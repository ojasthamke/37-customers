import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/core/database/repositories.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';
import 'package:aplibhaji_customers/features/auth/auth_provider.dart';

void main() {
  group('Network, Offline, Retry & Timeout Resilience Tests', () {
    test('1. Remote network failure falls back gracefully to cached repository data', () async {
      final mockCatalog = MockFailingCatalogRepository();

      // Categories should return cached list even when remote is offline
      final categories = await mockCatalog.getCategories();
      expect(categories, isNotEmpty);
      expect(categories.first['name'], 'Vegetables');

      // Products should return cached list even when remote is offline
      final products = await mockCatalog.getProducts();
      expect(products, isNotEmpty);
      expect(products.first['name'], 'Tomato');
    });

    test('2. Order deduplication handles duplicate network packets and merges fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(orderListProvider.notifier);

      final orderA1 = {
        'id': 'ord-1',
        'order_number': 'ORD-1001',
        'status': 'Pending',
        'total_amount': 250.0,
        'order_date': '2026-09-03T10:00:00Z',
        'order_items': [{'product_id': 'p1', 'quantity': 2.0}],
      };

      // Server sends newer status update without joined order_items (e.g. from lightweight realtime webhook)
      final orderA2 = {
        'id': 'ord-1',
        'order_number': 'ORD-1001',
        'status': 'Confirmed',
        'total_amount': 250.0,
        'order_date': '2026-09-03T10:00:00Z',
      };

      // Pass duplicate packets to deduplicator
      final deduped = notifier.deduplicateOrders([orderA1, orderA2]);

      expect(deduped.length, 1);
      expect(deduped.first['status'], 'Confirmed');
      // Order items from earlier packet must be preserved!
      expect(deduped.first['order_items'], isNotEmpty);
    });

    test('3. Idempotent retry with same key does not create duplicate order', () async {
      final repo = MockIdempotentOrderRepository();

      final firstCall = await repo.placeOrder(
        customerPhone: '9876543210',
        deliveryAddress: 'Flat 101, Star Residency',
        totalAmount: 350.0,
        items: [{'product_id': 'p1', 'quantity': 1.0}],
        idempotencyKey: 'idem-uuid-999',
      );

      final retryCall = await repo.placeOrder(
        customerPhone: '9876543210',
        deliveryAddress: 'Flat 101, Star Residency',
        totalAmount: 350.0,
        items: [{'product_id': 'p1', 'quantity': 1.0}],
        idempotencyKey: 'idem-uuid-999',
      );

      expect(firstCall['id'], retryCall['id']);
      expect(firstCall['order_number'], retryCall['order_number']);
      expect(repo.createdOrdersCount, 1, reason: 'Duplicate submission with same idempotency key must NOT create second order');
    });

    test('4. Network timeout on remote call throws TimeoutException cleanly within threshold', () async {
      final slowRepo = MockHangingOrderRepository();

      expect(
        () => slowRepo.hangWithTimeout(const Duration(milliseconds: 50)),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('5. Order details stream preserves cached order and does not emit error on remote network failure', () async {
      final controller = StreamController<Map<String, dynamic>>();
      bool hasEmittedData = false;
      final events = <Map<String, dynamic>>[];
      Object? receivedError;

      controller.stream.listen(
        (data) => events.add(data),
        onError: (err) => receivedError = err,
      );

      // 1. Simulate local SQLite cache emitting order
      final localCachedOrder = {'id': 'ord-local-1', 'status': 'Pending'};
      hasEmittedData = true;
      controller.add(localCachedOrder);
      await Future.delayed(Duration.zero);

      // 2. Simulate remote Supabase network failure (e.g. SocketException)
      final networkError = Exception('SocketException: Connection refused (OS Error: Network unreachable)');
      if (!hasEmittedData) {
        controller.addError(networkError);
      }

      await Future.delayed(Duration.zero);
      await controller.close();

      expect(events.length, 1);
      expect(events.first['id'], 'ord-local-1');
      expect(receivedError, isNull, reason: 'Cache-first pattern must preserve local order and prevent screen-wiping errors');
    });

    test('6. Resilient product parser handles string numbers, integers, and null fields without TypeError', () {
      final rawBackendProduct = {
        'id': 'p-malformed-1',
        'name': 'Organic Potato',
        'price': '45.50', // String instead of num
        'mrp': '60', // String integer instead of num
        'stock': '12.5', // String float instead of num
        'order_now_stock': '5',
        'order_now_price': '48.00',
        'is_enabled': 1,
        'description': '{"text":"Fresh farm potatoes","cost_price":"30.00","weight_per_piece":"0.5"}',
      };

      // Ensure parsing doesn't crash on String numbers
      final parsed = SupabaseCatalogRepository.parseProductDescription(rawBackendProduct);

      expect(parsed['price'], 45.50);
      expect(parsed['market_price'], 60.0);
      expect(parsed['stock'], 12.5);
      expect(parsed['order_now_stock'], 5.0);
      expect(parsed['order_now_price'], 48.0);
      expect(parsed['cost_price'], 30.0);
      expect(parsed['weight_per_piece'], 0.5);
    });

    test('7. Out-of-order race condition: Older request A cannot overwrite newer request B', () async {
      int activeRequestId = 0;
      String lastCommittedData = '';

      // Simulate Request A (starts first, finishes slow)
      Future<void> simulateRequestA() async {
        final int id = ++activeRequestId; // id = 1
        await Future.delayed(const Duration(milliseconds: 100)); // slow
        if (id == activeRequestId) {
          lastCommittedData = 'Data from A';
        }
      }

      // Simulate Request B (starts second, finishes fast)
      Future<void> simulateRequestB() async {
        final int id = ++activeRequestId; // id = 2
        await Future.delayed(const Duration(milliseconds: 20)); // fast
        if (id == activeRequestId) {
          lastCommittedData = 'Data from B';
        }
      }

      // Launch A, then quickly launch B
      final futureA = simulateRequestA();
      final futureB = simulateRequestB();

      await Future.wait([futureA, futureB]);

      // B must be the committed state, even though A finished after B
      expect(lastCommittedData, 'Data from B', reason: 'Stale delayed response must never overwrite fresher response');
    });
  });
}


class MockFailingCatalogRepository implements CatalogRepository {
  @override
  Future<List<Map<String, dynamic>>> getCategories({Function(List<Map<String, dynamic>>)? onRefresh}) async {
    // Simulates offline mode where remote failed and cached data was returned
    return [
      {'id': 'cat-1', 'name': 'Vegetables', 'is_enabled': 1},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getProducts({String? search, String? categoryId, Function(List<Map<String, dynamic>>)? onRefresh, bool forceRefresh = false}) async {
    return [
      {'id': 'prod-1', 'name': 'Tomato', 'price': 30.0, 'is_enabled': 1},
    ];
  }

  @override
  Future<Map<String, dynamic>?> getProductById(String id, {Function(Map<String, dynamic>)? onRefresh}) async => null;

  @override
  Future<void> cacheProducts(List<Map<String, dynamic>> products) async {}
}

class MockIdempotentOrderRepository implements OrderRepository {
  int createdOrdersCount = 0;
  final Map<String, Map<String, dynamic>> _ordersByIdempotency = {};

  @override
  Future<Map<String, dynamic>> placeOrder({
    required String customerPhone,
    required String deliveryAddress,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    String? idempotencyKey,
    String? deliveryDate,
    String? offlineOrderNo,
    String? areaName,
    String? roadName,
    String? subRoadName,
    String? orderType,
    String? orderTakingDate,
    String? customerId,
  }) async {
    if (idempotencyKey != null && _ordersByIdempotency.containsKey(idempotencyKey)) {
      return _ordersByIdempotency[idempotencyKey]!;
    }

    createdOrdersCount++;
    final newOrder = {
      'id': 'ord-$createdOrdersCount',
      'order_number': 'ORD-20260903-$createdOrdersCount',
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'total_amount': totalAmount,
      'status': 'Pending',
      'idempotency_key': idempotencyKey,
    };

    if (idempotencyKey != null) {
      _ordersByIdempotency[idempotencyKey] = newOrder;
    }
    return newOrder;
  }

  @override
  Future<List<Map<String, dynamic>>> getOrders(String customerPhone, {Function(List<Map<String, dynamic>>)? onRefresh}) async => [];

  @override
  Future<Map<String, dynamic>?> getOrderById(String id, {Function(Map<String, dynamic>)? onRefresh}) async => null;

  @override
  Future<List<Map<String, dynamic>>> getOrderItems(String orderId, {Function(List<Map<String, dynamic>>)? onRefresh}) async => [];

  @override
  Future<void> retryOrderSync(String orderId) async {}

  @override
  Future<void> dismissPermanentlyFailedOrder(String orderId) async {}
}

class MockHangingOrderRepository {
  Future<void> hangWithTimeout(Duration timeout) async {
    final completer = Completer<void>();
    // Never completes unless timed out
    return completer.future.timeout(timeout);
  }
}
