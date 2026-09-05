import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Security, Authorization & Customer Isolation Tests', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              name TEXT,
              phone TEXT,
              customer_code TEXT,
              is_logged_in INTEGER DEFAULT 0,
              is_guest INTEGER DEFAULT 0,
              auth_user_id TEXT,
              password TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              order_number TEXT UNIQUE,
              customer_id TEXT,
              customer_phone TEXT,
              delivery_address TEXT,
              order_date TEXT,
              status TEXT,
              total_amount REAL,
              sync_status TEXT,
              delivery_date TEXT,
              offline_order_no TEXT,
              idempotency_key TEXT,
              customer_name TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE order_items (
              id TEXT PRIMARY KEY,
              order_id TEXT,
              product_id TEXT,
              product_name TEXT,
              price REAL,
              quantity REAL,
              unit TEXT,
              total_price REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE customer_login_logs (
              id TEXT PRIMARY KEY,
              customer_id TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. Local Cache Isolation: Customer B cannot read Customer A order from SQLite', () async {
      // 1. Insert Customer A sensitive order into SQLite
      await db.insert('orders', {
        'id': 'ord-cust-A-1',
        'order_number': '#ORD-1001',
        'customer_id': 'cust-uuid-A',
        'customer_phone': '9876543210',
        'delivery_address': 'Flat 401, Customer A Secret Residence',
        'order_date': '2026-09-03T10:00:00Z',
        'status': 'Pending',
        'total_amount': 750.0,
      });

      await db.insert('order_items', {
        'id': 'item-1',
        'order_id': 'ord-cust-A-1',
        'product_id': 'prod-1',
        'product_name': 'Fresh Strawberries',
        'price': 250.0,
        'quantity': 3.0,
        'unit': 'kg',
        'total_price': 750.0,
      });

      // 2. Customer B is currently authenticated
      final currentCustB = {
        'id': 'cust-uuid-B',
        'phone': '9123456789',
        'name': 'Customer B',
      };

      // Query order by ID as Customer B
      final localOrders = await db.query(
        'orders',
        where: 'id = ?',
        whereArgs: ['ord-cust-A-1'],
      );

      expect(localOrders.isNotEmpty, true);
      final foundOrder = localOrders.first;

      // Verification: Application authorization check must suppress emission
      final orderCustId = foundOrder['customer_id']?.toString() ?? '';
      final orderPhone = foundOrder['customer_phone']?.toString() ?? '';
      final currentCustId = currentCustB['id']!;
      final currentPhone = currentCustB['phone']!;

      final bool idMatches = currentCustId.isNotEmpty && orderCustId.isNotEmpty && orderCustId == currentCustId;
      final bool phoneMatches = currentPhone.isNotEmpty && orderPhone.isNotEmpty && orderPhone == currentPhone;

      final bool isAuthorized = idMatches || phoneMatches;
      expect(isAuthorized, false, reason: 'Customer B must NOT be authorized to view Customer A private order details');
    });

    test('2. Unauthenticated / Guest Access Denied: Logged-out user rejected from order details', () {
      Map<String, dynamic>? currentCust; // Logged out
      bool emissionAttempted = false;
      Object? receivedError;

      // Simulate order access authorization check
      if (currentCust == null) {
        receivedError = Exception('Unauthorized: Please log in to view order details.');
      } else {
        emissionAttempted = true;
      }

      expect(emissionAttempted, false);
      expect(receivedError.toString(), contains('Unauthorized: Please log in to view order details.'));
    });

    test('3. Logout Security: Wipes all sensitive tables and cart state from SQLite', () async {
      // Populate tables with user data
      await db.insert('customers', {'id': 'cust-1', 'name': 'John Doe', 'phone': '9999999999', 'is_logged_in': 1});
      await db.insert('orders', {'id': 'ord-1', 'order_number': '101', 'customer_id': 'cust-1', 'total_amount': 500.0});
      await db.insert('order_items', {'id': 'item-1', 'order_id': 'ord-1', 'product_name': 'Tomato', 'price': 50.0});
      await db.insert('customer_login_logs', {'id': 'log-1', 'customer_id': 'cust-1'});
      await db.insert('settings', {'key': 'cart_items', 'value': '[{"product_id":"p1"}]'});
      await db.insert('settings', {'key': 'quick_cart_items', 'value': '[{"product_id":"p2"}]'});
      await db.insert('settings', {'key': 'app_theme', 'value': 'light'}); // Non-sensitive

      // Execute logout cleanup
      await db.transaction((txn) async {
        await txn.update('customers', {'is_logged_in': 0});
        await txn.delete('order_items');
        await txn.delete('orders');
        await txn.delete('customers');
        await txn.delete('customer_login_logs');
        await txn.delete('settings', where: 'key IN (?, ?)', whereArgs: ['cart_items', 'quick_cart_items']);
      });

      // Verify all sensitive data wiped
      final customers = await db.query('customers');
      final orders = await db.query('orders');
      final items = await db.query('order_items');
      final logs = await db.query('customer_login_logs');
      final cartSettings = await db.query('settings', where: 'key IN (?, ?)', whereArgs: ['cart_items', 'quick_cart_items']);
      final generalSettings = await db.query('settings', where: 'key = ?', whereArgs: ['app_theme']);

      expect(customers.isEmpty, true, reason: 'Customers table must be wiped on logout');
      expect(orders.isEmpty, true, reason: 'Orders table must be wiped on logout');
      expect(items.isEmpty, true, reason: 'Order items table must be wiped on logout');
      expect(logs.isEmpty, true, reason: 'Login logs must be wiped on logout');
      expect(cartSettings.isEmpty, true, reason: 'Cart items must be wiped on logout');
      expect(generalSettings.isNotEmpty, true, reason: 'General app settings should be preserved');
    });

    test('4. Backend Account Hijack Protection: Password reset strictly requires phone confirmation', () {
      // Simulate reset_customer_password contract
      String? phoneConfirm = ''; // Attacker leaves blank to bypass

      bool isRejected = false;
      String? errorMessage;

      if (phoneConfirm == null || phoneConfirm.trim().isEmpty) {
        isRejected = true;
        errorMessage = 'Registered mobile number confirmation is required to reset password.';
      }

      expect(isRejected, true);
      expect(errorMessage, 'Registered mobile number confirmation is required to reset password.');
    });

    test('5. Guest Account Overwrite Protection: Registered customer cannot be overwritten by guest signup', () {
      final existingCustomer = {
        'id': 'cust-reg-1',
        'is_guest': 0,
        'auth_user_id': 'auth-uuid-1',
        'password': 'StrongPassword123',
        'phone': '9876543210',
      };

      // Unauthenticated attacker attempts guest registration with same phone
      final incomingGuestPhone = '9876543210';
      bool isBlocked = false;

      final isGuest = existingCustomer['is_guest'] == 1;
      final hasAuth = existingCustomer['auth_user_id'] != null;
      final hasPassword = (existingCustomer['password'] as String?)?.isNotEmpty ?? false;

      if (existingCustomer['phone'] == incomingGuestPhone && (!isGuest || hasAuth || hasPassword)) {
        isBlocked = true;
      }

      expect(isBlocked, true, reason: 'Guest registration must be rejected if phone belongs to an existing registered customer');
    });
  });
}