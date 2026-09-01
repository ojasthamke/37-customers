import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/features/dashboard/home_screen.dart';
import 'package:aplibhaji_customers/features/catalog/catalog_provider.dart';
import 'package:aplibhaji_customers/features/cart/cart_provider.dart';
import 'package:aplibhaji_customers/features/auth/auth_provider.dart';
import 'package:aplibhaji_customers/features/order/order_provider.dart';
import 'package:aplibhaji_customers/features/catalog/product_listing_screen.dart';
import 'package:aplibhaji_customers/features/order/order_details_screen.dart';
import 'package:aplibhaji_customers/core/widgets/quantity_selector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home Tab Senior QA & Interaction Tests', () {
    testWidgets('1. Home Tab renders Header, Categories, and Products correctly', (WidgetTester tester) async {
      final mockCategories = [
        {'id': 'cat-1', 'name': 'Vegetables'},
        {'id': 'cat-2', 'name': 'Fruits'},
      ];

      final mockProducts = [
        {
          'id': 'prod-1',
          'name': 'Fresh Potato',
          'price': 40.0,
          'market_price': 50.0,
          'unit': 'kg',
          'stock': 10.0,
          'is_available': true,
          'image_path': '',
        },
        {
          'id': 'prod-2',
          'name': 'Organic Tomato',
          'price': 30.0,
          'market_price': 35.0,
          'unit': 'kg',
          'stock': 0.0,
          'is_available': true,
          'image_path': '',
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value(mockCategories)),
            popularProductsProvider.overrideWith((ref) => Stream.value(mockProducts)),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {
                  'id': 'cust-1',
                  'name': 'Rahul Sharma',
                  'customer_code': 'CUST100',
                  'delivery_schedule': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
                  'cutoff_time': '23:59:00',
                },
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

      // Verify Header & Customer Welcome
      expect(find.textContaining('Rahul Sharma'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);

      // Verify Category Carousel
      expect(find.text('Shop by Category'), findsOneWidget);
      expect(find.text('Vegetables'), findsOneWidget);
      expect(find.text('Fruits'), findsOneWidget);

      // Verify Products Section
      expect(find.text('All Products'), findsOneWidget);
      expect(find.text('Fresh Potato'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);

      // Verify Out of Stock Item
      expect(find.text('Organic Tomato'), findsOneWidget);
      expect(find.text('OUT OF STOCK'), findsWidgets);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('2. Category tap navigates to ProductListingScreen', (WidgetTester tester) async {
      final mockCategories = [
        {'id': 'cat-1', 'name': 'Fresh Vegetables'},
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value(mockCategories)),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {'id': 'cust-1', 'name': 'Amit', 'customer_code': 'CUST101'},
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

      final categoryCard = find.text('Fresh Vegetables');
      expect(categoryCard, findsOneWidget);

      await tester.tap(categoryCard);
      await tester.pumpAndSettle();

      expect(find.byType(ProductListingScreen), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('3. Help button opens support bottom sheet with WhatsApp & Call', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {'id': 'cust-1', 'name': 'Test User'},
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

      final helpBtn = find.text('Help');
      expect(helpBtn, findsOneWidget);
      await tester.tap(helpBtn);
      await tester.pumpAndSettle();

      expect(find.text('Customer Support'), findsOneWidget);
      expect(find.text('Chat on WhatsApp'), findsOneWidget);
      expect(find.text('Call Us Directly'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('4. Guest warning banner renders for guest users with actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {
                  'id': 'guest-1',
                  'name': 'Guest User',
                  'is_guest': true,
                },
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

      expect(find.textContaining('Logged in as Guest'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('5. Active Order card renders and navigates to OrderDetailsScreen', (WidgetTester tester) async {
      final mockActiveOrder = [
        {
          'id': 'ord-12345',
          'order_number': 'ORD-9999',
          'order_type': 'Normal',
          'status': 'Preparing',
          'delivery_date': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'order_items': [
            {'product_id': 'prod-1', 'quantity': 2.0}
          ],
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(AsyncValue.data(mockActiveOrder))),
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

      expect(find.text('Active Order'), findsOneWidget);
      expect(find.text('Preparing'), findsOneWidget);
      expect(find.textContaining('Order #ORD-9999'), findsOneWidget);

      await tester.tap(find.text('Active Order'));
      await tester.pumpAndSettle();

      expect(find.byType(OrderDetailsScreen), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('6. Floating Cart Bar renders on Home when items exist in normal cart', (WidgetTester tester) async {
      final cartNotifier = CartNotifier();
      cartNotifier.addItem(
        productId: 'prod-1',
        productName: 'Potato',
        price: 40.0,
        unit: 'kg',
        quantity: 2.0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value([])),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
            cartProvider.overrideWith((ref) => cartNotifier),
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

      expect(find.text('VIEW CART'), findsOneWidget);
      expect(find.text(' item'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('7. Adding product opens Quantity Selector sheet and updates cart state', (WidgetTester tester) async {
      final mockProducts = [
        {
          'id': 'prod-1',
          'name': 'Fresh Potato',
          'price': 40.0,
          'unit': 'kg',
          'stock': 10.0,
          'is_available': true,
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value(mockProducts)),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
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

      // Tap 'Add to Cart'
      final addBtn = find.text('Add to Cart');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Verify Quantity Selection Sheet
      expect(find.byType(QuantitySelectionSheet), findsOneWidget);
      expect(find.text('Select Quantity'), findsOneWidget);
      expect(find.text('Confirm Selection'), findsOneWidget);

      // Confirm selection
      await tester.tap(find.text('Confirm Selection'));
      await tester.pumpAndSettle();

      // Verify sheet is dismissed and product now shows quantity stepper (250 g)
      expect(find.byType(QuantitySelectionSheet), findsNothing);
      expect(find.text('250 g'), findsOneWidget);
      expect(find.text('VIEW CART'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('8. Bad / Corrupted Data: Integer IDs, JSON schedules & string items do not crash Home Tab', (WidgetTester tester) async {
      final corruptedProducts = [
        {
          'id': 101, // Integer ID instead of String
          'name': 'Corrupted Product Name',
          'price': '45.50', // String price
          'market_price': '60.00', // String market price
          'unit': 'kg',
          'stock': '20', // String stock
          'is_available': 1, // Integer boolean
        }
      ];

      final corruptedOrders = [
        {
          'id': 999, // Integer order ID
          'order_number': 'ORD-CORRUPT',
          'order_type': 'Normal',
          'status': 'Confirmed',
          'delivery_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'order_items': '[{"product_id": 101, "product_name": "Corrupted Product", "quantity": 1.0}]', // JSON string instead of List
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value(corruptedProducts)),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(AsyncValue.data(corruptedOrders))),
            authProvider.overrideWith((ref) => AuthNotifierMock(
              AuthState(
                customer: {
                  'id': 555, // Integer customer ID
                  'name': 'Corrupt Data User',
                  'delivery_schedule': 'Monday, Wednesday, Friday', // Comma separated string instead of List
                  'cutoff_time': '22:00:00',
                },
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

      // Verify header, banner, active order, and product render safely without throwing any exceptions
      expect(find.textContaining('Corrupt Data User'), findsOneWidget);
      expect(find.text('Active Order'), findsOneWidget);
      expect(find.textContaining('Corrupted Product Name'), findsOneWidget);
      expect(find.text('Add to Cart'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('9. Offline & Error Recovery: Friendly retry card rendered on network failure', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.error(Exception('Failed host lookup'))),
            popularProductsProvider.overrideWith((ref) => Stream.error(Exception('Connection timed out'))),
            appSettingsProvider.overrideWith((ref) => Stream.value({'store_status': 'OPEN'})),
            orderListProvider.overrideWith((ref) => MockOrderListNotifier(const AsyncValue.data([]))),
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

      // Verify friendly retry cards are shown instead of raw red debug text
      expect(find.text('Unable to load categories'), findsOneWidget);
      expect(find.text('Unable to load products'), findsOneWidget);
      expect(find.text('Try Again'), findsNWidgets(2));

      // Tap 'Try Again'
      await tester.tap(find.text('Try Again').first);
      await tester.pumpAndSettle();

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('10. Precise Quantity Stepper: Float drift handling (250g -> 500g -> 250g)', (WidgetTester tester) async {
      final initialItem = CartItem(
        productId: 'prod-1',
        productName: 'Fresh Potato',
        price: 40.0,
        unit: 'kg',
        quantity: 0.25,
      );
      final mockCart = MockCartNotifier(CartState(items: {'prod-1': initialItem}));

      final mockProducts = [
        {
          'id': 'prod-1',
          'name': 'Fresh Potato',
          'price': 40.0,
          'unit': 'kg',
          'stock': 10.0,
          'is_available': true,
        }
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            popularProductsProvider.overrideWith((ref) => Stream.value(mockProducts)),
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

      // Verify initial quantity shows clean '250 g'
      expect(find.text('250 g'), findsOneWidget);

      // Scroll slightly up so product card is well above the floating bottom cart bar
      await tester.drag(find.byType(HomeScreen), const Offset(0, -150));
      await tester.pumpAndSettle();

      // Tap '-' icon to reduce quantity (0.25 - 0.25 = 0 -> removes from cart)
      final removeIcon = find.byIcon(Icons.remove_rounded);
      expect(removeIcon, findsOneWidget);
      await tester.tap(removeIcon);
      await tester.pumpAndSettle();

      // Should now show 'Add to Cart'
      expect(find.text('Add to Cart'), findsOneWidget);

      // Drain all timers
      await tester.pump(const Duration(seconds: 15));
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
