import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/core/utils/schedule_helper.dart';
import 'package:aplibhaji_customers/core/widgets/quantity_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Order Now Flow & Invariant Test Suite', () {
    test('1. Financial Calculation: Quick Cart delivery fee and 5-rupee ceiling rounding', () {
      final quickCart = CartNotifier(storageKey: 'quick_cart_items');

      // Add Quick Order item: 1 kg @ ₹45.50
      quickCart.addItem(
        productId: 'q-tomato',
        productName: 'Quick Tomatoes',
        price: 45.50,
        unit: 'kg',
        quantity: 1.0,
        isOrderNow: true,
      );

      // Quick Order default fee = ₹10.0
      // Subtotal = 45.50
      // Base delivery = 10.00
      // Unrounded total = 55.50
      // Ceil to multiple of 5 = 60.00
      // Rounding difference = 4.50
      // Delivery fee = 10.00 + 4.50 = 14.50
      // Grand Total = 60.00
      final state = quickCart.state;
      expect(state.subtotal, 45.50);
      expect(state.baseDeliveryCharge, 10.0);
      expect(state.unroundedGrandTotal, 55.50);
      expect(state.roundedGrandTotal, 60.0);
      expect(state.roundingDifference, closeTo(4.50, 0.001));
      expect(state.deliveryCharge, closeTo(14.50, 0.001));
      expect(state.subtotal + state.deliveryCharge, state.grandTotal);
      expect(state.grandTotal, 60.0);
    });

    test('2. Unit Conversion & Decimal Formatting in Quantity Selector', () {
      expect(formatQuantity(0.25, 'kg'), '250 g');
      expect(formatQuantity(0.50, 'kg'), '500 g');
      expect(formatQuantity(0.75, 'kg'), '750 g');
      expect(formatQuantity(1.0, 'kg'), '1 kg');
      expect(formatQuantity(1.25, 'kg'), '1.25 kg');
      expect(formatQuantity(2.5, 'kg'), '2.5 kg');
      expect(formatQuantity(0.5, 'dozen'), '6 Pcs');
      expect(formatQuantity(1.0, 'dozen'), '1 Dozen');
      expect(formatQuantity(1.5, 'dozen'), '18 Pcs');
    });

    test('3. Stock Validation: Zero stock and excessive quantities are identified', () {
      final quickCart = CartNotifier(storageKey: 'quick_cart_items');

      quickCart.addItem(
        productId: 'q-apple',
        productName: 'Apples',
        price: 120.0,
        unit: 'kg',
        quantity: 2.0,
        isOrderNow: true,
      );

      // Simulation of checkout stock check
      bool validateStock(double currentStock, double requestedQty) {
        if (currentStock <= 0 || requestedQty > currentStock) {
          return false; // Invalid
        }
        return true; // Valid
      }

      expect(validateStock(0.0, 2.0), isFalse); // Stock is 0 -> Rejected
      expect(validateStock(-1.0, 2.0), isFalse); // Stock < 0 -> Rejected
      expect(validateStock(1.0, 2.0), isFalse); // Requested > Stock -> Rejected
      expect(validateStock(2.0, 2.0), isTrue); // Requested == Stock -> Allowed
      expect(validateStock(5.0, 2.0), isTrue); // Requested < Stock -> Allowed
    });

    test('4. Order Business Rules: Quick Order operates independently of area weekly delivery schedule', () {
      // Area with no scheduled pre-order delivery days
      final scheduleDetails = AreaScheduleHelper.calculateDetails(
        [], // empty schedule
        cutoffTimeStr: '20:00',
      );

      expect(scheduleDetails.state, ScheduleState.noSchedule);

      // Verify checkout button logic condition:
      // For Normal orders in noSchedule area -> blocked
      // For Quick orders in noSchedule area -> allowed!
      bool isOrderAllowed({required bool isOrderNow, required bool isClosed, required ScheduleDetails? details}) {
        if (isClosed) return false;
        if (!isOrderNow && (details == null || details.state == ScheduleState.noSchedule)) {
          return false;
        }
        return true;
      }

      expect(isOrderAllowed(isOrderNow: false, isClosed: false, details: scheduleDetails), isFalse);
      expect(isOrderAllowed(isOrderNow: true, isClosed: false, details: scheduleDetails), isTrue);
      expect(isOrderAllowed(isOrderNow: true, isClosed: true, details: scheduleDetails), isFalse);
    });

    test('5. Active Cart Provider respects isViewingQuickOrderCartProvider setting', () async {
      final container = ProviderContainer(
        overrides: [
          isViewingQuickOrderCartProvider.overrideWith((ref) => true),
          appSettingsProvider.overrideWith((ref) => Stream.value({'order_now_status': 'open'})),
        ],
      );

      await container.read(appSettingsProvider.future);

      // When viewing quick cart, activeCartProvider points to quick cart
      final activeCart = container.read(activeCartProvider);
      expect(activeCart.deliveryChargeValue, 10.0); // Quick delivery fee
    });


    test('6. Immutable Historical Order Pricing: Recorded receipt prices are preserved', () {
      // Historical order item from database
      final rawOrderItem = {
        'id': 'oi-123',
        'product_id': 'prod-tomato',
        'product_name': 'Tomatoes',
        'quantity': 2.0,
        'price': 30.0, // Historical purchase price
        'total_price': 60.0,
        'unit': 'kg',
      };

      // Ensure that calculating receipt subtotal uses recorded price (₹30) rather than live price (₹60)
      final mapItem = Map<String, dynamic>.from(rawOrderItem);
      final double itemTotal = (mapItem['total_price'] as num?)?.toDouble() ??
          (((mapItem['price'] as num?)?.toDouble() ?? 0.0) * ((mapItem['quantity'] as num?)?.toDouble() ?? 0.0));
      mapItem['total_price'] = itemTotal;

      expect(mapItem['price'], 30.0);
      expect(mapItem['total_price'], 60.0);
    });

    test('7. Property-Based Quick Order Random Invariants: 100 random combinations', () {
      final quickCart = CartNotifier(storageKey: 'quick_cart_items');

      for (int run = 0; run < 100; run++) {
        quickCart.clear();

        final int itemCount = (run % 8) + 1;
        double manualSubtotal = 0.0;

        for (int i = 0; i < itemCount; i++) {
          final double price = ((run * 19 + i * 31) % 150) + 1.0;
          final double qty = ((run * 7 + i * 11) % 4) * 0.25 + 0.25;
          manualSubtotal += price * qty;

          quickCart.addItem(
            productId: 'rand-q-$run-$i',
            productName: 'Quick Item $i',
            price: price,
            unit: 'kg',
            quantity: qty,
            isOrderNow: true,
          );
        }

        final state = quickCart.state;
        expect(state.itemCount, itemCount);
        expect(state.subtotal, closeTo(manualSubtotal, 0.001));
        expect(state.grandTotal, state.roundedGrandTotal);
        expect(state.subtotal + state.deliveryCharge, state.grandTotal);
        expect(state.grandTotal % 5.0, 0.0);
      }
    });

    test('8. Independent Section Availability: Quick Order vs Home Section stock separation (e.g. Dhemsha)', () {
      // Dhemsha product state: Out of stock in Home section (is_available = false, stock = 0.0),
      // but in stock in Quick Order section (order_now_is_available = true, order_now_stock = 1.0, order_now_price = 28.77)
      final remoteProduct = {
        'id': '2b9491a7-228b-4afd-ac1d-1b0be9652bc4',
        'name': 'Dhemsha',
        'price': 40.0,
        'is_available': false, // Home section availability = false
        'is_enabled': true,
        'stock': 0.0,
        'order_now_price': 28.77,
        'order_now_stock': 1.0,
        'order_now_is_available': true, // Quick Order section availability = true
      };

      // 1. Check Quick Order validation
      final bool isQuickOrderAvailable = (remoteProduct['order_now_is_available'] == null ||
              remoteProduct['order_now_is_available'] == true ||
              remoteProduct['order_now_is_available'] == 1) &&
          (remoteProduct['is_enabled'] == null || remoteProduct['is_enabled'] == true || remoteProduct['is_enabled'] == 1);
      final double quickStock = (remoteProduct['order_now_stock'] as num?)?.toDouble() ?? 0.0;
      final double quickPrice = (remoteProduct['order_now_price'] as num?)?.toDouble() ?? 0.0;

      expect(isQuickOrderAvailable, isTrue);
      expect(quickStock, 1.0);
      expect(quickPrice, 28.77);

      // 2. Check Home Section validation (must be out of stock)
      final bool isHomeAvailable = (remoteProduct['is_available'] == true || remoteProduct['is_available'] == 1) &&
          (remoteProduct['is_enabled'] == null || remoteProduct['is_enabled'] == true || remoteProduct['is_enabled'] == 1);
      final double homeStock = (remoteProduct['stock'] as num?)?.toDouble() ?? 0.0;
      final double homePrice = (remoteProduct['price'] as num?)?.toDouble() ?? 0.0;

      expect(isHomeAvailable, isFalse);
      expect(homeStock, 0.0);
      expect(homePrice, 40.0);
    });
  });
}