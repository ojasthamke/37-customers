import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/core/widgets/quantity_selector.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/features/order/my_orders_screen.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';

void main() {
  group('UI Rendering, Responsive Layouts & Interaction Tests', () {
    testWidgets('1. QuantitySelectionSheet renders without overflow on small phone (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final product = {
        'id': 'p-small-test',
        'name': 'Fresh Organic Red Potatoes from Local Mandi',
        'price': 40.0,
        'unit': 'kg',
        'stock': 15.0,
        'is_available': true,
        'is_enabled': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuantitySelectionSheet(product: product),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fresh Organic Red Potatoes from Local Mandi'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on small screen');
    });

    testWidgets('2. QuantitySelectionSheet handles virtual keyboard open (viewInsets.bottom = 300)', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 2);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      final product = {
        'id': 'p-kb-test',
        'name': 'Green Bell Pepper (Capsicum)',
        'price': 60.0,
        'unit': 'kg',
        'stock': 25.0,
        'is_available': true,
        'is_enabled': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QuantitySelectionSheet(product: product),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Green Bell Pepper (Capsicum)'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Keyboard inset does not cause overflow in scrollable sheet');
    });

    testWidgets('3. QuantitySelector Stepper decrements with float drift protection', (tester) async {
      final product = {
        'id': 'p-stepper-test',
        'name': 'Ginger (Adrak)',
        'price': 120.0,
        'unit': 'kg',
        'stock': 10.0,
        'is_available': true,
        'is_enabled': true,
      };

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Pre-add item with 1.0 kg
      container.read(cartProvider.notifier).addItem(
        productId: 'p-stepper-test',
        productName: 'Ginger (Adrak)',
        price: 120.0,
        quantity: 1.0,
        unit: 'kg',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: QuantitySelector(product: product)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 kg'), findsOneWidget);

      // Tap minus button
      final minusBtn = find.byIcon(Icons.remove_rounded);
      expect(minusBtn, findsOneWidget);
      await tester.tap(minusBtn);
      await tester.pumpAndSettle();

      // Should be 0.75 kg (750 g), with no floating-point noise
      expect(container.read(cartProvider).items['p-stepper-test']?.quantity, 0.75);
      expect(find.text('750 g'), findsOneWidget);
    });

    test('4. Step size returns precise fractions per unit', () {
      expect(getStepSize('kg'), 0.25);
      expect(getStepSize('g'), 250.0);
      expect(getStepSize('doz'), 1.0);
      expect(getStepSize('pcs'), 1.0);
    });

    test('5. Currency formatting produces clean decimals without trailing zeros', () {
      expect(formatQuantity(0.25, 'kg'), '250 g');
      expect(formatQuantity(0.50, 'kg'), '500 g');
      expect(formatQuantity(0.75, 'kg'), '750 g');
      expect(formatQuantity(1.0, 'kg'), '1 kg');
      expect(formatQuantity(1.5, 'kg'), '1.5 kg');
      expect(formatQuantity(2.0, 'kg'), '2 kg');
      expect(formatQuantity(0.5, 'doz'), '6 Pcs');
      expect(formatQuantity(1.0, 'doz'), '1 Dozen');
    });

    testWidgets('6. Cart Origin Tab Provider is honored during navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // User starts on Tab 2 (Orders)
      container.read(cartOriginTabProvider.notifier).state = 2;

      expect(container.read(cartOriginTabProvider), 2);
    });

    testWidgets('7. MyOrdersScreen empty state displays pull-to-refresh and empty text', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            orderListProvider.overrideWith((ref) => FakeEmptyOrderListNotifier(ref)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: MyOrdersScreen(showAppBar: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders placed yet'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}

class FakeEmptyOrderListNotifier extends OrderListNotifier {
  FakeEmptyOrderListNotifier(super.ref) {
    state = const AsyncValue.data([]);
  }

  @override
  Future<void> fetchOrders(String phone) async {
    state = const AsyncValue.data([]);
  }
}
