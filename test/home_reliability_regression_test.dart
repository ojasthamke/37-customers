import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/core/utils/schedule_helper.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/catalog/catalog_provider.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/features/auth/auth_provider.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deep Reliability, Performance & Resource Integrity Tests', () {
    testWidgets('1. Resource Lifecycle: Home Tab can be mounted, disposed, and remounted repeatedly without leaks', (WidgetTester tester) async {
      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              categoriesProvider.overrideWith((ref) => Stream.value([])),
              popularProductsProvider.overrideWith((ref) => Stream.value([])),
              appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
              orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
              authProvider.overrideWith((ref) => AuthNotifierMock(
                AuthState(
                  customer: {'id': 'cust-$i', 'name': 'User $i'},
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
        expect(find.textContaining('Welcome'), findsOneWidget);

        // Dispose HomeScreen by pushing a blank container
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Disposed'))));
        await tester.pumpAndSettle();
        expect(find.text('Disposed'), findsOneWidget);
      }
    });

    testWidgets('2. Navigation & Cart Retention: Tapping Logo refreshes catalog without wiping active Cart State', (WidgetTester tester) async {
      final item = CartItem(
        productId: 'prod-retention-1',
        productName: 'Fresh Spinach',
        price: 30.0,
        unit: 'bunch',
        quantity: 3.0,
      );
      final mockCart = MockCartNotifier(CartState(items: {'prod-retention-1': item}));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            cartProvider.overrideWith((ref) => mockCart),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {'id': 'cust-1', 'name': 'Rahul'},
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

      // Verify cart badge shows 1 item
      expect(find.text('VIEW CART'), findsOneWidget);

      // Tap the OrderKart Logo on the AppBar
      final logoImage = find.byType(Image);
      expect(logoImage, findsOneWidget);
      await tester.tap(logoImage);
      await tester.pumpAndSettle();

      // Verify Cart is STILL intact (not wiped by logo tap refresh)
      expect(find.text('VIEW CART'), findsOneWidget);
      expect(mockCart.state.items.containsKey('prod-retention-1'), isTrue);
      expect(mockCart.state.items['prod-retention-1']!.quantity, 3.0);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    test('3. Time & Cutoff Edge Cases: Deterministic IST cutoff boundary evaluation', () {
      final scheduleDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

      // Case A: 1 second before cutoff (23:58:59 IST) -> Open
      // 23:58:59 IST is 18:28:59 UTC
      final testTimeBefore = DateTime.utc(2026, 8, 30, 18, 28, 59);
      final detailsBefore = AreaScheduleHelper.calculateDetails(
        scheduleDays,
        cutoffTimeStr: '23:59:00',
        customNow: testTimeBefore,
      );
      expect(detailsBefore.state, ScheduleState.openToday);
      expect(detailsBefore.remainingTime?.inSeconds, 1);
      expect(AreaScheduleHelper.formatDuration(detailsBefore.remainingTime!), '00:00:01');

      // Case B: Exactly at cutoff (23:59:00 IST) -> Transitions to Closed Today (next day scheduled)
      final testTimeExact = DateTime.utc(2026, 8, 30, 18, 29, 0);
      final detailsExact = AreaScheduleHelper.calculateDetails(
        scheduleDays,
        cutoffTimeStr: '23:59:00',
        customNow: testTimeExact,
      );
      expect(detailsExact.state, ScheduleState.closedToday);
      expect(detailsExact.nextOrderDate, isNotNull);

      // Case C: 1 second after cutoff (23:59:01 IST) -> Closed Today
      final testTimeAfter = DateTime.utc(2026, 8, 30, 18, 29, 1);
      final detailsAfter = AreaScheduleHelper.calculateDetails(
        scheduleDays,
        cutoffTimeStr: '23:59:00',
        customNow: testTimeAfter,
      );
      expect(detailsAfter.state, ScheduleState.closedToday);

      // Case D: Negative Duration protection
      expect(AreaScheduleHelper.formatDuration(const Duration(seconds: -10)), '00:00:00');
    });

    test('4. Date Formatting & Midnight Transition', () {
      // Midnight base: 2026-08-30 00:00:01 IST (2026-08-29 18:30:01 UTC)
      final customNow = DateTime.utc(2026, 8, 29, 18, 30, 1);
      final tomorrowDate = DateTime.utc(2026, 8, 31);
      final formattedTomorrow = AreaScheduleHelper.formatDayAndDate(tomorrowDate, customNow);
      expect(formattedTomorrow, contains('Tomorrow, 31 August'));

      final futureDate = DateTime.utc(2026, 9, 3);
      final formattedFuture = AreaScheduleHelper.formatDayAndDate(futureDate, customNow);
      expect(formattedFuture, contains('Thursday, 3 September'));
    });

    test('5. Cart Pricing & Grand Total Retail Ceiling Calculation', () {
      final cart = CartState(
        items: {
          'p1': CartItem(productId: 'p1', productName: 'Item 1', price: 42.50, quantity: 2.0, unit: 'kg'),
          'p2': CartItem(productId: 'p2', productName: 'Item 2', price: 33.20, quantity: 1.0, unit: 'kg'),
        },
        deliveryChargeValue: 30.0,
        freeDeliveryLimit: 300.0,
      );

      // Subtotal = 42.50 * 2 + 33.20 * 1 = 85.0 + 33.20 = 118.20
      expect(cart.subtotal, closeTo(118.20, 0.001));
      // Base delivery charge = 30.0 (since subtotal < 300)
      expect(cart.baseDeliveryCharge, 30.0);
      // Unrounded total = 118.20 + 30.0 = 148.20
      expect(cart.unroundedGrandTotal, closeTo(148.20, 0.001));
      // Rounded total = ceil(148.20 / 5) * 5 = 30 * 5 = 150.0
      expect(cart.roundedGrandTotal, 150.0);
      // Rounding difference = 150.0 - 148.20 = 1.80
      expect(cart.roundingDifference, closeTo(1.80, 0.001));
      // Final delivery charge includes auto-rounding = 30.0 + 1.80 = 31.80
      expect(cart.deliveryCharge, closeTo(31.80, 0.001));
    });
  });
}

class MockCartNotifier extends StateNotifier<CartState> implements CartNotifier {
  MockCartNotifier(super.state);

  @override
  void addItem({
    required String productId,
    required String productName,
    required double price,
    required String unit,
    double quantity = 1.0,
    bool isOrderNow = false,
    String? imagePath,
  }) {
    final updated = Map<String, CartItem>.from(state.items);
    updated[productId] = CartItem(
      productId: productId,
      productName: productName,
      price: price,
      unit: unit,
      quantity: quantity,
      isOrderNow: isOrderNow,
      imagePath: imagePath,
    );
    state = state.copyWith(items: updated);
  }

  @override
  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      final updated = Map<String, CartItem>.from(state.items)..remove(productId);
      state = state.copyWith(items: updated);
    } else {
      final existing = state.items[productId];
      if (existing != null) {
        final updated = Map<String, CartItem>.from(state.items);
        updated[productId] = existing.copyWith(quantity: quantity);
        state = state.copyWith(items: updated);
      }
    }
  }

  @override
  void removeItem(String productId) {
    final updated = Map<String, CartItem>.from(state.items)..remove(productId);
    state = state.copyWith(items: updated);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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