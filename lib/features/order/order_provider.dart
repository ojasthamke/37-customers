import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/providers.dart';
import '../auth/auth_provider.dart';
import '../cart/cart_provider.dart';
import '../../core/services/sync_service.dart';

class OrderListNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref _ref;
  StreamSubscription? _subscription;
  Timer? _pollTimer;
  final Map<String, String> _lastKnownStatuses = {};
  bool _isFetchingSilent = false;
  int _fetchOrderRequestId = 0;

  OrderListNotifier(this._ref) : super(const AsyncValue.loading()) {
    // Listen for auth state changes to subscribe to customer orders
    _ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.customer != null) {
        _subscribeToOrders(next.customer!['id'] ?? '');
      } else {
        _unsubscribe();
        if (mounted) state = const AsyncValue.data([]);
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
            final filtered = list.where((o) => 
              (customerId.isNotEmpty && o['customer_id'] == customerId) || 
              (phone.isNotEmpty && o['customer_phone'] == phone)
            ).toList();
            return deduplicateOrders(filtered);
          })
          .listen((list) async {
            for (final order in list) {
              final String id = (order['id'] ?? '').toString();
              final String status = order['status'] ?? 'Pending';
              _lastKnownStatuses[id] = status;
            }

            // Silently fetch full order_items on realtime order change for in-app UI
            _fetchSilent(customerId, phone);
          }, onError: (err) {
            debugPrint('Realtime orders error (ignored): $err');
          });
    } catch (e) {
      debugPrint('Realtime orders stream creation failed: $e');
    }
  }

  Future<void> _fetchSilent(String customerId, String phone, {bool isInitial = false}) async {
    if (_isFetchingSilent && !isInitial) return;
    _isFetchingSilent = true;
    final int requestId = ++_fetchOrderRequestId;

    try {
      if (customerId.isEmpty && phone.isEmpty) {
        if (mounted) state = const AsyncValue.data([]);
        return;
      }

      final client = Supabase.instance.client;
      var query = client.from('orders').select('*, order_items(*)');
      if (customerId.isNotEmpty && phone.isNotEmpty) {
        query = query.or('customer_id.eq.$customerId,customer_phone.eq.$phone');
      } else if (customerId.isNotEmpty) {
        query = query.eq('customer_id', customerId);
      } else {
        query = query.eq('customer_phone', phone);
      }

      final list = await query.order('order_date', ascending: false).timeout(const Duration(seconds: 15));
      if (requestId != _fetchOrderRequestId) return;

      final parsed = List<Map<String, dynamic>>.from(list);
      final deduped = deduplicateOrders(parsed);
      if (mounted) {
        state = AsyncValue.data(deduped);
      }

      // Clean up SQLite local orders cache to purge any stale OFF- duplicates
      try {
        final db = await DatabaseHelper.instance.database;
        await db.transaction((txn) async {
          for (final order in deduped) {
            final offlineNo = order['offline_order_no']?.toString();
            final orderNo = order['order_number']?.toString();
            final orderId = order['id']?.toString();
            if (offlineNo != null && offlineNo.isNotEmpty) {
              await txn.delete('orders', where: "offline_order_no = ? AND (order_number IS NULL OR order_number = '' OR sync_status != 'synced')", whereArgs: [offlineNo]);
            }
            if (orderNo != null && orderNo.isNotEmpty) {
              await txn.delete('orders', where: "order_number = ? AND sync_status != 'synced'", whereArgs: [orderNo]);
            }
            if (orderId != null && orderId.isNotEmpty) {
              await txn.delete('orders', where: "id = ? AND sync_status != 'synced'", whereArgs: [orderId]);
            }
          }
        });
      } catch (e) {
        debugPrint('OrderListNotifier: SQLite cleanup error: $e');
      }
    } catch (err, stack) {
      if (requestId != _fetchOrderRequestId) return;
      if (isInitial && mounted) {
        try {
          final repo = _ref.read(orderRepositoryProvider);
          final list = await repo.getOrders(phone);
          final filtered = list.where((o) => 
            (customerId.isNotEmpty && o['customer_id'] == customerId) || 
            (phone.isNotEmpty && o['customer_phone'] == phone)
          ).toList();
          if (mounted) {
            state = AsyncValue.data(deduplicateOrders(filtered));
          }
        } catch (e) {
          if (mounted) {
            state = AsyncValue.error(err, stack);
          }
        }
      }
    } finally {
      _isFetchingSilent = false;
    }
  }

  List<Map<String, dynamic>> deduplicateOrders(List<Map<String, dynamic>> orders) {
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
      final customerId = customer?['id']?.toString();

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
        customerId: customerId,
      );

      _ref.read(activeCartNotifierProvider).clear();
      
      return order;
    } catch (e) {
      debugPrint('OrderListNotifier: placeOrder error: $e');
      rethrow;
    }
  }

  Future<void> retryOrderSync(String orderId) async {
    final repo = _ref.read(orderRepositoryProvider);
    await repo.retryOrderSync(orderId);
    await SyncService.instance.syncPendingOrders();
    final customer = _ref.read(authProvider).customer;
    final phone = customer?['phone']?.toString() ?? '';
    if (phone.isNotEmpty) {
      await fetchOrders(phone);
    }
  }

  Future<void> dismissFailedOrder(String orderId) async {
    final repo = _ref.read(orderRepositoryProvider);
    await repo.dismissPermanentlyFailedOrder(orderId);
    final customer = _ref.read(authProvider).customer;
    final phone = customer?['phone']?.toString() ?? '';
    if (phone.isNotEmpty) {
      await fetchOrders(phone);
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
final orderDetailsProvider = StreamProvider.autoDispose.family<OrderFullDetails, String>((ref, orderId) {
  final client = Supabase.instance.client;
  final dbHelper = DatabaseHelper.instance;
  final controller = StreamController<OrderFullDetails>();
  Timer? pollTimer;
  bool hasEmittedData = false;
  int currentSeq = 0;
  int latestCommittedSeq = 0;

  bool phoneMatch(String a, String b) {
    if (a == b) return true;
    final cleanA = a.replaceAll(RegExp(r'\D'), '');
    final cleanB = b.replaceAll(RegExp(r'\D'), '');
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA == cleanB) return true;
    if (cleanA.length >= 10 && cleanB.length >= 10) {
      return cleanA.substring(cleanA.length - 10) == cleanB.substring(cleanB.length - 10);
    }
    return false;
  }

  Future<void> loadLocalFirst() async {
    try {
      final currentCust = ref.read(authProvider).customer;
      if (currentCust == null) return;
      final currentCustId = currentCust['id']?.toString() ?? '';
      final currentPhone = currentCust['phone']?.toString() ?? '';

      final db = await dbHelper.database;
      final localOrders = await db.query(
        'orders',
        where: 'id = ? OR order_number = ? OR offline_order_no = ? OR idempotency_key = ?',
        whereArgs: [orderId, orderId, orderId, orderId],
      );
      if (localOrders.isNotEmpty) {
        final orderMap = Map<String, dynamic>.from(localOrders.first);
        final orderCustId = orderMap['customer_id']?.toString() ?? '';
        final orderPhone = orderMap['customer_phone']?.toString() ?? '';

        final bool idMatches = currentCustId.isNotEmpty && orderCustId.isNotEmpty && orderCustId == currentCustId;
        final bool phoneMatches = currentPhone.isNotEmpty && orderPhone.isNotEmpty && phoneMatch(currentPhone, orderPhone);
        final bool isUnknownOwnership = orderCustId.isEmpty && orderPhone.isEmpty;
        if (!idMatches && !phoneMatches && !isUnknownOwnership) {
          debugPrint('[OrderDetails] Suppressing local order load: ownership mismatch with current user');
          return;
        }

        final actualId = orderMap['id']?.toString() ?? orderId;
        final localItems = await db.query('order_items', where: 'order_id = ?', whereArgs: [actualId]);
        if (!controller.isClosed) {
          hasEmittedData = true;
          controller.add(OrderFullDetails(
            order: orderMap,
            items: List<Map<String, dynamic>>.from(localItems),
          ));
        }
      }
    } catch (_) {}
  }

  Future<void> fetchLatest() async {
    final int mySeq = ++currentSeq;
    try {
      final currentCust = ref.read(authProvider).customer;
      if (currentCust == null) {
        if (!controller.isClosed) {
          controller.addError(Exception('Unauthorized: Please log in to view order details.'));
        }
        return;
      }
      final currentCustId = currentCust['id']?.toString() ?? '';
      final currentPhone = currentCust['phone']?.toString() ?? '';

      final order = await client
          .from('orders')
          .select()
          .or('id.eq.$orderId,order_number.eq.$orderId,offline_order_no.eq.$orderId,idempotency_key.eq.$orderId')
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      
      if (order != null) {
        final orderCustId = order['customer_id']?.toString() ?? '';
        final orderPhone = order['customer_phone']?.toString() ?? '';
        final bool idMatches = currentCustId.isNotEmpty && orderCustId.isNotEmpty && orderCustId == currentCustId;
        final bool phoneMatches = currentPhone.isNotEmpty && orderPhone.isNotEmpty && phoneMatch(currentPhone, orderPhone);
        if (!idMatches && !phoneMatches) {
          if (!controller.isClosed) {
            controller.addError(Exception('Unauthorized order access.'));
          }
          return;
        }
        final itemsRes = await client.from('order_items').select().eq('order_id', order['id']).timeout(const Duration(seconds: 15));
        final items = List<Map<String, dynamic>>.from(itemsRes);
        
        try {
          final db = await dbHelper.database;
          await db.insert(
            'orders',
            {
              'id': order['id']?.toString(),
              'order_number': order['order_number']?.toString(),
              'customer_id': order['customer_id']?.toString(),
              'customer_phone': order['customer_phone']?.toString(),
              'delivery_address': order['delivery_address']?.toString(),
              'order_date': order['order_date']?.toString(),
              'status': order['status']?.toString() ?? 'Pending',
              'total_amount': (order['total_amount'] as num?)?.toDouble() ?? 0.0,
              'sync_status': 'synced',
              'delivery_date': order['delivery_date']?.toString(),
              'order_type': order['order_type']?.toString() ?? 'Normal',
              'order_taking_date': order['order_taking_date']?.toString(),
              'offline_order_no': order['offline_order_no']?.toString(),
              'customer_name': order['customer_name']?.toString(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {}

        if (mySeq < latestCommittedSeq) return;
        latestCommittedSeq = mySeq;

        if (!controller.isClosed) {
          hasEmittedData = true;
          controller.add(OrderFullDetails(order: Map<String, dynamic>.from(order), items: items));
        }
      } else {
        // If not on remote, check if we had local
        final db = await dbHelper.database;
        final localOrders = await db.query(
          'orders',
          where: 'id = ? OR order_number = ? OR offline_order_no = ? OR idempotency_key = ?',
          whereArgs: [orderId, orderId, orderId, orderId],
        );
        if (localOrders.isEmpty && !controller.isClosed) {
          controller.addError(Exception('Order not found.'));
        }
      }
    } catch (e) {
      // Offline / network failure fallback: check local DB once more before emitting error
      if (!hasEmittedData) {
        try {
          final db = await dbHelper.database;
          final localOrders = await db.query(
            'orders',
            where: 'id = ? OR order_number = ? OR offline_order_no = ? OR idempotency_key = ?',
            whereArgs: [orderId, orderId, orderId, orderId],
          );
          if (localOrders.isNotEmpty) {
            final orderMap = Map<String, dynamic>.from(localOrders.first);
            final actualId = orderMap['id']?.toString() ?? orderId;
            final localItems = await db.query('order_items', where: 'order_id = ?', whereArgs: [actualId]);
            if (!controller.isClosed) {
              hasEmittedData = true;
              controller.add(OrderFullDetails(
                order: orderMap,
                items: List<Map<String, dynamic>>.from(localItems),
              ));
              return;
            }
          }
        } catch (_) {}
      }

      // Only emit error if no cached/local data is already displayed
      if (!controller.isClosed && !hasEmittedData) {
        controller.addError(e);
      } else {
        debugPrint('orderDetailsProvider: Remote fetch error (preserving cached data): $e');
      }
    }
  }

  loadLocalFirst().then((_) => fetchLatest());

  // Polling fallback every 10 seconds
  pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => fetchLatest());

  StreamSubscription? sub;
  try {
    final orderStream = client
        .from('orders')
        .stream(primaryKey: ['id'])
        .map((list) {
          final matched = list.where((o) =>
              o['id'] == orderId ||
              o['order_number'] == orderId ||
              o['offline_order_no'] == orderId ||
              o['idempotency_key'] == orderId).toList();
          return matched.isNotEmpty ? matched.first : null;
        });

    sub = orderStream.listen((order) async {
      final int rtSeq = ++currentSeq;
      if (order != null) {
        final currentCust = ref.read(authProvider).customer;
        if (currentCust == null) return;
        final currentCustId = currentCust['id']?.toString() ?? '';
        final currentPhone = currentCust['phone']?.toString() ?? '';
        final orderCustId = order['customer_id']?.toString() ?? '';
        final orderPhone = order['customer_phone']?.toString() ?? '';
        final bool idMatches = currentCustId.isNotEmpty && orderCustId.isNotEmpty && orderCustId == currentCustId;
        final bool phoneMatches = currentPhone.isNotEmpty && orderPhone.isNotEmpty && orderPhone == currentPhone;
        if (!idMatches && !phoneMatches) {
          return;
        }

        try {
          final itemsRes = await client.from('order_items').select().eq('order_id', order['id']);
          final items = List<Map<String, dynamic>>.from(itemsRes);
          if (rtSeq < latestCommittedSeq) return;
          latestCommittedSeq = rtSeq;
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

final lastOrderProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final client = Supabase.instance.client;
    final currentCust = ref.watch(authProvider).customer;
    final userId = currentCust?['id']?.toString() ?? client.auth.currentUser?.id;
    final phone = currentCust?['phone']?.toString();
    if ((userId == null || userId.isEmpty) && (phone == null || phone.isEmpty)) {
      return null;
    }

    var query = client.from('orders').select('*, order_items(*)');
    if (userId != null && userId.isNotEmpty && phone != null && phone.isNotEmpty) {
      query = query.or('customer_id.eq.$userId,customer_phone.eq.$phone');
    } else if (userId != null && userId.isNotEmpty) {
      query = query.eq('customer_id', userId);
    } else {
      query = query.eq('customer_phone', phone!);
    }

    final res = await query.order('order_date', ascending: false).limit(1).maybeSingle();
    return res;
  } catch (_) {
    return null;
  }
});
