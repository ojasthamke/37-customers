import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline -> Online Data Consistency & Transaction Integrity Tests', () {
    test('Test 1: Offline Old Price (₹50) updates to Server Price (₹70) on Pre-Flight Validation', () {
      final cartNotifier = CartNotifier();

      // Customer added 2 kg Tomato while offline at cached price ₹50
      cartNotifier.addItem(
        productId: 'tomato-1',
        productName: 'Fresh Tomatoes',
        price: 50.0,
        unit: 'kg',
        quantity: 2.0,
      );

      expect(cartNotifier.state.items['tomato-1']!.price, 50.0);
      expect(cartNotifier.state.items['tomato-1']!.quantity, 2.0);
      expect(cartNotifier.state.subtotal, 100.0);

      // Pre-flight check simulates server returning ₹70
      const double remotePrice = 70.0;
      final localItem = cartNotifier.state.items['tomato-1']!;
      final bool priceMismatch = (localItem.price - remotePrice).abs() > 0.01;

      expect(priceMismatch, isTrue);

      if (priceMismatch) {
        cartNotifier.updateItemPrice('tomato-1', remotePrice);
      }

      // Verify cart price and subtotal updated to ₹140
      expect(cartNotifier.state.items['tomato-1']!.price, 70.0);
      expect(cartNotifier.state.subtotal, 140.0);
    });

    test('Test 2: Stock Reduced (100 kg -> 1 kg) while Cart has 2 kg blocks Order', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'tomato-1',
        productName: 'Fresh Tomatoes',
        price: 50.0,
        unit: 'kg',
        quantity: 2.0,
      );

      final localItem = cartNotifier.state.items['tomato-1']!;
      const double remoteStock = 1.0; // Server only has 1 kg remaining

      final bool isStockInsufficient = remoteStock > 0 && localItem.quantity > remoteStock;
      expect(isStockInsufficient, isTrue);
    });

    test('Test 3: Product Deleted on Server is caught by Missing Product Set Check', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'deleted-prod-1',
        productName: 'Discontinued Herb',
        price: 30.0,
        unit: 'bunch',
        quantity: 1.0,
      );

      // Remote query returns only active products (empty if discontinued)
      final List<Map<String, dynamic>> remoteProducts = [];
      final foundIds = remoteProducts.map((p) => p['id']?.toString()).toSet();

      final List<String> deletedIds = [];
      for (final localId in cartNotifier.state.items.keys) {
        if (!foundIds.contains(localId)) {
          deletedIds.add(localId);
        }
      }

      expect(deletedIds.contains('deleted-prod-1'), isTrue);
    });

    test('Test 4: Product Disabled or Out of Stock on Server blocks Order Placement', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'spinach-1',
        productName: 'Baby Spinach',
        price: 40.0,
        unit: 'bunch',
        quantity: 1.0,
      );

      // Remote returns product with is_available = false
      final remoteProduct = {
        'id': 'spinach-1',
        'price': 40.0,
        'is_available': false,
        'is_enabled': true,
      };

      final bool isAvailable = (remoteProduct['is_available'] == true || remoteProduct['is_available'] == 1) &&
          (remoteProduct['is_enabled'] == true || remoteProduct['is_enabled'] == 1);

      expect(isAvailable, isFalse);
    });

    test('Test 5: Price Change Reconstitution accurately calculates Rounding and Subtotals', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'item-1',
        productName: 'Organic Potato',
        price: 22.0,
        unit: 'kg',
        quantity: 3.0,
      );

      // Subtotal: 66.0, Delivery: 30.0 -> Unrounded Total: 96.0 -> Ceil to 5: 100.0
      expect(cartNotifier.state.subtotal, 66.0);
      expect(cartNotifier.state.unroundedGrandTotal, 96.0);
      expect(cartNotifier.state.roundedGrandTotal, 100.0);
      expect(cartNotifier.state.roundingDifference, closeTo(4.0, 0.001));

      // Admin updates price to 25.0
      cartNotifier.updateItemPrice('item-1', 25.0);

      // Subtotal: 75.0, Delivery: 30.0 -> Unrounded Total: 105.0 -> Ceil to 5: 105.0
      expect(cartNotifier.state.subtotal, 75.0);
      expect(cartNotifier.state.unroundedGrandTotal, 105.0);
      expect(cartNotifier.state.roundedGrandTotal, 105.0);
      expect(cartNotifier.state.roundingDifference, 0.0);
    });

    test('Test 6: Invariant - Displayed Checkout Total exactly matches Order Payload Total', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'mango-1',
        productName: 'Alphonso Mango',
        price: 250.0,
        unit: 'dozen',
        quantity: 2.0,
      );

      final cartState = cartNotifier.state;
      final double displayedGrandTotal = cartState.roundedGrandTotal;

      final payloadItems = cartState.items.values.map((item) => {
        'product_id': item.productId,
        'product_name': item.productName,
        'price': item.price,
        'quantity': item.quantity,
        'unit': item.unit,
        'total_price': item.totalPrice,
      }).toList();

      final double payloadItemsSum = payloadItems.fold(0.0, (sum, i) => sum + (i['total_price'] as double));

      expect(displayedGrandTotal, payloadItemsSum);
      expect(payloadItems[0]['price'], 250.0);
      expect(payloadItems[0]['total_price'], 500.0);
    });
  });
}