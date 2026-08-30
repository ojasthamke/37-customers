import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  group('Cart Navigation Origin & Context Tests', () {
    test('Scenario 1: Quick Order (tab 2) -> Cart (tab 1) records origin 2', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start on Quick Order (NOW)
      container.read(activeTabProvider.notifier).state = 2;
      container.read(isViewingQuickOrderCartProvider.notifier).state = true;
      expect(container.read(activeTabProvider), 2);
      expect(container.read(isViewingQuickOrderCartProvider), true);

      // User opens Cart from Quick Order
      container.read(cartOriginTabProvider.notifier).state = 2;
      container.read(activeTabProvider.notifier).state = 1;

      expect(container.read(activeTabProvider), 1);
      expect(container.read(cartOriginTabProvider), 2);
      expect(container.read(isViewingQuickOrderCartProvider), true);

      // User presses Back -> reads cartOriginTabProvider
      final origin = container.read(cartOriginTabProvider);
      container.read(activeTabProvider.notifier).state = origin;

      expect(container.read(activeTabProvider), 2); // Returns to Quick Order
      expect(container.read(isViewingQuickOrderCartProvider), true);
    });

    test('Scenario 2: Home (tab 0) -> Cart (tab 1) records origin 0 and returns to Home', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start on Home
      container.read(activeTabProvider.notifier).state = 0;
      container.read(isViewingQuickOrderCartProvider.notifier).state = false;

      // User opens Cart from Home
      container.read(cartOriginTabProvider.notifier).state = 0;
      container.read(activeTabProvider.notifier).state = 1;

      expect(container.read(activeTabProvider), 1);
      expect(container.read(cartOriginTabProvider), 0);
      expect(container.read(isViewingQuickOrderCartProvider), false);

      // User presses Back -> returns to Home
      final origin = container.read(cartOriginTabProvider);
      container.read(activeTabProvider.notifier).state = origin;

      expect(container.read(activeTabProvider), 0);
    });

    test('Scenario 3: Orders (tab 3) -> Cart (tab 1) records origin 3 and returns to Orders', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start on Orders
      container.read(activeTabProvider.notifier).state = 3;

      // User opens Cart from Orders
      container.read(cartOriginTabProvider.notifier).state = 3;
      container.read(activeTabProvider.notifier).state = 1;

      expect(container.read(activeTabProvider), 1);
      expect(container.read(cartOriginTabProvider), 3);

      // User presses Back -> returns to Orders
      final origin = container.read(cartOriginTabProvider);
      container.read(activeTabProvider.notifier).state = origin;

      expect(container.read(activeTabProvider), 3);
    });
  });
}
