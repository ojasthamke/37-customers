// ignore_for_file: avoid_print, prefer_const_declarations, invalid_null_aware_operator, unnecessary_null_comparison
import 'dart:async';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  print('================================================================');
  print('OrderKart Proof-Based Adversarial Security Verification');
  print('================================================================');

  print('Initializing Supabase client...');
  final client = SupabaseClient(
    'https://xsqaxvbrjvhgemlfgoxn.supabase.co',
    'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
  );
  print('Supabase client initialized.');

  // 1. Authenticate as a test customer
  print('\n[1/10] Authenticating test customer...');
  final phone = '9999999999';
  final password = 'password123';
  final email = '$phone@aplibhaji.com';
  
  AuthResponse? authRes;
  try {
    final res = await client.auth.signInWithPassword(email: email, password: password);
    authRes = res;
    print('--> Authenticated. Customer UID: ${res.user?.id}');
  } catch (e) {
    print('Sign in failed, attempting registration...');
    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        data: {'name': 'Test Customer', 'phone': phone, 'address': '123 Verification Lane'},
      );
      authRes = res;
      print('--> Registered & Authenticated. Customer UID: ${res.user?.id}');
    } catch (signUpErr) {
      print('--> Fatal: Sign up failed: $signUpErr');
      return;
    }
  }

  if (authRes == null || client.auth.currentUser == null) {
    print('--> Fatal: Authentication failed (AuthResponse or User is null).');
    return;
  }

  // Brief sleep to ensure profile sync triggers complete
  await Future.delayed(const Duration(milliseconds: 500));

  // Verify/create customer profile
  try {
    final customer = await client.from('customers').select().eq('id', client.auth.currentUser!.id);
    if (customer.isEmpty) {
      print('Customer profile missing, creating...');
      await client.from('customers').insert({
        'id': client.auth.currentUser!.id,
        'name': 'Test Customer',
        'phone': phone,
        'email': email,
        'address': '123 Verification Lane'
      });
      print('--> Customer profile created.');
    } else {
      print('--> Customer profile verified.');
    }
  } catch (e) {
    print('--> Customer profile check failed: $e');
  }

  // Get a product for tests
  print('\n[2/10] Fetching active product from catalog...');
  Map<String, dynamic>? testProduct;
  try {
    final products = await client.from('products').select().eq('is_available', true).limit(1);
    if (products.isEmpty) {
      print('--> Fatal: No products found in the database catalog.');
      return;
    }
    testProduct = products.first;
    print('--> Test Product resolved: "${testProduct?['name']}" (Price: ₹${testProduct?['price']}, ID: ${testProduct?['id']})');
  } catch (e) {
    print('--> Fatal: Failed to fetch products: $e');
    return;
  }

  final productId = testProduct['id'] as String;

  // TEST A: Direct insert into orders table (Bypassing RPC)
  print('\n[3/10] Attack A: Direct INSERT into orders table (Bypassing RPC)...');
  final fakeOrderId = const Uuid().v4();
  try {
    await client.from('orders').insert({
      'id': fakeOrderId,
      'order_number': 'AB-MALICIOUS-001',
      'customer_id': client.auth.currentUser!.id,
      'customer_phone': phone,
      'delivery_address': '123 Hackers St',
      'status': 'Pending',
      'total_amount': 1.00, // Attempting fake total
    }).select();
    print('--> FAIL: Malicious direct insert into orders succeeded!');
  } catch (e) {
    print('--> SUCCESS: Direct insert into orders blocked by RLS policies: $e');
  }

  // TEST B: Direct insert into order_items table (Bypassing RPC)
  print('\n[4/10] Attack B: Direct INSERT into order_items table (Bypassing RPC)...');
  try {
    await client.from('order_items').insert({
      'order_id': fakeOrderId,
      'product_id': productId,
      'product_name': testProduct['name'],
      'price': 1.00, // Fake price
      'quantity': 10,
      'unit': testProduct['unit'],
      'total_price': 10.00, // Fake total
    }).select();
    print('--> FAIL: Malicious direct insert into order_items succeeded!');
  } catch (e) {
    print('--> SUCCESS: Direct insert into order_items blocked by RLS policies: $e');
  }

  // TEST C: Invoke secure RPC with negative quantity
  print('\n[5/10] Attack C: Invoke place_order_secure with negative quantity...');
  try {
    await client.rpc('place_order_secure', params: {
      'p_delivery_address': '123 Hackers St',
      'p_customer_phone': phone,
      'p_items': [
        {'product_id': productId, 'quantity': -5}
      ]
    });
    print('--> FAIL: place_order_secure accepted negative quantity!');
  } catch (e) {
    print('--> SUCCESS: Negative quantity rejected by PL/pgSQL validation: $e');
  }

  // TEST D: Invoke secure RPC with zero quantity
  print('\n[6/10] Attack D: Invoke place_order_secure with zero quantity...');
  try {
    await client.rpc('place_order_secure', params: {
      'p_delivery_address': '123 Hackers St',
      'p_customer_phone': phone,
      'p_items': [
        {'product_id': productId, 'quantity': 0}
      ]
    });
    print('--> FAIL: place_order_secure accepted zero quantity!');
  } catch (e) {
    print('--> SUCCESS: Zero quantity rejected by PL/pgSQL validation: $e');
  }

  // TEST E: Direct inventory price manipulation on products
  print('\n[7/10] Attack E: Direct products table price manipulation (IDOR / RLS Bypass)...');
  try {
    final List<dynamic> res = await client.from('products').update({'price': 1.00}).eq('id', productId).select();
    if (res.isEmpty) {
      print('--> SUCCESS: Customer update on products blocked (0 rows modified).');
    } else {
      print('--> FAIL: Product price updated directly by customer! (Modified rows: $res)');
    }
  } catch (e) {
    print('--> SUCCESS: Customer update on products blocked with exception: $e');
  }

  // TEST F: Legitimate order creation via secure RPC (Calculates totals server-side)
  print('\n[8/10] Test F: Legitimate order placement via place_order_secure RPC...');
  final idempotencyKey = const Uuid().v4();
  Map<String, dynamic>? firstOrderResult;
  try {
    final response = await client.rpc('place_order_secure', params: {
      'p_delivery_address': '123 Verification Lane',
      'p_customer_phone': phone,
      'p_items': [
        {'product_id': productId, 'quantity': 2.0}
      ],
      'p_idempotency_key': idempotencyKey,
    });
    firstOrderResult = Map<String, dynamic>.from(response);
    print('--> SUCCESS: Legitimate order created:');
    print('    Order ID: ${firstOrderResult['id']}');
    print('    Order Number: ${firstOrderResult['order_number']}');
    print('    Server-Calculated Total: ₹${firstOrderResult['total_amount']}');
  } catch (e) {
    print('--> FAIL: place_order_secure failed to place legitimate order: $e');
    return;
  }

  // TEST G: Replay attack / Idempotency check with the SAME key
  print('\n[9/10] Test G: Replay check (resubmitting SAME request and idempotency key)...');
  try {
    final response = await client.rpc('place_order_secure', params: {
      'p_delivery_address': '123 Verification Lane',
      'p_customer_phone': phone,
      'p_items': [
        {'product_id': productId, 'quantity': 2.0}
      ],
      'p_idempotency_key': idempotencyKey,
    });
    final secondOrderResult = Map<String, dynamic>.from(response);
    if (secondOrderResult['id'] == firstOrderResult['id']) {
      print('--> SUCCESS: Replay intercepted! Returned existing order ${secondOrderResult['id']} without inserting duplicate.');
    } else {
      print('--> FAIL: Duplicate order was created with ID ${secondOrderResult['id']}');
    }
  } catch (e) {
    print('--> FAIL: Replay check threw unexpected exception: $e');
  }

  // TEST H: Create a new distinct order with a DIFFERENT idempotency key
  print('\n[10/10] Test H: Creating a separate order with a new idempotency key...');
  try {
    final newKey = const Uuid().v4();
    final response = await client.rpc('place_order_secure', params: {
      'p_delivery_address': '123 Verification Lane',
      'p_customer_phone': phone,
      'p_items': [
        {'product_id': productId, 'quantity': 1.0}
      ],
      'p_idempotency_key': newKey,
    });
    final thirdOrderResult = Map<String, dynamic>.from(response);
    if (thirdOrderResult['id'] != firstOrderResult['id']) {
      print('--> SUCCESS: New distinct order placed successfully. ID: ${thirdOrderResult['id']}');
    } else {
      print('--> FAIL: Failed to generate a new order.');
    }
  } catch (e) {
    print('--> FAIL: Failed to place subsequent order: $e');
  }

  print('\n================================================================');
  print('Adversarial Verification Suite Execution Complete');
  print('================================================================');
}
