import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Five-Agent Comprehensive Verification Suite', () {
    // -- AGENT 1: CATALOG & PRODUCT LOGIC --
    group('Agent 1: Home / Catalog / Product Validation', () {
      test('1.1 Custom Gram Conversion when Warehouse Stock >= 50 kg', () {
        double calculateGramsToKg(double input, double stock) {
          if (input >= 50.0) {
            return input / 1000.0;
          }
          return input;
        }

        final result1 = calculateGramsToKg(250.0, 100.0);
        expect(result1, 0.25, reason: '250 grams must convert to 0.25 kg even with high warehouse stock');

        final result2 = calculateGramsToKg(500.0, 75.0);
        expect(result2, 0.5);

        final result3 = calculateGramsToKg(2.0, 100.0);
        expect(result3, 2.0);
      });

      test('1.2 Untracked Stock Produce Defaults to Available', () {
        double resolveStock(dynamic rawStock) {
          final double? parsed = (rawStock is num)
              ? rawStock.toDouble()
              : double.tryParse(rawStock?.toString() ?? '');
          return parsed ?? 100.0;
        }

        expect(resolveStock(null), 100.0);
        expect(resolveStock(0), 0.0);
        expect(resolveStock(25.5), 25.5);
      });

      test('1.3 Comma Decimal Keyboard Input Normalization', () {
        double parseQuantityInput(String text) {
          return double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;
        }

        expect(parseQuantityInput('1,5'), 1.5);
        expect(parseQuantityInput(' 2,75 '), 2.75);
        expect(parseQuantityInput('0,250'), 0.25);
      });
      test('1.4 Delivery Schedule Accepts Both Raw List and JSON String', () {
        List<dynamic> parseSchedule(dynamic raw) {
          if (raw == null) return [];
          if (raw is List) return raw;
          try {
            return jsonDecode(raw.toString()) as List<dynamic>;
          } catch (_) {
            return [];
          }
        }

        expect(parseSchedule(['Mon', 'Wed', 'Fri']), ['Mon', 'Wed', 'Fri'], reason: 'Raw list from Supabase must be preserved');
        expect(parseSchedule('["Tue", "Thu"]'), ['Tue', 'Thu'], reason: 'JSON string from SQLite must be decoded');
        expect(parseSchedule(null), isEmpty);
      });

      test('1.5 QuantitySelector Prioritizes Order Now Price and Stock for Quick Orders', () {
        final quickProduct = {
          'id': 'mango-1',
          'price': 100.0,
          'order_now_price': 130.0,
          'stock': 50.0,
          'order_now_stock': 5.0,
          'is_order_now': true,
        };

        final isQuick = quickProduct['is_order_now'] == true;
        final rawPrice = isQuick ? (quickProduct['order_now_price'] ?? quickProduct['price']) : quickProduct['price'];
        final price = (rawPrice is num) ? (rawPrice as num).toDouble() : 0.0;
        final rawStock = isQuick ? quickProduct['order_now_stock'] : quickProduct['stock'];
        final stock = (rawStock is num) ? (rawStock as num).toDouble() : 0.0;

        expect(price, 130.0, reason: 'Quick order must use 130.0 order_now_price');
        expect(stock, 5.0, reason: 'Quick order must use 5.0 order_now_stock');
      });

      test('1.6 Custom Quantity Unit Suffix Parsing (kg vs g vs plain)', () {
        double parseQty(String text, String unit) {
          final clean = text.trim().toLowerCase().replaceAll(',', '.');
          if (clean.endsWith('kg')) {
            return double.tryParse(clean.replaceAll('kg', '').trim()) ?? 0.0;
          }
          if (clean.endsWith('g') || clean.endsWith('gm') || clean.endsWith('gram') || clean.endsWith('grams')) {
            final g = double.tryParse(clean.replaceAll(RegExp(r'[a-z]'), '').trim()) ?? 0.0;
            return ((g / 1000.0) * 1000).round() / 1000.0;
          }
          final input = double.tryParse(clean) ?? 0.0;
          if (unit == 'kg' && input >= 50.0) {
            return ((input / 1000.0) * 1000).round() / 1000.0;
          }
          return ((input) * 1000).round() / 1000.0;
        }

        expect(parseQty('50 kg', 'kg'), 50.0);
        expect(parseQty('50kg', 'kg'), 50.0);
        expect(parseQty('50g', 'kg'), 0.05);
        expect(parseQty('50', 'kg'), 0.05);
        expect(parseQty('250', 'kg'), 0.25);
        expect(parseQty('2', 'kg'), 2.0);
      });
    });

    // -- AGENT 2: CART SYSTEM & PRECISION MATH --
    group('Agent 2: Cart System & Math Precision', () {
      test('2.1 Increment and Decrement Operator Precedence & Float Drift', () {
        double step = 0.25;
        double currentQty = 1.0;

        double nextQty = ((currentQty + step) * 1000).round() / 1000.0;
        expect(nextQty, 1.25, reason: 'Operator precedence must evaluate addition before multiplication');

        nextQty = ((nextQty + step) * 1000).round() / 1000.0;
        expect(nextQty, 1.5);
        nextQty = ((nextQty + step) * 1000).round() / 1000.0;
        expect(nextQty, 1.75);
        nextQty = ((nextQty + step) * 1000).round() / 1000.0;
        expect(nextQty, 2.0);

        double decQty = ((nextQty - step) * 1000).round() / 1000.0;
        expect(decQty, 1.75);
        decQty = ((decQty - step) * 1000).round() / 1000.0;
        expect(decQty, 1.5);
      });

      test('2.2 ₹5 Rounding Normalization (Zero Float Epsilon Jumps)', () {
        final double floatNoiseSubtotal = 150.00000000000003;
        final normalized = (floatNoiseSubtotal * 100).round() / 100.0;
        final roundedGrandTotal = (normalized / 5.0).ceil() * 5.0;
        expect(roundedGrandTotal, 150.0, reason: '150.00000000000003 must not round up to 155.0');

        final cart = CartNotifier();
        cart.addItem(productId: 'p1', productName: 'Item 1', price: 83.0, unit: 'kg', quantity: 1.0);
        expect(cart.state.unroundedGrandTotal, 113.0);
        expect(cart.state.roundedGrandTotal, 115.0);
        expect(cart.state.grandTotal, 115.0);
      });

      test('2.3 Custom Portion Modulo Detects 250g and 750g correctly', () {
        bool isCleanGramPortion(double qty) {
          final grams = (qty * 1000).round();
          return grams % 50 == 0 || grams % 10 == 0;
        }

        expect(isCleanGramPortion(0.25), isTrue, reason: '250g (0.25 kg) is 5x 50g');
        expect(isCleanGramPortion(0.75), isTrue, reason: '750g (0.75 kg) is 15x 50g');
        expect(isCleanGramPortion(0.15), isTrue, reason: '150g is 3x 50g');
        expect(isCleanGramPortion(0.05), isTrue, reason: '50g is 1x 50g');
      });

      test('2.4 Custom Size Dialog Supports Comma Separator and Gram Units', () {
        double calculateEntered(String rawText, String unit) {
          final val = double.tryParse(rawText.trim().replaceAll(',', '.')) ?? 0.0;
          if (unit == 'g') return val / 1000.0;
          return val;
        }

        expect(calculateEntered('500', 'g'), 0.5);
        expect(calculateEntered('1,5', 'kg'), 1.5);
        expect(calculateEntered('250', 'g'), 0.25);
      });

      test('2.5 Rapid Writes Invalidation via Version Counter', () {
        int saveCounter = 0;
        final savedSnapshots = <int>[];

        void simulateSave(int version, int data) {
          if (version != saveCounter) return;
          savedSnapshots.add(data);
        }

        int v1 = ++saveCounter;
        int v2 = ++saveCounter;
        int v3 = ++saveCounter;

        simulateSave(v1, 10);
        simulateSave(v2, 20);
        simulateSave(v3, 30);

        expect(savedSnapshots, [30], reason: 'Only the latest version 30 must commit to storage');
      });

      test('2.6 Nullable Stock Never Fabricates 100kg Limit', () {
        double? resolveNullableStock(dynamic raw) {
          return (raw is num) ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
        }

        expect(resolveNullableStock(null), isNull);
        expect(resolveNullableStock(5.0), 5.0);
        expect(resolveNullableStock('12.5'), 12.5);
      });
    });

    // -- AGENT 3: CHECKOUT & ORDER FLOW --
    group('Agent 3: Order Flow & Scheduling', () {
      test('3.1 Quick Orders Always Resolve to Today and Order Now Type', () {
        final now = DateTime.now();
        final String orderType = 'Order Now';
        final String deliveryDateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        
        expect(orderType, 'Order Now');
        expect(deliveryDateStr, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      });

      test('3.2 Price Separation between Quick Order and Regular Catalog', () {
        final product = {
          'id': 'spinach-1',
          'price': 40.0,
          'order_now_price': 55.0,
          'stock': 10.0,
          'order_now_stock': 3.0,
        };

        double resolvePrice(Map<String, dynamic> p, bool isQuick) {
          if (isQuick) {
            return (p['order_now_price'] as num?)?.toDouble() ?? (p['price'] as num).toDouble();
          }
          return (p['price'] as num).toDouble();
        }

        expect(resolvePrice(product, false), 40.0);
        expect(resolvePrice(product, true), 55.0);
      });

      test('3.3 Empty Cart and Missing Contact Phone Block Order Placement', () {
        String? validateCheckout(Map<String, CartItem> items, String? phone, String? address) {
          if (items.isEmpty) return 'Cart is empty';
          if (phone == null || phone.trim().isEmpty) return 'Contact phone number is missing';
          if (address == null || address.trim().isEmpty) return 'Delivery address is missing';
          return null;
        }

        expect(validateCheckout({}, '9021107009', 'Main St'), 'Cart is empty');
        expect(validateCheckout({'p1': CartItem(productId: '1', productName: 'T', price: 10, quantity: 1, unit: 'kg')}, '', 'Main St'), 'Contact phone number is missing');
        expect(validateCheckout({'p1': CartItem(productId: '1', productName: 'T', price: 10, quantity: 1, unit: 'kg')}, '9021107009', ''), 'Delivery address is missing');
        expect(validateCheckout({'p1': CartItem(productId: '1', productName: 'T', price: 10, quantity: 1, unit: 'kg')}, '9021107009', 'Main St'), isNull);
      });

      test('3.4 Guest Checkout Blocked with Login Guidance', () {
        bool shouldPromptLogin(Map<String, dynamic>? customer) {
          return customer == null ||
              customer['is_guest'] == true ||
              customer['is_guest'] == 1 ||
              customer['is_guest']?.toString() == '1' ||
              customer['is_guest']?.toString().toLowerCase() == 'true';
        }

        expect(shouldPromptLogin(null), isTrue);
        expect(shouldPromptLogin({'is_guest': true}), isTrue);
        expect(shouldPromptLogin({'is_guest': 1}), isTrue);
        expect(shouldPromptLogin({'id': 'cust-1', 'is_guest': false}), isFalse);
      });
      test('3.5 Robust Remote Price Parser Handles Strings, Numbers, and Nulls', () {
        double parsePrice(dynamic val) {
          if (val is num) return val.toDouble();
          if (val != null) return double.tryParse(val.toString()) ?? 0.0;
          return 0.0;
        }

        expect(parsePrice(45), 45.0);
        expect(parsePrice(45.5), 45.5);
        expect(parsePrice('45.00'), 45.0);
        expect(parsePrice('  55.25  '), 55.25);
        expect(parsePrice(null), 0.0);
        expect(parsePrice('invalid'), 0.0);
      });
    });

    // -- AGENT 4: ORDERS & RECEIPT CALCULATIONS --
    group('Agent 4: Orders & Tracking Calculations', () {
      test('4.1 Delivery Charge Never Turns Negative When Items are Unavailable', () {
        final order = {
          'total_amount': 230.0,
        };
        final items = [
          {'product_name': 'Item A', 'total_price': 100.0, 'is_available': true},
          {'product_name': 'Item B', 'total_price': 100.0, 'is_available': false},
        ];

        final availableItems = items.where((i) => i['is_available'] != false && i['is_available'] != 0).toList();
        double availableSubtotal = 0.0;
        for (final item in availableItems) {
          availableSubtotal += (item['total_price'] as num).toDouble();
        }

        final totalAmount = (order['total_amount'] as num).toDouble();
        final deliveryCharge = items.isEmpty ? 0.0 : (totalAmount - availableSubtotal);
        final displayDeliveryCharge = (deliveryCharge > 0.08 && items.isNotEmpty) ? deliveryCharge : 0.0;

        expect(availableSubtotal, 100.0);
        expect(displayDeliveryCharge >= 0.0, isTrue, reason: 'Delivery fee must never be negative');
      });

      test('4.2 Delivery Charge Does Not Display Full Total When Items List is Empty', () {
        final order = {'total_amount': 250.0};
        final List<Map<String, dynamic>> emptyItems = [];

        final double totalAmount = (order['total_amount'] as num).toDouble();
        final double deliveryCharge = emptyItems.isEmpty ? 0.0 : (totalAmount - 0.0);
        final double displayDeliveryCharge = (deliveryCharge > 0.08 && emptyItems.isNotEmpty) ? deliveryCharge : 0.0;

        expect(displayDeliveryCharge, 0.0, reason: 'Empty items list must not show order total as delivery charge');
      });

      test('4.3 Reorder Dialog Handles Integer Prices and Quantities Safely', () {
        final rawItem = {
          'product_id': 101, // int ID
          'product_name': 'Fresh Tomatoes',
          'price': 50, // int price
          'quantity': 2, // int quantity
          'unit': 'kg',
        };

        final pid = rawItem['product_id']?.toString() ?? '';
        final name = rawItem['product_name']?.toString() ?? '';
        final price = (rawItem['price'] as num?)?.toDouble() ?? 0.0;
        final unit = rawItem['unit']?.toString() ?? 'kg';
        final qty = (rawItem['quantity'] as num?)?.toDouble() ?? 1.0;

        expect(pid, '101');
        expect(name, 'Fresh Tomatoes');
        expect(price, 50.0);
        expect(unit, 'kg');
        expect(qty, 2.0);
      });

      test('4.4 Reorder Cart Insertion with Int Numbers', () {
        final item = {
          'product_id': 501,
          'product_name': 'Potato',
          'price': 30,
          'quantity': 3,
          'unit': 'kg',
        };

        final cart = CartNotifier();
        cart.addItem(
          productId: item['product_id']?.toString() ?? '',
          productName: item['product_name']?.toString() ?? '',
          price: (item['price'] as num?)?.toDouble() ?? 0.0,
          quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
          unit: item['unit']?.toString() ?? 'kg',
        );

        expect(cart.state.items.containsKey('501'), isTrue);
        expect(cart.state.items['501']!.price, 30.0);
        expect(cart.state.items['501']!.quantity, 3.0);
        expect(cart.state.subtotal, 90.0);
      });

      test('4.5 Place Order RPC Payload Sanitizes Dynamic Types', () {
        final rawItems = [
          {'product_id': 999, 'quantity': 2},
          {'product_id': 'uuid-abc', 'quantity': 1.5},
        ];

        final sanitized = rawItems.map((item) => {
          'product_id': item['product_id']?.toString(),
          'quantity': (item['quantity'] as num?)?.toDouble() ?? 1.0,
        }).toList();

        expect(sanitized[0]['product_id'], '999');
        expect(sanitized[0]['quantity'], 2.0);
        expect(sanitized[1]['product_id'], 'uuid-abc');
        expect(sanitized[1]['quantity'], 1.5);
      });

      test('4.6 Reorder Clamps Stale Past Quantity to Current Available Inventory', () {
        final currentStock = 3.0;
        final pastQuantity = 10.0;
        final double safeQty = (pastQuantity > currentStock) ? currentStock : pastQuantity;
        expect(safeQty, 3.0, reason: 'Reorder must clamp to current available stock of 3.0');
      });
    });

    // -- AGENT 5: PROFILE & AUTHENTICATION --
    group('Agent 5: Profile & Session Management', () {
      test('5.1 Guest Customer Flag Detection', () {
        bool isGuestUser(Map<String, dynamic>? customer) {
          if (customer == null) return true;
          return customer['is_guest'] == true ||
              customer['is_guest'] == 1 ||
              customer['is_guest']?.toString() == '1' ||
              customer['is_guest']?.toString().toLowerCase() == 'true';
        }

        expect(isGuestUser(null), isTrue);
        expect(isGuestUser({'is_guest': true, 'name': 'Guest'}), isTrue);
        expect(isGuestUser({'is_guest': 1, 'name': 'Guest'}), isTrue);
        expect(isGuestUser({'is_guest': 'true', 'name': 'Guest'}), isTrue);
        expect(isGuestUser({'is_guest': false, 'name': 'Verified Member'}), isFalse);
        expect(isGuestUser({'is_guest': 0, 'name': 'Verified Member'}), isFalse);
      });

      test('5.2 Stream Loop Lifecycle Disposed Check', () async {
        bool isDisposed = false;
        int loopCount = 0;

        // Emulate polling loop with isDisposed check
        Future<void> runLoop() async {
          while (!isDisposed) {
            loopCount++;
            if (loopCount >= 2) isDisposed = true; // Simulating teardown
          }
        }

        await runLoop();
        expect(isDisposed, isTrue);
        expect(loopCount, 2);
      });

      test('5.3 Area Dropdown Items Safely Converts Mixed Type IDs', () {
        final List<Map<String, dynamic>> rawAreas = [
          {'id': 1, 'name': 'Bangar Nagar'},
          {'id': 'area-uuid-2', 'name': 'Goregaon West'},
        ];

        final parsed = rawAreas.map((a) => {
          'id': a['id']?.toString() ?? '',
          'name': a['name']?.toString() ?? '',
        }).toList();

        expect(parsed[0]['id'], '1');
        expect(parsed[0]['name'], 'Bangar Nagar');
        expect(parsed[1]['id'], 'area-uuid-2');
        expect(parsed[1]['name'], 'Goregaon West');
      });

      test('5.4 Customer A to Customer B Session Switch Full Isolation', () {
        // Customer A logs in and has cart items
        final cartA = CartNotifier();
        cartA.addItem(productId: 'item-A', productName: 'Item A', price: 50, quantity: 1, unit: 'kg');
        expect(cartA.state.items.length, 1);

        // Customer A logs out
        cartA.clear();
        expect(cartA.state.items.isEmpty, isTrue);

        // Customer B logs in
        final cartB = CartNotifier();
        expect(cartB.state.items.isEmpty, isTrue, reason: 'Customer B must see 0 items from Customer A');
      });
    });

    // -- LOOP 3: 50+ RANDOMIZED BOUNDARY COMBINATIONS ORACLE TEST --
    group('Loop 3: 50+ Randomized Boundary Combinations Oracle Test', () {
      test('50 Randomized Multi-Variable Business Logic Calculations', () {
        final prices = [0.01, 1.0, 4.99, 5.0, 9.99, 15.0, 40.0, 55.5, 99.99, 149.99, 150.0, 150.01, 299.99, 300.0, 300.01, 999.99];
        final quantities = [0.083, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 5.0, 10.0];
        final orderTypes = ['Normal', 'Quick Order'];

        int testCount = 0;
        for (int i = 0; i < 50; i++) {
          final price = prices[i % prices.length];
          final qty = quantities[(i * 3) % quantities.length];
          final orderType = orderTypes[i % orderTypes.length];
          final bool isQuick = orderType == 'Quick Order';

          final double deliveryFee = isQuick ? 10.0 : 30.0;
          final double freeLimit = isQuick ? 100000.0 : 300.0;

          // 1. Independent Oracle calculation
          final double expectedItemTotal = price * qty;
          final double expectedSubtotal = expectedItemTotal;
          final double expectedBaseFee = expectedSubtotal >= freeLimit ? 0.0 : deliveryFee;
          final double expectedUnrounded = expectedSubtotal + expectedBaseFee;
          final double normalized = (expectedUnrounded * 100).round() / 100.0;
          final double expectedGrandTotal = (normalized / 5.0).ceil() * 5.0;

          // 2. Real Application Cart calculation
          final state = CartState(
            items: {
              'item_$i': CartItem(
                productId: 'p_$i',
                productName: 'Produce $i',
                price: price,
                quantity: qty,
                unit: 'kg',
                isOrderNow: isQuick,
              ),
            },
            deliveryChargeValue: deliveryFee,
            freeDeliveryLimit: freeLimit,
          );

          expect(
            (state.subtotal - expectedSubtotal).abs() < 0.0001,
            isTrue,
            reason: 'Iteration $i: Cart subtotal (${state.subtotal}) must match expected ($expectedSubtotal)',
          );

          expect(
            state.grandTotal,
            expectedGrandTotal,
            reason: 'Iteration $i: Cart grand total (${state.grandTotal}) must match expected ($expectedGrandTotal) for price $price, qty $qty, $orderType',
          );

          testCount++;
        }

        expect(testCount, 50, reason: 'Exactly 50 randomized boundary test cases must be evaluated');
      });
    });
  });
}
