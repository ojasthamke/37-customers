import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplibhaji_customers/core/utils/string_utils.dart';
import 'package:aplibhaji_customers/features/cart/cart_screen.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/features/catalog/catalog_provider.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Produce Image & URL Dictionary Tests', () {
    test('Handles Supabase storage relative paths and full URLs', () {
      final fullUrl = 'https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/product-images/tomato.jpg';
      expect(getProductImage('Tomato', fullUrl), fullUrl);

      final relPath = 'product-images/potato.jpg';
      expect(getProductImage('Potato', relPath), contains('https://xsqaxvbrjvhgemlfgoxn.supabase.co/storage/v1/object/public/product-images/potato.jpg'));

      final spaceUrl = 'https://example.com/my fresh tomato.jpg';
      expect(getProductImage('Tomato', spaceUrl), 'https://example.com/my%20fresh%20tomato.jpg');
    });

    test('Bilingual dictionary fallback for 80+ Marathi, Hindi, English produce', () {
      final testItems = [
        'Bharit Vange',
        'Bhendi',
        'Dodhke',
        'Karle',
        'Lasun',
        'Shevga',
        'Gavar',
        'Palak',
        'Methi',
        'Fulgobi',
        'Spring Onion',
        'Dhemsha',
        'Limbu',
        'Gajar',
        'Kakdi',
        'Lauki',
        'Beet Root',
        'Batata',
        'Kanda',
        'Tomato',
        'Shimla Mirchi',
        'Kothimbir',
        'Aale',
        'Kobi',
        'Matar',
        'Karela',
        'Bhindi',
        'Poha',
      ];

      for (final item in testItems) {
        final img = getProductImage(item, null);
        expect(img, isNotEmpty, reason: 'Failed for item $item');
        expect(img.startsWith('https://images.unsplash.com/'), isTrue, reason: 'Unsplash URL expected for $item');
      }
    });
  });

  group('Big Font Scaling & Cart UI Layout Tests', () {
    testWidgets('Empty Cart renders with Buy Again section under 1.8x font scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lastOrderProvider.overrideWith((ref) => Future.value({
              'id': 'ord-123',
              'order_items': [
                {
                  'product_id': 'p-1',
                  'product_name': 'Fresh Palak',
                  'price': 25.0,
                  'quantity': 1.0,
                  'unit': 'bunch',
                },
                {
                  'product_id': 'p-2',
                  'product_name': 'Batata (Potato)',
                  'price': 40.0,
                  'quantity': 2.0,
                  'unit': 'kg',
                },
              ],
            })),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.8),
              ),
              child: const CartScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Buy Again'), findsOneWidget);
      expect(find.text('Reorder All →'), findsOneWidget);
      expect(find.text('Fresh Palak'), findsOneWidget);
      expect(find.text('Batata (Potato)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Active Cart with items renders bill summary under 1.8x font scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          allProductsProvider.overrideWith((ref) => Stream.value([
            {
              'id': 'p-1',
              'name': 'Fresh Palak',
              'price': 25.0,
              'stock': 10.0,
              'is_available': true,
              'unit': 'bunch',
            },
          ])),
          lastOrderProvider.overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeCartNotifierProvider).addItem(
        productId: 'p-1',
        productName: 'Fresh Palak',
        price: 25.0,
        unit: 'bunch',
        quantity: 2.0,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.8),
              ),
              child: const CartScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fresh Palak'), findsOneWidget);
      expect(find.text('Proceed to Checkout'), findsOneWidget);
      expect(find.text('Grand Total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
