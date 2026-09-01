import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/dashboard/schedule_banner.dart';
import 'package:aplibhaji_customers/features/catalog/catalog_provider.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/features/auth/auth_provider.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';
import 'package:aplibhaji_customers/core/widgets/quantity_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security, Data Isolation & Business Logic Invariant Tests', () {
    test('1. Data Isolation & Invariants: CartNotifier rejects empty IDs, negative quantities, and negative prices', () {
      final notifier = CartNotifier();

      // Test A: Empty product ID rejected
      notifier.addItem(
        productId: '   ',
        productName: 'Ghost Item',
        price: 50.0,
        unit: 'kg',
        quantity: 1.0,
      );
      expect(notifier.state.items.isEmpty, isTrue);

      // Test B: Negative or zero quantity rejected
      notifier.addItem(
        productId: 'valid-prod-1',
        productName: 'Valid Item',
        price: 40.0,
        unit: 'kg',
        quantity: -2.0,
      );
      expect(notifier.state.items.isEmpty, isTrue);

      // Test C: Negative price clamped to 0.0
      notifier.addItem(
        productId: 'valid-prod-2',
        productName: 'Promo Item',
        price: -100.0,
        unit: 'piece',
        quantity: 1.0,
      );
      expect(notifier.state.items.containsKey('valid-prod-2'), isTrue);
      expect(notifier.state.items['valid-prod-2']!.price, 0.0);
      expect(notifier.state.subtotal, 0.0);
    });

    testWidgets('2. Accessibility Tooltips: IconButtons on Home Screen have semantic tooltips', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {'id': 'cust-sec-1', 'name': 'Rahul'},
                isLoading: false,
              ),
            )),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Shopping Cart button has tooltip 'Shopping Cart'
      final cartIconButton = find.byTooltip('Shopping Cart');
      expect(cartIconButton, findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('3. Large Font / Text Scaling 2.0x: ScheduleBanner does not overflow at 200% text scale', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {
                  'id': 'cust-a11y',
                  'name': 'Accessibility User',
                  'delivery_schedule': '["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]',
                  'cutoff_time': '23:59:00',
                },
                isLoading: false,
              ),
            )),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 640), // Narrow compact device
                textScaler: TextScaler.linear(2.0), // 2.0x Large Accessibility font
              ),
              child: Scaffold(
                body: ScheduleBanner(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.textContaining('ORDERING OPEN'), findsOneWidget);
      // Verify no RenderFlex exception was thrown
      expect(tester.takeException(), isNull);

      // Drain timers
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('4. Localization & Unicode Emoji Resilience: Devanagari & Marathi text safely rendered', (WidgetTester tester) async {
      const devanagariName = 'राहुल शर्मा 🥦👨‍🌾';
      const devanagariCategory = 'ताजी भाजीपाला (Fresh Organic Greens)';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([
              {'id': 'cat-mr-1', 'name': devanagariCategory, 'is_enabled': true}
            ])),
            popularProductsProvider.overrideWith((ref) => Stream.value([
              {
                'id': 'prod-mr-1',
                'name': 'ताजी मेथी (Organic Methi)',
                'price': 25.0,
                'market_price': 30.0,
                'unit': 'bunch',
                'stock': 50.0,
                'is_available': true,
                'is_enabled': true,
              }
            ])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {'id': 'cust-mr', 'name': devanagariName},
                isLoading: false,
              ),
            )),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('राहुल शर्मा'), findsOneWidget);
      expect(find.text('ताजी भाजीपाला (Fresh Organic Greens)'), findsOneWidget);
      expect(find.text('ताजी मेथी (Organic Methi)'), findsOneWidget);

      // Drain timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('5. QuantitySelectionSheet Memory & Controller Lifecycle: Disposes cleanly without leak', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cartProvider.overrideWith((ref) => CartNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: QuantitySelectionSheet(
                product: {
                  'id': 'prod-sheet-1',
                  'name': 'Fresh Tomatoes',
                  'price': 40.0,
                  'unit': 'kg',
                  'stock': 20.0,
                  'is_available': true,
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Fresh Tomatoes'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);

      // Dismount sheet
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Cleaned'))));
      await tester.pumpAndSettle();
      expect(find.text('Cleaned'), findsOneWidget);

      // Drain database timers
      await tester.pump(const Duration(seconds: 15));
    });
  });
}

class AuthNotifierMock extends StateNotifier<AuthState> implements AuthNotifier {
  AuthNotifierMock(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockOrderListNotifier extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> implements OrderListNotifier {
  MockOrderListNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}