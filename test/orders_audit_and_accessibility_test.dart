import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Orders Filter Logic Verification', () {
    final List<Map<String, dynamic>> testOrders = [
      {
        'id': 'ord-1',
        'order_number': 'OK-20260902-00001',
        'status': 'Pending',
        'order_type': 'Normal',
      },
      {
        'id': 'ord-2',
        'order_number': 'OK-20260902-00002',
        'status': 'Pending',
        'order_type': 'Pre-Order',
      },
      {
        'id': 'ord-3',
        'order_number': 'OK-20260902-00003',
        'status': 'Confirmed',
        'order_type': 'Normal',
      },
      {
        'id': 'ord-4',
        'order_number': 'OK-20260902-00004',
        'status': 'Delivered',
        'order_type': 'Normal',
      },
      {
        'id': 'ord-5',
        'order_number': 'OK-20260902-00005',
        'status': 'Cancelled',
        'order_type': 'Pre-Order',
      },
    ];

    List<Map<String, dynamic>> filterOrders(List<Map<String, dynamic>> orders, String selectedFilter) {
      return orders.where((order) {
        final status = (order['status'] ?? 'Pending').toString().toLowerCase();
        final orderType = (order['order_type'] ?? '').toString().toLowerCase();

        if (selectedFilter == 'Pre-Orders') {
          return orderType == 'pre-order';
        } else if (selectedFilter == 'Active') {
          return status != 'delivered' && status != 'cancelled';
        } else if (selectedFilter == 'Delivered') {
          return status == 'delivered';
        }
        return true;
      }).toList();
    }

    test('Regular Pending orders do NOT leak into Pre-Orders tab', () {
      final preOrders = filterOrders(testOrders, 'Pre-Orders');
      final preOrderIds = preOrders.map((o) => o['id']).toList();

      expect(preOrderIds.contains('ord-1'), isFalse, reason: 'Normal pending order must not show in Pre-Orders');
      expect(preOrderIds.contains('ord-2'), isTrue, reason: 'True pre-order must show in Pre-Orders');
      expect(preOrderIds.contains('ord-5'), isTrue, reason: 'Pre-order with cancelled status retains pre-order type');
      expect(preOrders.length, equals(2));
    });

    test('Active filter returns only active non-delivered non-cancelled orders', () {
      final active = filterOrders(testOrders, 'Active');
      final activeIds = active.map((o) => o['id']).toList();

      expect(activeIds, containsAll(['ord-1', 'ord-2', 'ord-3']));
      expect(activeIds.contains('ord-4'), isFalse, reason: 'Delivered orders must not appear in Active');
      expect(activeIds.contains('ord-5'), isFalse, reason: 'Cancelled orders must not appear in Active');
    });

    test('Delivered filter returns only delivered orders', () {
      final delivered = filterOrders(testOrders, 'Delivered');
      final deliveredIds = delivered.map((o) => o['id']).toList();

      expect(deliveredIds, equals(['ord-4']));
    });

    test('All filter returns all orders', () {
      final all = filterOrders(testOrders, 'All');
      expect(all.length, equals(5));
    });
  });

  group('Authoritative Price Resolution Parity Test', () {
    double resolveAuthoritativePrice(Map<String, dynamic> product) {
      final num? sellingPriceNum = product['selling_price'] as num?;
      return (sellingPriceNum != null && sellingPriceNum > 0)
          ? sellingPriceNum.toDouble()
          : (product['price'] as num).toDouble();
    }

    test('Uses selling_price when available and positive', () {
      final p = {'price': 50.0, 'selling_price': 38.0};
      expect(resolveAuthoritativePrice(p), equals(38.0));
    });

    test('Falls back to base price when selling_price is null', () {
      final p = {'price': 50.0, 'selling_price': null};
      expect(resolveAuthoritativePrice(p), equals(50.0));
    });

    test('Falls back to base price when selling_price is zero', () {
      final p = {'price': 50.0, 'selling_price': 0.0};
      expect(resolveAuthoritativePrice(p), equals(50.0));
    });
  });

  group('Accessibility & Big Font Text Scaler Clamp Test', () {
    test('Clamps extreme font scaling within safe bounds [0.85, 1.35]', () {
      const normalScaler = TextScaler.linear(1.0);
      expect(normalScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35).scale(16), equals(16.0));

      const largeScaler = TextScaler.linear(1.6);
      expect(largeScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35).scale(16), equals(16 * 1.35));

      const hugeScaler = TextScaler.linear(2.2);
      expect(hugeScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35).scale(16), equals(16 * 1.35));

      const smallScaler = TextScaler.linear(0.6);
      expect(smallScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.35).scale(16), equals(16 * 0.85));
    });
  });
}
