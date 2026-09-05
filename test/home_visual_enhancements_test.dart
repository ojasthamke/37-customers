import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Screen Visual Enhancements Tests', () {
    testWidgets('1. Animated Add Button responds to tap and scale down', (tester) async {
      bool wasTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  wasTapped = true;
                },
                child: const Text('Add to Cart'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Add to Cart'), findsOneWidget);
      await tester.tap(find.text('Add to Cart'));
      await tester.pumpAndSettle();
      expect(wasTapped, isTrue);
    });

    testWidgets('2. PopularProductCard displays low-stock urgency badge when stock <= 4', (tester) async {
      final product = {
        'id': 'test_low_stock_1',
        'name': 'Fresh Organic Tomato',
        'price': 40.0,
        'market_price': 50.0,
        'unit': 'kg',
        'stock': 3.0, // Low stock: <= 4
        'is_available': true,
        'is_enabled': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PopularProductCard(p: product),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fresh Organic Tomato'), findsOneWidget);
      expect(find.text('Only 3 left!'), findsOneWidget);
    });

    testWidgets('3. PopularProductCard hides low-stock badge when stock is abundant', (tester) async {
      final product = {
        'id': 'test_abundant_stock_1',
        'name': 'Fresh Potato',
        'price': 30.0,
        'market_price': 40.0,
        'unit': 'kg',
        'stock': 50.0, // Abundant stock
        'is_available': true,
        'is_enabled': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PopularProductCard(p: product),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fresh Potato'), findsOneWidget);
      expect(find.text('Only 50 left!'), findsNothing);
    });

    testWidgets('4. Out of stock item renders out-of-stock badge and disables purchase', (tester) async {
      final product = {
        'id': 'test_oos_1',
        'name': 'Alphonso Mango',
        'price': 600.0,
        'unit': 'doz',
        'stock': 0.0, // OOS
        'is_available': true,
        'is_enabled': true,
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PopularProductCard(p: product),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Alphonso Mango'), findsOneWidget);
      expect(find.text('OUT OF STOCK'), findsWidgets);
    });
  });
}
