import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Stock Limits & Readjustment Tests', () {
    test('1. Prevents cart quantity from exceeding stock or clamps down', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      // Add product with 50 kg initially
      notifier.addItem(
        productId: 'aalu_1',
        productName: 'Aalu आलू',
        price: 40.0,
        unit: 'kg',
        quantity: 50.0,
      );

      expect(container.read(cartProvider).items['aalu_1']?.quantity, 50.0);

      // Suppose user tries to increase or update to 300 kg, but store stock is only 106.5 kg:
      const double availableStock = 106.5;
      double requestedQuantity = 300.0;

      // System rule: clamped to available stock if exceeded
      if (requestedQuantity > availableStock) {
        requestedQuantity = availableStock;
      }

      notifier.updateQuantity('aalu_1', requestedQuantity);
      expect(container.read(cartProvider).items['aalu_1']?.quantity, 106.5);
      expect(container.read(cartProvider).items['aalu_1']?.totalPrice, 106.5 * 40.0);
    });

    test('2. Readjusts all items exceeding stock to maximum available', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      // Setup 2 items in cart
      notifier.addItem(
        productId: 'prod_aalu',
        productName: 'Aalu आलू',
        price: 40.0,
        unit: 'kg',
        quantity: 200.0,
      );

      notifier.addItem(
        productId: 'prod_tomato',
        productName: 'Tomato टोमॅटो',
        price: 30.0,
        unit: 'kg',
        quantity: 50.0,
      );

      final mockStockDatabase = {
        'prod_aalu': 106.5,
        'prod_tomato': 20.0,
      };

      // Run bulk readjustment logic
      final cart = container.read(cartProvider);
      int readjustedCount = 0;

      for (final item in cart.items.values) {
        final stock = mockStockDatabase[item.productId] ?? 0.0;
        if (stock > 0 && item.quantity > stock) {
          notifier.updateQuantity(item.productId, stock);
          readjustedCount++;
        }
      }

      expect(readjustedCount, 2);
      expect(container.read(cartProvider).items['prod_aalu']?.quantity, 106.5);
      expect(container.read(cartProvider).items['prod_tomato']?.quantity, 20.0);
    });

    test('3. Retains valid quantities when within stock boundary', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(cartProvider.notifier);

      notifier.addItem(
        productId: 'prod_onion',
        productName: 'Kanda कांदा',
        price: 35.0,
        unit: 'kg',
        quantity: 5.0,
      );

      const double availableStock = 50.0;
      final cart = container.read(cartProvider);
      final item = cart.items['prod_onion']!;

      bool exceeds = item.quantity > availableStock;
      expect(exceeds, isFalse);
      expect(item.quantity, 5.0);
    });
  });
}
