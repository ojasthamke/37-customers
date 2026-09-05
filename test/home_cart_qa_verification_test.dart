import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  group('Home & Cart QA Fixes Verification Tests', () {

    test('Fix 1: Free Delivery + POS Rounding must NOT inflate delivery charge', () {
      final items = {
        'prod_1': CartItem(
          productId: 'prod_1',
          productName: 'Fresh Tomatoes',
          price: 151.0,
          quantity: 2.0, // total = 302.0
          unit: 'kg',
        ),
      };

      final cartState = CartState(
        items: items,
        deliveryChargeValue: 30.0,
        freeDeliveryLimit: 300.0,
      );

      // Verify calculations
      expect(cartState.subtotal, 302.0);
      expect(cartState.baseDeliveryCharge, 0.0, reason: 'Subtotal exceeds threshold');
      expect(cartState.unroundedGrandTotal, 302.0);
      expect(cartState.roundedGrandTotal, 305.0);
      expect(cartState.roundingDifference, 3.0);
      
      // Crucial fix assertion: deliveryCharge MUST be 0.0, NOT 3.0!
      expect(cartState.deliveryCharge, 0.0, reason: 'Delivery fee must remain Free (0.0)');
      expect(cartState.separateRoundingAdjustment, 3.0, reason: 'Rounding adjustment is shown separately');
      expect(cartState.grandTotal, 305.0);
    });

    test('Fix 1.b: Below Free Delivery Threshold correctly folds rounding into delivery charge', () {
      final items = {
        'prod_1': CartItem(
          productId: 'prod_1',
          productName: 'Potatoes',
          price: 143.0,
          quantity: 1.0,
          unit: 'kg',
        ),
      };

      final cartState = CartState(
        items: items,
        deliveryChargeValue: 30.0,
        freeDeliveryLimit: 300.0,
      );

      expect(cartState.subtotal, 143.0);
      expect(cartState.baseDeliveryCharge, 30.0);
      expect(cartState.unroundedGrandTotal, 173.0);
      expect(cartState.roundedGrandTotal, 175.0);
      expect(cartState.roundingDifference, 2.0);
      
      // When delivery is NOT free, the Rs 2 roundoff is folded into delivery charge (30 + 2 = 32)
      expect(cartState.deliveryCharge, 32.0);
      expect(cartState.separateRoundingAdjustment, 0.0);
      expect(cartState.grandTotal, 175.0);
    });

    test('Fix 5: Deleted product from backend must be detected as out-of-stock in cart check', () {
      final cartItems = {
        'prod_deleted': CartItem(
          productId: 'prod_deleted',
          productName: 'Discontinued Item',
          price: 50.0,
          quantity: 1.0,
          unit: 'kg',
        ),
      };

      // Catalog from server does NOT contain 'prod_deleted'
      final List<Map<String, dynamic>> allProducts = [
        {'id': 'prod_active', 'name': 'Active Product', 'stock': 10.0, 'is_available': true},
      ];

      // Replicating cart_screen out-of-stock logic:
      bool hasStockOutItems = false;
      for (final it in cartItems.values) {
        final matching = allProducts.firstWhere(
          (p) => p['id']?.toString() == it.productId,
          orElse: () => <String, dynamic>{},
        );
        if (matching.isEmpty) {
          hasStockOutItems = true;
          break;
        }
        final double st = (matching['stock'] as num?)?.toDouble() ?? 0.0;
        final bool avail = (matching['is_available'] == true || matching['is_available'] == 1) &&
            (matching['is_enabled'] == null ||
                matching['is_enabled'] == true ||
                matching['is_enabled'] == 1) &&
            st > 0;
        if (!avail) {
          hasStockOutItems = true;
          break;
        }
      }

      expect(hasStockOutItems, isTrue, reason: 'Deleted product must flag cart as having out-of-stock items');
    });

    test('CartItem decimal precision and boundary guards', () {
      final item = CartItem(
        productId: 'p1',
        productName: 'Organic Spinach',
        price: 24.50,
        quantity: 0.250,
        unit: 'kg',
      );

      expect(item.totalPrice, 6.125);
    });
  });
}
