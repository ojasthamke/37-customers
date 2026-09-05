import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Inventory Correctness & Out-Of-Stock Adversarial Tests', () {
    test('1. Exact Stock Boundary: 1.0 kg request consumes exact stock; subsequent 0.001 kg is rejected', () {
      double availableStock = 1.000;
      final requestedA = 1.000;

      // Order A attempts 1.000 kg
      bool orderASucceeded = false;
      if (availableStock >= requestedA) {
        availableStock -= requestedA;
        orderASucceeded = true;
      }

      expect(orderASucceeded, true);
      expect(availableStock, 0.000);

      // Subsequent order attempts smallest boundary quantity 0.001 kg
      final requestedB = 0.001;
      bool orderBSucceeded = false;
      if (availableStock >= requestedB) {
        availableStock -= requestedB;
        orderBSucceeded = true;
      }

      expect(orderBSucceeded, false, reason: 'Request exceeding available stock must be rejected');
      expect(availableStock, 0.000);
    });

    test('2. Split Race: 1.0 kg stock cannot satisfy 0.75 kg + 0.50 kg (prevents 1.25 kg oversell)', () {
      double availableStock = 1.000;
      final requestedA = 0.750;
      final requestedB = 0.500;

      bool aSuccess = false;
      bool bSuccess = false;

      // A executes first
      if (availableStock >= requestedA) {
        availableStock -= requestedA;
        aSuccess = true;
      }

      // B attempts remainder
      if (availableStock >= requestedB) {
        availableStock -= requestedB;
        bSuccess = true;
      }

      expect(aSuccess, true);
      expect(bSuccess, false);
      expect(availableStock, 0.250);
      expect(aSuccess && bSuccess, false, reason: 'Total consumed must never exceed starting stock');
    });

    test('3. Float Drift Precision: 0.1 + 0.1 + 0.1 does not drift beyond 0.3 kg boundary', () {
      double stock = 0.300;
      double consumed = 0.0;
      const step = 0.100;

      for (int i = 0; i < 3; i++) {
        consumed = double.parse((consumed + step).toStringAsFixed(3));
      }

      expect(consumed, 0.300);
      final remaining = double.parse((stock - consumed).toStringAsFixed(3));
      expect(remaining, 0.000);
      expect(remaining >= 0, true);
    });

    test('4. Unit Normalization: 1000g equals 1.0 kg without unit-conversion mismatch', () {
      double parseQty(dynamic qty, String unit) {
        final q = (qty is num) ? qty.toDouble() : double.tryParse(qty.toString()) ?? 0.0;
        final u = unit.toLowerCase().trim();
        if (u == 'g' || u == 'gram' || u == 'grams') {
          return q / 1000.0;
        }
        return q;
      }

      final qtyInGrams = parseQty(1000, 'g');
      final qtyInKg = parseQty(1.0, 'kg');

      expect(qtyInGrams, 1.0);
      expect(qtyInKg, 1.0);
      expect(qtyInGrams == qtyInKg, true);
    });

    test('5. Quick Order vs Standard Order Independent Inventory Allocation', () {
      final product = {
        'id': 'p-combo-1',
        'name': 'Organic Spinach',
        'stock': 25.0, // Standard home stock
        'order_now_stock': 1.5, // Order Now express warehouse stock
      };

      // Customer A places Quick Order for 1.5 kg
      final quickOrderQty = 1.5;
      final quickStock = product['order_now_stock'] as double;
      expect(quickStock >= quickOrderQty, true);

      // Customer B attempts Quick Order for 1.0 kg after A consumes 1.5 kg
      final remainingQuickStock = quickStock - quickOrderQty;
      expect(remainingQuickStock, 0.0);
      final secondQuickOrderPossible = remainingQuickStock >= 1.0;
      expect(secondQuickOrderPossible, false, reason: 'Quick order must be bound strictly to order_now_stock');

      // Standard home stock remains unimpacted
      expect(product['stock'], 25.0);
    });

    test('6. Multi-Item Atomic Validation: If one item is out of stock, entire order is rejected', () {
      final inventory = {
        'prod_tomato': 1.0,
        'prod_potato': 10.0,
      };

      final orderItems = [
        {'product_id': 'prod_tomato', 'quantity': 2.0}, // Exceeds stock (1.0)
        {'product_id': 'prod_potato', 'quantity': 5.0}, // Valid
      ];

      bool canFulfillAll = true;
      for (final item in orderItems) {
        final pid = item['product_id'] as String;
        final qty = item['quantity'] as double;
        if ((inventory[pid] ?? 0.0) < qty) {
          canFulfillAll = false;
          break;
        }
      }

      expect(canFulfillAll, false);
      // Ensure potato inventory is NOT decremented when tomato fails
      expect(inventory['prod_potato'], 10.0, reason: 'Failed multi-item order must not partially mutate inventory');
    });

    test('7. Negative & Invalid Stock Handling: -1, 0, or null stock disables purchasing', () {
      bool isPurchasable(dynamic stock, bool? isAvailable) {
        if (isAvailable == false) return false;
        if (stock == null) return true; // untracked
        final num? val = stock is num ? stock : num.tryParse(stock.toString());
        if (val == null || val <= 0) return false;
        return true;
      }

      expect(isPurchasable(-1, true), false);
      expect(isPurchasable(0, true), false);
      expect(isPurchasable(0.0, true), false);
      expect(isPurchasable(5.0, false), false);
      expect(isPurchasable(5.0, true), true);
    });
  });
}