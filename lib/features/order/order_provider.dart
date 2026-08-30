import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../core/database/providers.dart';
import '../../core/database/caching_repositories.dart';
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
    
    // 1. Fetch initial via HTTP Future
    Future<void> fetchInitial() async {
      try {
        final repo = _ref.read(orderRepositoryProvider);
        final list = await repo.getOrders(phone);
        final filtered = list.where((o) => o['customer_id'] == customerId || o['customer_phone'] == phone).toList();
        state = AsyncValue.data(_deduplicateOrders(filtered));
      } catch (err, stack) {
        state = AsyncValue.error(err, stack);
      }
    }

    fetchInitial();
    
    // Polling fallback every 10 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      Future<void> fetchSilent() async {
        try {
          final repo = _ref.read(orderRepositoryProvider);
          final list = await repo.getOrders(phone);
          final filtered = list.where((o) => o['customer_id'] == customerId || o['customer_phone'] == phone).toList();
          state = AsyncValue.data(_deduplicateOrders(filtered));
        } catch (_) {
          // Ignore polling errors in background
        }
      }
      fetchSilent();
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

            try {
              final repo = _ref.read(orderRepositoryProvider);
              if (repo is CachingOrderRepository) {
                final pending = await repo.getPendingOrders();
                final filteredPending = pending.where((o) => o['customer_id'] == customerId || o['customer_phone'] == phone).toList();
                final merged = [...filteredPending, ...list];
                state = AsyncValue.data(_deduplicateOrders(merged));
              } else {
                state = AsyncValue.data(_deduplicateOrders(list));
              }
            } catch (e) {
              state = AsyncValue.data(_deduplicateOrders(list));
            }
          }, onError: (err) {
            debugPrint('Realtime orders error (ignored): $err');
          });
    } catch (e) {
      debugPrint('Realtime orders stream creation failed: $e');
    }
  }

  List<Map<String, dynamic>> _deduplicateOrders(List<Map<String, dynamic>> orders) {
    final Map<String, Map<String, dynamic>> dedupMap = {};
    for (final o in orders) {
      final String key = (o['order_number']?.toString().isNotEmpty == true)
          ? o['order_number'].toString()
          : (o['offline_order_no']?.toString().isNotEmpty == true
              ? o['offline_order_no'].toString()
              : (o['id']?.toString() ?? ''));
      if (key.isEmpty) continue;

      if (!dedupMap.containsKey(key)) {
        dedupMap[key] = o;
      } else {
        // If duplicate exists, keep the one with higher or non-zero total_amount / synced status
        final existingTotal = (dedupMap[key]!['total_amount'] as num?)?.toDouble() ?? 0.0;
        final newTotal = (o['total_amount'] as num?)?.toDouble() ?? 0.0;
        if (newTotal > existingTotal || (o['sync_status'] == 'synced' && dedupMap[key]!['sync_status'] != 'synced')) {
          dedupMap[key] = o;
        }
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
    try {
      final repo = _ref.read(orderRepositoryProvider);
      final customerId = _ref.read(authProvider).customer?['id'] ?? '';
      final list = await repo.getOrders(customerPhone);
      final filtered = list.where((o) => o['customer_id'] == customerId || o['customer_phone'] == customerPhone).toList();
      filtered.sort((a, b) {
        final aDate = DateTime.tryParse(a['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['order_date']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      state = AsyncValue.data(filtered);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
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
  final repo = ref.read(orderRepositoryProvider);
  final client = Supabase.instance.client;
  final controller = StreamController<OrderFullDetails>();
  Timer? pollTimer;

  Future<void> fetchLatest() async {
    // 1. Instantly load from local SQLite cache to avoid loading spinner hangs
    try {
      final localOrder = await repo.getOrderById(orderId);
      if (localOrder != null) {
        final localItems = await repo.getOrderItems(orderId);
        if (!controller.isClosed) {
          controller.add(OrderFullDetails(order: localOrder, items: localItems));
        }
      }
    } catch (_) {}

    // 2. Fetch from Supabase in the background to update details
    try {
      var order = await client.from('orders').select().eq('id', orderId).maybeSingle();
      order ??= await client.from('orders').select().eq('idempotency_key', orderId).maybeSingle();
      
      if (order != null) {
        final items = await repo.getOrderItems(order['id']);
        if (!controller.isClosed) {
          controller.add(OrderFullDetails(order: order, items: items));
        }
      }
    } catch (e) {
      // Propagate error only if we don't have local cached data and controller is empty
      if (!controller.isClosed) {
        // Fallback check again
        try {
          final localOrder = await repo.getOrderById(orderId);
          if (localOrder == null) {
            controller.addError(e);
          }
        } catch (_) {
          controller.addError(e);
        }
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
          final items = await repo.getOrderItems(order['id']);
          if (!controller.isClosed) {
            controller.add(OrderFullDetails(order: order, items: items));
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
