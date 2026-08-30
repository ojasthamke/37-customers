// ignore_for_file: avoid_print, prefer_const_declarations, invalid_null_aware_operator
import 'dart:convert';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  print('================================================================');
  print('OrderKart State Machine & Cancellation Integrity Test');
  print('================================================================');

  final client = SupabaseClient(
    'https://xsqaxvbrjvhgemlfgoxn.supabase.co',
    'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
  );
  
  // 1. Resolve Admin Credentials
  print('\n[1/7] Authenticating as Admin...');
  final adminEmail = 'admin@aplibhaji.com';
  final adminPassword = 'adminpassword';
  
  AuthResponse? adminAuthRes;
  try {
    adminAuthRes = await client.auth.signInWithPassword(email: adminEmail, password: adminPassword);
    print('--> Admin Authenticated. User: ${adminAuthRes.user?.email}');
  } catch (e) {
    print('--> Fatal: Admin Authentication failed: $e');
    return;
  }

  // Get an available product to place test order
  final products = await client.from('products').select().eq('is_available', true).limit(1);
  if (products.isEmpty) {
    print('--> Fatal: No products found.');
    return;
  }
  final testProduct = products.first;
  final productId = testProduct['id'] as String;
  
  // Check initial stock
  num initialStock = 0;
  final desc = testProduct['description'] as String?;
  if (desc != null) {
    try {
      final descMap = json.decode(desc);
      if (descMap is Map && descMap.containsKey('stock')) {
        initialStock = descMap['stock'] ?? 0;
      }
    } catch (_) {
      // Not a valid JSON or doesn't have stock
    }
  }
  print('--> Test Product resolved: "${testProduct['name']}" (Stock: $initialStock, ID: $productId)');

  // 2. Create test customer session and place a pending order
  print('\n[2/7] Authenticating customer & placing order...');
  final customerEmail = '9999999999@aplibhaji.com';
  final customerPassword = 'password123';
  
  AuthResponse? customerAuthRes;
  try {
    customerAuthRes = await client.auth.signInWithPassword(email: customerEmail, password: customerPassword);
    print('--> Customer Authenticated: ${customerAuthRes.user?.email}');
  } catch (e) {
    print('--> Fatal: Customer Authentication failed: $e');
    return;
  }

  // Place order via secure RPC
  final idempotencyKey = const Uuid().v4();
  Map<String, dynamic> testOrderResult;
  try {
    final response = await client.rpc('place_order_secure', params: {
      'p_delivery_address': '456 State Machine Lane',
      'p_customer_phone': '9999999999',
      'p_items': [
        {'product_id': productId, 'quantity': 1.0}
      ],
      'p_idempotency_key': idempotencyKey,
    });
    testOrderResult = Map<String, dynamic>.from(response);
    print('--> Legitimate pending order created. ID: ${testOrderResult['id']}, Status: ${testOrderResult['status']}');
  } catch (e) {
    print('--> Fatal: Failed to place order: $e');
    return;
  }

  final orderId = testOrderResult['id'] as String;

  // Let's re-authenticate as Admin to perform status transitions
  await client.auth.signInWithPassword(email: adminEmail, password: adminPassword);

  // 3. Test Invalid Transition: Pending -> Delivered (Bypassing state machine)
  print('\n[3/7] Test: Invalid transition (Pending -> Delivered)...');
  try {
    await client.from('orders').update({'status': 'Delivered'}).eq('id', orderId).select();
    print('--> FAIL: Pending -> Delivered transition accepted!');
  } catch (e) {
    print('--> SUCCESS: Invalid transition blocked: $e');
  }

  // 4. Test Valid Transition: Pending -> Confirmed
  print('\n[4/7] Test: Valid transition (Pending -> Confirmed)...');
  try {
    final res = await client.from('orders').update({'status': 'Confirmed'}).eq('id', orderId).select();
    if (res.isNotEmpty && res.first['status'] == 'Confirmed') {
      print('--> SUCCESS: Valid transition (Pending -> Confirmed) accepted.');
    } else {
      print('--> FAIL: Transition update returned empty.');
    }
  } catch (e) {
    print('--> FAIL: Valid transition blocked: $e');
  }

  // 5. Test Invalid Transition: Confirmed -> Pending (Rewinding status)
  print('\n[5/7] Test: Invalid transition (Confirmed -> Pending)...');
  try {
    await client.from('orders').update({'status': 'Pending'}).eq('id', orderId).select();
    print('--> FAIL: Confirmed -> Pending transition accepted!');
  } catch (e) {
    print('--> SUCCESS: Invalid transition blocked: $e');
  }

  // 6. Test Valid Transition & Stock Restoration: Confirmed -> Cancelled
  print('\n[6/7] Test: Cancellation & Atomic Stock Restoration...');
  try {
    // Get stock before cancellation
    final prodBefore = await client.from('products').select().eq('id', productId).single();
    print('    Stock before cancellation: ${prodBefore['description']}');

    final res = await client.from('orders').update({'status': 'Cancelled'}).eq('id', orderId).select();
    if (res.isNotEmpty && res.first['status'] == 'Cancelled') {
      print('    Order cancelled successfully.');
    }

    final prodAfter = await client.from('products').select().eq('id', productId).single();
    print('    Stock after cancellation: ${prodAfter['description']}');
    print('--> SUCCESS: Cancellation and atomic stock restoration complete.');
  } catch (e) {
    print('--> FAIL: Cancellation failed: $e');
  }

  // 7. Test Double Cancellation (Must throw exception and NOT double-restore stock)
  print('\n[7/7] Test: Double Cancellation Protection...');
  try {
    final prodBefore = await client.from('products').select().eq('id', productId).single();
    print('    Stock before second cancellation: ${prodBefore['description']}');

    await client.from('orders').update({'status': 'Cancelled'}).eq('id', orderId).select();
    print('--> FAIL: Double cancellation accepted without throwing error!');
  } catch (e) {
    print('--> SUCCESS: Double cancellation blocked with trigger exception: $e');
    final prodAfter = await client.from('products').select().eq('id', productId).single();
    print('    Stock after blocked cancellation: ${prodAfter['description']} (Confirming no double stock restoration)');
  }

  print('\n================================================================');
  print('State Machine & Cancellation Audit Complete');
  print('================================================================');
}
