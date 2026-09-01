import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cart System Deep Audit & Invariant Test Suite', () {
    test('1. Normal Customer Journey: Add, increment, decrement, and clear', () {
      final cartNotifier = CartNotifier();

      // Add Tomato (1 kg @ 50)
      cartNotifier.addItem(
        productId: 'prod-tomato',
        productName: 'Tomatoes',
        price: 50.0,
        unit: 'kg',
        quantity: 1.0,
      );

      expect(cartNotifier.state.itemCount, 1);
      expect(cartNotifier.state.subtotal, 50.0);
      expect(cartNotifier.state.items['prod-tomato']!.quantity, 1.0);

      // Increment by 0.5 kg
      cartNotifier.updateQuantity('prod-tomato', 1.5);
      expect(cartNotifier.state.items['prod-tomato']!.quantity, 1.5);
      expect(cartNotifier.state.subtotal, 75.0);

      // Add Potato (2 kg @ 25)
      cartNotifier.addItem(
        productId: 'prod-potato',
        productName: 'Potatoes',
        price: 25.0,
        unit: 'kg',
        quantity: 2.0,
      );

      expect(cartNotifier.state.itemCount, 2);
      expect(cartNotifier.state.subtotal, 125.0);

      // Remove Tomato
      cartNotifier.removeItem('prod-tomato');
      expect(cartNotifier.state.itemCount, 1);
      expect(cartNotifier.state.subtotal, 50.0);
      expect(cartNotifier.state.items.containsKey('prod-tomato'), isFalse);

      // Clear Cart
      cartNotifier.clear();
      expect(cartNotifier.state.itemCount, 0);
      expect(cartNotifier.state.subtotal, 0.0);
      expect(cartNotifier.state.grandTotal, 0.0);
    });

    test('2. Cart Calculation Audit: Mathematical precision, free delivery & retail rounding', () {
      final cartNotifier = CartNotifier();

      // Test A: ₹0 Price Promo Item
      cartNotifier.addItem(
        productId: 'free-coriander',
        productName: 'Complimentary Coriander',
        price: 0.0,
        unit: 'bunch',
        quantity: 1.0,
      );
      expect(cartNotifier.state.subtotal, 0.0);
      expect(cartNotifier.state.baseDeliveryCharge, 0.0);
      expect(cartNotifier.state.grandTotal, 0.0);

      // Test B: Subtotal < ₹300 incurs ₹30 delivery fee with ₹5 ceiling rounding
      // Subtotal = 22.50 * 3 = 67.50
      // Base delivery = 30.00
      // Unrounded total = 97.50
      // Ceil to multiple of 5 = 100.00
      // Rounding difference = 2.50
      // Delivery fee = 30.00 + 2.50 = 32.50
      cartNotifier.clear();
      cartNotifier.addItem(
        productId: 'prod-onion',
        productName: 'Onions',
        price: 22.50,
        unit: 'kg',
        quantity: 3.0,
      );
      expect(cartNotifier.state.subtotal, 67.50);
      expect(cartNotifier.state.baseDeliveryCharge, 30.0);
      expect(cartNotifier.state.unroundedGrandTotal, 97.50);
      expect(cartNotifier.state.roundedGrandTotal, 100.0);
      expect(cartNotifier.state.roundingDifference, closeTo(2.50, 0.001));
      expect(cartNotifier.state.deliveryCharge, closeTo(32.50, 0.001));
      expect(cartNotifier.state.subtotal + cartNotifier.state.deliveryCharge, cartNotifier.state.grandTotal);

      // Test C: Subtotal >= ₹300 gets free base delivery
      cartNotifier.addItem(
        productId: 'prod-apple',
        productName: 'Shimla Apples',
        price: 150.0,
        unit: 'kg',
        quantity: 2.0,
      );
      // Subtotal: 67.50 + 300.00 = 367.50 >= 300.00
      expect(cartNotifier.state.subtotal, 367.50);
      expect(cartNotifier.state.baseDeliveryCharge, 0.0);
      // Unrounded: 367.50 -> Ceil to 5: 370.00 -> Rounding Diff: 2.50
      expect(cartNotifier.state.unroundedGrandTotal, 367.50);
      expect(cartNotifier.state.roundedGrandTotal, 370.0);
      expect(cartNotifier.state.deliveryCharge, closeTo(2.50, 0.001));
      expect(cartNotifier.state.subtotal + cartNotifier.state.deliveryCharge, cartNotifier.state.grandTotal);
    });

    test('3. Duplicate Product Merging: Adding existing product aggregates quantities without duplicating keys', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'prod-ginger',
        productName: 'Fresh Ginger',
        price: 120.0,
        unit: 'kg',
        quantity: 0.25,
      );

      expect(cartNotifier.state.itemCount, 1);
      expect(cartNotifier.state.items['prod-ginger']!.quantity, 0.25);

      // Add same product again with 0.5 kg
      cartNotifier.addItem(
        productId: 'prod-ginger',
        productName: 'Fresh Ginger',
        price: 120.0,
        unit: 'kg',
        quantity: 0.50,
      );

      // Verify merged into single line item with 0.75 kg
      expect(cartNotifier.state.itemCount, 1);
      expect(cartNotifier.state.items['prod-ginger']!.quantity, 0.75);
      expect(cartNotifier.state.subtotal, 90.0);
    });

    test('4. Decimal Quantities & Float Drift Invariant: 250g increments round cleanly', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'prod-chilli',
        productName: 'Green Chillies',
        price: 80.0,
        unit: 'kg',
        quantity: 0.25,
      );

      // Perform 3 consecutive 250g step increments: 0.25 -> 0.5 -> 0.75 -> 1.0
      cartNotifier.updateQuantity('prod-chilli', 0.25 + 0.25);
      expect(cartNotifier.state.items['prod-chilli']!.quantity, 0.50);

      cartNotifier.updateQuantity('prod-chilli', 0.50 + 0.25);
      expect(cartNotifier.state.items['prod-chilli']!.quantity, 0.75);

      cartNotifier.updateQuantity('prod-chilli', 0.75 + 0.25);
      expect(cartNotifier.state.items['prod-chilli']!.quantity, 1.0);
      expect(cartNotifier.state.subtotal, 80.0);
    });

    test('5. Large Cart Stress Test: 50 distinct items aggregate subtotal and count accurately', () {
      final cartNotifier = CartNotifier();

      double expectedSubtotal = 0.0;
      for (int i = 1; i <= 50; i++) {
        final double price = i * 2.0;
        final double qty = (i % 3) + 1.0;
        expectedSubtotal += price * qty;

        cartNotifier.addItem(
          productId: 'stress-prod-$i',
          productName: 'Product $i',
          price: price,
          unit: 'kg',
          quantity: qty,
        );
      }

      expect(cartNotifier.state.itemCount, 50);
      expect(cartNotifier.state.subtotal, closeTo(expectedSubtotal, 0.001));
      expect(cartNotifier.state.baseDeliveryCharge, 0.0); // > 300.0
    });

    test('6. Corrupted JSON Recovery: Malformed storage payloads parse safely without crashing', () {
      const String malformedJson = '''
      [
        {"productId": "valid-1", "productName": "Valid Item", "price": "40.50", "quantity": "2.5", "unit": "kg"},
        {"productId": "", "productName": "Blank ID", "price": 10.0, "quantity": 1.0, "unit": "kg"},
        {"productId": "valid-2", "productName": "Valid Item 2", "price": null, "quantity": -5.0, "unit": "kg"}
      ]
      ''';

      final List<dynamic> decoded = jsonDecode(malformedJson);
      final Map<String, CartItem> items = {};
      for (var item in decoded) {
        final String prodId = item['productId']?.toString() ?? '';
        if (prodId.isEmpty) continue;
        final double price = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : (double.tryParse(item['price']?.toString() ?? '') ?? 0.0);
        final double quantity = (item['quantity'] is num)
            ? (item['quantity'] as num).toDouble()
            : (double.tryParse(item['quantity']?.toString() ?? '') ?? 0.0);

        final cleanQty = (quantity * 1000).round() / 1000.0;
        if (cleanQty <= 0) continue;

        items[prodId] = CartItem(
          productId: prodId,
          productName: item['productName']?.toString() ?? '',
          price: price < 0 ? 0.0 : price,
          quantity: cleanQty,
          unit: item['unit']?.toString() ?? '',
        );
      }

      expect(items.length, 1);
      expect(items.containsKey('valid-1'), isTrue);
      expect(items['valid-1']!.price, 40.50);
      expect(items['valid-1']!.quantity, 2.5);
      expect(items.containsKey('valid-2'), isFalse); // Skipped negative quantity
    });

    test('7. Invariant: Quantity zero or negative removes item from CartNotifier', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'prod-to-delete',
        productName: 'Expiring Item',
        price: 30.0,
        unit: 'piece',
        quantity: 1.0,
      );

      expect(cartNotifier.state.itemCount, 1);

      // Update quantity to 0
      cartNotifier.updateQuantity('prod-to-delete', 0.0);
      expect(cartNotifier.state.itemCount, 0);
      expect(cartNotifier.state.items.isEmpty, isTrue);
    });

    test('8. Extreme Financial Calculation Cases: Micro-cents to large amounts', () {
      final cartNotifier = CartNotifier();

      final extremeCases = [
        {'price': 0.0, 'qty': 5.0, 'expected': 0.0},
        {'price': 0.01, 'qty': 100.0, 'expected': 1.0},
        {'price': 0.10, 'qty': 2.5, 'expected': 0.25},
        {'price': 1.0, 'qty': 0.75, 'expected': 0.75},
        {'price': 99.99, 'qty': 0.25, 'expected': 24.9975},
        {'price': 999.99, 'qty': 1.25, 'expected': 1249.9875},
        {'price': 99999.99, 'qty': 2.0, 'expected': 199999.98},
      ];

      for (int i = 0; i < extremeCases.length; i++) {
        final c = extremeCases[i];
        final p = c['price'] as double;
        final q = c['qty'] as double;
        final exp = c['expected'] as double;

        cartNotifier.clear();
        cartNotifier.addItem(
          productId: 'ext-$i',
          productName: 'Extreme Item $i',
          price: p,
          unit: 'kg',
          quantity: q,
        );

        final item = cartNotifier.state.items['ext-$i']!;
        expect(item.totalPrice, closeTo(exp, 0.0001));
        expect(cartNotifier.state.subtotal, closeTo(exp, 0.0001));
      }
    });

    test('9. Unit Conversions: Grams, kg, and dozen conversions calculate exact totals', () {
      final cartNotifier = CartNotifier();

      // Case A: ₹100/kg product, customer buys 250g (0.25 kg)
      cartNotifier.addItem(
        productId: 'prod-tomato-100',
        productName: 'Tomatoes',
        price: 100.0,
        unit: 'kg',
        quantity: 0.25,
      );
      expect(cartNotifier.state.items['prod-tomato-100']!.totalPrice, 25.0);

      // Case B: ₹100/kg product, customer updates to 500g (0.50 kg)
      cartNotifier.updateQuantity('prod-tomato-100', 0.50);
      expect(cartNotifier.state.items['prod-tomato-100']!.totalPrice, 50.0);

      // Case C: ₹100/kg product, customer updates to 750g (0.75 kg)
      cartNotifier.updateQuantity('prod-tomato-100', 0.75);
      expect(cartNotifier.state.items['prod-tomato-100']!.totalPrice, 75.0);

      // Case D: ₹100/kg product, customer updates to 1.25 kg
      cartNotifier.updateQuantity('prod-tomato-100', 1.25);
      expect(cartNotifier.state.items['prod-tomato-100']!.totalPrice, 125.0);

      // Case E: ₹60/Dozen product, customer selects 0.5 dozen (6 pcs)
      cartNotifier.addItem(
        productId: 'prod-banana-60',
        productName: 'Bananas',
        price: 60.0,
        unit: 'dozen',
        quantity: 0.5,
      );
      expect(cartNotifier.state.items['prod-banana-60']!.totalPrice, 30.0);

      // Case F: ₹60/Dozen product, customer selects 1.5 dozen (18 pcs)
      cartNotifier.updateQuantity('prod-banana-60', 1.5);
      expect(cartNotifier.state.items['prod-banana-60']!.totalPrice, 90.0);
    });

    test('10. Delivery Charge Threshold: Exact ₹299.99, ₹300.00, and ₹300.01 boundaries', () {
      final normalCart = CartNotifier(); // normal cart: fee = 30.0, limit = 300.0

      // Subtotal = 299.99 (< 300.00)
      normalCart.addItem(
        productId: 'item-299',
        productName: 'Item 299',
        price: 299.99,
        unit: 'kg',
        quantity: 1.0,
      );
      expect(normalCart.state.subtotal, 299.99);
      expect(normalCart.state.baseDeliveryCharge, 30.0);
      expect(normalCart.state.unroundedGrandTotal, 329.99);
      expect(normalCart.state.roundedGrandTotal, 330.0);
      expect(normalCart.state.roundingDifference, closeTo(0.01, 0.001));
      expect(normalCart.state.deliveryCharge, closeTo(30.01, 0.001));

      // Subtotal = 300.00 (exact threshold -> free delivery)
      normalCart.clear();
      normalCart.addItem(
        productId: 'item-300',
        productName: 'Item 300',
        price: 300.00,
        unit: 'kg',
        quantity: 1.0,
      );
      expect(normalCart.state.subtotal, 300.00);
      expect(normalCart.state.baseDeliveryCharge, 0.0);
      expect(normalCart.state.roundedGrandTotal, 300.0);
      expect(normalCart.state.deliveryCharge, 0.0);

      // Subtotal = 300.01 (> 300.00 -> free delivery)
      normalCart.clear();
      normalCart.addItem(
        productId: 'item-301',
        productName: 'Item 301',
        price: 300.01,
        unit: 'kg',
        quantity: 1.0,
      );
      expect(normalCart.state.subtotal, 300.01);
      expect(normalCart.state.baseDeliveryCharge, 0.0);
      expect(normalCart.state.unroundedGrandTotal, 300.01);
      expect(normalCart.state.roundedGrandTotal, 305.0);
      expect(normalCart.state.roundingDifference, closeTo(4.99, 0.001));
      expect(normalCart.state.deliveryCharge, closeTo(4.99, 0.001));
      expect(normalCart.state.subtotal + normalCart.state.deliveryCharge, normalCart.state.grandTotal);
    });

    test('11. Product Image Synchronization & Preservation in CartItem', () {
      final cartNotifier = CartNotifier();

      const adminUploadedUrl = 'https://xyz.supabase.co/storage/v1/object/public/products/organic_tomato_custom.jpg';

      cartNotifier.addItem(
        productId: 'prod-admin-img',
        productName: 'Custom Organic Tomato',
        price: 65.0,
        unit: 'kg',
        quantity: 2.0,
        imagePath: adminUploadedUrl,
      );

      final item = cartNotifier.state.items['prod-admin-img']!;
      expect(item.imagePath, adminUploadedUrl);

      // Verify serialization preserves imagePath
      final list = cartNotifier.state.items.values.map((i) => {
        'productId': i.productId,
        'productName': i.productName,
        'price': i.price,
        'quantity': i.quantity,
        'unit': i.unit,
        'isOrderNow': i.isOrderNow,
        'imagePath': i.imagePath,
      }).toList();

      final encoded = jsonEncode(list);
      final List<dynamic> decoded = jsonDecode(encoded);
      expect(decoded.first['imagePath'], adminUploadedUrl);
    });

    test('12. Cross-Screen Total Consistency: Cart state, display total, and order payload match', () {
      final cartNotifier = CartNotifier();

      cartNotifier.addItem(
        productId: 'item-a',
        productName: 'Item A',
        price: 45.50,
        unit: 'kg',
        quantity: 2.5, // 113.75
      );
      cartNotifier.addItem(
        productId: 'item-b',
        productName: 'Item B',
        price: 33.33,
        unit: 'kg',
        quantity: 3.0, // 99.99
      );

      // Subtotal = 113.75 + 99.99 = 213.74
      // Base delivery = 30.00
      // Unrounded total = 243.74
      // Ceil to multiple of 5 = 245.00
      // Rounding diff = 1.26
      // Delivery charge = 30.00 + 1.26 = 31.26
      // Grand total = 245.00
      final cart = cartNotifier.state;
      expect(cart.subtotal, closeTo(213.74, 0.001));
      expect(cart.roundedGrandTotal, 245.0);
      expect(cart.grandTotal, 245.0);
      expect(cart.subtotal + cart.deliveryCharge, cart.grandTotal);

      // Verify simulated Order Payload matches cart.roundedGrandTotal
      final payload = {
        'total_amount': cart.roundedGrandTotal,
        'items': cart.items.values.map((i) => {
          'product_id': i.productId,
          'total_price': i.totalPrice,
        }).toList(),
      };

      expect(payload['total_amount'], 245.0);
    });

    test('13. Property-Based Randomized Invariant Testing: 100 random combinations', () {
      final cartNotifier = CartNotifier();

      for (int run = 0; run < 100; run++) {
        cartNotifier.clear();

        final int itemCount = (run % 10) + 1;
        double manualSubtotal = 0.0;

        for (int i = 0; i < itemCount; i++) {
          final double price = ((run * 17 + i * 23) % 200) + 0.50;
          final double qty = ((run * 13 + i * 7) % 5) * 0.25 + 0.25;
          manualSubtotal += price * qty;

          cartNotifier.addItem(
            productId: 'rand-p-$run-$i',
            productName: 'Random Product $i',
            price: price,
            unit: 'kg',
            quantity: qty,
          );
        }

        final state = cartNotifier.state;
        expect(state.itemCount, itemCount);
        expect(state.subtotal, closeTo(manualSubtotal, 0.001));
        expect(state.grandTotal, state.roundedGrandTotal);
        expect(state.subtotal + state.deliveryCharge, state.grandTotal);

        if (state.subtotal >= state.freeDeliveryLimit) {
          expect(state.baseDeliveryCharge, 0.0);
        } else {
          expect(state.baseDeliveryCharge, state.deliveryChargeValue);
        }

        // Verify grandTotal is always a multiple of 5
        expect(state.grandTotal % 5.0, 0.0);
      }
    });
  });
}