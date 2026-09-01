import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/database/database_helper.dart';
import '../../core/database/providers.dart';
import '../auth/auth_provider.dart';
import '../../core/services/notification_service.dart';
import '../cart/cart_provider.dart';

class OrderListNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  StreamSubscription? _subscription;
  Timer? _pollTimer;
  final Map<String, String> _lastKnownStatuses = {};


  OrderListNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Listen for auth state changes to subscribe to customer orders
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.customer != null) {
        _subscribeToOrders(next.customer!['id'] ?? '');
      } else {
        _unsubscribe();
        state = const AsyncValue.data([]);
      }
    });

    final currentCust = _ref.read(authProvider).customer;
    if (currentCust != null) {
      _subscribeToOrders(currentCust['id'] ?? '');
    } else {
      state = const AsyncValue.data([]);
    }
  }

  void _subscribeToOrders(String customerId) {
    _unsubscribe();
    state = const AsyncValue.loading();
    final phone = _ref.read(authProvider).customer?['phone'] ?? '';
    
    // 1. Fetch initial fresh from remote Supabase
    _fetchSilent(customerId, phone, isInitial: true);
    
    // Polling fallback every 10 seconds for real-time consistency
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchSilent(customerId, phone);
    });
    
    try {
      _subscription = Supabase.instance.client
          .from('orders')
          .stream(primaryKey: ['id'])
          .map((list) {
            final filtered = list.where((o) => o['customer_id'] == customerId || o['customer_phone'] == phone).toList();
            return _deduplicateOrders(filtered);
          })
          .listen((list) async {
            final bool isFirstLoad = _lastKnownStatuses.isEmpty;
            for (final order in list) {
              final String id = order['id'] as String;
              final String orderNo = order['order_number'] ?? 'N/A';
              final String status = order['status'] ?? 'Pending';
              
              if (!isFirstLoad) {
                final oldStatus = _lastKnownStatuses[id];
                if (oldStatus != null && oldStatus != status) {
                  NotificationService.instance.showNotification(
                    id: id.hashCode,
                    title: 'Order Status Updated',
                    body: 'Your order $orderNo has been updated to: $status',
                    payload: id,
                  );
                }
              }
              _lastKnownStatuses[id] = status;
            }

            // Also silently fetch full order_items on realtime order change
            _fetchSilent(customerId, phone);
          }, onError: (err) {
            debugPrint('Realtime orders error (ignored): $err');
          });
    } catch (e) {
      debugPrint('Realtime orders stream creation failed: $e');
    }
  }

  Future<void> _fetchSilent(String customerId, String phone, {bool isInitial = false}) async {
    try {
      final client = Supabase.instance.client;
      final list = await client
          .from('orders')
          .select('*, order_items(*)')
          .or('customer_id.eq.$customerId,customer_phone.eq.$phone')
          .order('order_date', ascending: false);

      final parsed = List<Map<String, dynamic>>.from(list);
      final deduped = _deduplicateOrders(parsed);
      state = AsyncValue.data(deduped);

      // Clean up SQLite local orders cache to purge any stale OFF- duplicates
      try {
        final db = await DatabaseHelper.instance.database;
        for (final order in deduped) {
          final offlineNo = order['offline_order_no']?.toString();
          final orderNo = order['order_number']?.toString();
          final orderId = order['id']?.toString();
          if (offlineNo != null && offlineNo.isNotEmpty) {
            await db.delete('orders', where: "offline_order_no = ? AND (order_number IS NULL OR order_number = '' OR sync_status != 'synced')", whereArgs: [offlineNo]);
          }
          if (orderNo != null && orderNo.isNotEmpty) {
            await db.delete('orders', where: "order_number = ? AND sync_status != 'synced'", whereArgs: [orderNo]);
          }
          if (orderId != null && orderId.isNotEmpty) {
            await db.delete('orders', where: "id = ? AND sync_status != 'synced'", whereArgs: [orderId]);
          }
        }
      } catch (e) {
        debugPrint('OrderListNotifier: SQLite cleanup error: $e');
      }
    } catch (err, stack) {
      if (isInitial) {
        try {
          final repo = _ref.read(orderRepositoryProvider);
          final list = await repo.getOrders(phone);
          final filtered = list.where((o) => o['customer_id'] == customerId || o['customer_phone'] == phone).toList();
          state = AsyncValue.data(_deduplicateOrders(filtered));
        } catch (e) {
          state = AsyncValue.error(err, stack);
        }
      }
    }
  }

  List<Map<String, dynamic>> _deduplicateOrders(List<Map<String, dynamic>> orders) {
    final Map<String, Map<String, dynamic>> dedupMap = {};
    for (final o in orders) {
      final String orderNumber = o['order_number']?.toString().trim() ?? '';
      final String offlineOrderNo = o['offline_order_no']?.toString().trim() ?? '';
      final String id = o['id']?.toString().trim() ?? '';

      // Find existing match by order_number, offline_order_no, or id
      String? matchedKey;
      for (final entry in dedupMap.entries) {
        final ex = entry.value;
        final exOrderNo = ex['order_number']?.toString().trim() ?? '';
        final exOfflineNo = ex['offline_order_no']?.toString().trim() ?? '';
        final exId = ex['id']?.toString().trim() ?? '';

        if ((orderNumber.isNotEmpty && exOrderNo.isNotEmpty && orderNumber == exOrderNo) ||
            (offlineOrderNo.isNotEmpty && exOfflineNo.isNotEmpty && offlineOrderNo == exOfflineNo) ||
            (id.isNotEmpty && exId.isNotEmpty && id == exId)) {
          matchedKey = entry.key;
          break;
        }
      }

      final String primaryKey = orderNumber.isNotEmpty
          ? orderNumber
          : (offlineOrderNo.isNotEmpty ? offlineOrderNo : id);
      if (primaryKey.isEmpty) continue;

      if (matchedKey == null) {
        dedupMap[primaryKey] = Map<String, dynamic>.from(o);
      } else {
        final existing = dedupMap[matchedKey]!;
        final Map<String, dynamic> merged = Map<String, dynamic>.from(existing);

        // Update fields with incoming order data
        merged.addAll(o);

        // Explicitly preserve existing non-empty order_items if incoming realtime update did not contain joined items
        final existingItems = existing['order_items'];
        final newItems = o['order_items'];
        if ((newItems == null || (newItems is List && newItems.isEmpty)) &&
            (existingItems != null && existingItems is List && existingItems.isNotEmpty)) {
          merged['order_items'] = existingItems;
        } else if (newItems != null && newItems is List && newItems.isNotEmpty) {
          merged['order_items'] = newItems;
        }

        dedupMap.remove(matchedKey);
        final newKey = (merged['order_number']?.toString().isNotEmpty == true) ? merged['order_number'].toString() : primaryKey;
        dedupMap[newKey] = merged;

      }
    }
    final result = dedupMap.values.toList();
    result.sort((a, b) {
      final aDate = DateTime.tryParse(a['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return result;
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastKnownStatuses.clear();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> fetchOrders(String customerPhone) async {
    final customerId = _ref.read(authProvider).customer?['id'] ?? '';
    await _fetchSilent(customerId, customerPhone);
  }


  Future<Map<String, dynamic>?> placeOrder({
    required String name,
    required String phone,
    required String address,
    String? idempotencyKey,
    String? deliveryDate,
    String? offlineOrderNo,
    String? orderType,
    String? orderTakingDate,
  }) async {
    final cart = _ref.read(activeCartProvider);
    if (cart.items.isEmpty) return null;

    try {
      final repo = _ref.read(orderRepositoryProvider);
      final itemsPayload = cart.items.values.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'unit': item.unit,
        'total_price': item.totalPrice,
      }).toList();

      final customer = _ref.read(authProvider).customer;
      final areaName = customer?['area_name'];
      final roadName = customer?['road_name'];
      final subRoadName = customer?['sub_road_name'];

      final order = await repo.placeOrder(
        customerPhone: phone,
        deliveryAddress: address,
        totalAmount: cart.roundedGrandTotal,
        items: itemsPayload,
        idempotencyKey: idempotencyKey,
        deliveryDate: deliveryDate,
        offlineOrderNo: offlineOrderNo,
        areaName: areaName,
        roadName: roadName,
        subRoadName: subRoadName,
        orderType: orderType,
        orderTakingDate: orderTakingDate,
      );

      _ref.read(activeCartNotifierProvider).clear();
      
      return order;
    } catch (e) {
      debugPrint('OrderListNotifier: placeOrder error: $e');
      rethrow;
    }
  }
}

final orderListProvider = StateNotifierProvider<OrderListNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return OrderListNotifier(ref);
});

class OrderFullDetails {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> items;

  OrderFullDetails({required this.order, required this.items});
}

// Order details provider family (Realtime Stream with Future fallback & Polling)
final orderDetailsProvider = StreamProvider.family<OrderFullDetails, String>((ref, orderId) {
  final client = Supabase.instance.client;
  final controller = StreamController<OrderFullDetails>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    try {
      var order = await client.from('orders').select().eq('id', orderId).maybeSingle();
      order ??= await client.from('orders').select().eq('idempotency_key', orderId).maybeSingle();
      
      if (order != null) {
        final itemsRes = await client.from('order_items').select().eq('order_id', order['id']);
        final items = List<Map<String, dynamic>>.from(itemsRes);
        if (!controller.isClosed) {
          controller.add(OrderFullDetails(order: Map<String, dynamic>.from(order), items: items));
        }
      } else {
        if (!controller.isClosed) {
          controller.addError(Exception('Order has been removed or deleted.'));
        }
      }
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(e);
      }
    }
  }

  fetchLatest();

  // Polling fallback every 10 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchLatest());

  StreamSubscription? sub;
  try {
    final orderStream = client
        .from('orders')
        .stream(primaryKey: ['id'])
        .map((list) {
          final matched = list.where((o) => o['id'] == orderId || o['idempotency_key'] == orderId).toList();
          return matched.isNotEmpty ? matched.first : null;
        });

    sub = orderStream.listen((order) async {
      if (order != null) {
        try {
          final itemsRes = await client.from('order_items').select().eq('order_id', order['id']);
          final items = List<Map<String, dynamic>>.from(itemsRes);
          if (!controller.isClosed) {
            controller.add(OrderFullDetails(order: Map<String, dynamic>.from(order), items: items));
          }
        } catch (_) {}
      }
    }, onError: (err) {
      debugPrint('Realtime orderDetails error (ignored): $err');
    });
  } catch (e) {
    debugPrint('Realtime orderDetails stream creation failed: $e');
  }

  ref.onDispose(() {
    pollTimer?.cancel();
    sub?.cancel();
    controller.close();
  });

  return controller.stream;
});
