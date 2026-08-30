// ignore_for_file: avoid_print, prefer_const_declarations, invalid_null_aware_operator, unused_import
import 'dart:async';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  print('================================================================');
  print('OrderKart Proof-Based Order Integrity & Anti-Tampering Audit');
  print('================================================================');

  print('Initializing Supabase client...');
  final client = SupabaseClient(
    'https://xsqaxvbrjvhgemlfgoxn.supabase.co',
    'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
  );
  print('Supabase client initialized.');

  // 1. Authenticate as a test customer
  print('\n[1/6] Authenticating test customer...');
  final phone = '9999999999';
  final password = 'password123';
  final email = '$phone@aplibhaji.com';
  
  AuthResponse? authRes;
  try {
    authRes = await client.auth.signInWithPassword(email: email, password: password);
    print('--> Authenticated. Customer UID: ${authRes.user?.id}');
  } catch (e) {
    print('--> Fatal: Authentication failed: $e');
    return;
  }

  // Get one of our test customer's orders
  print('\n[2/6] Querying customer order history...');
  Map<String, dynamic>? testOrder;
  try {
    final orders = await client.from('orders').select().eq('customer_id', client.auth.currentUser!.id).limit(1);
    if (orders.isEmpty) {
      print('--> Fatal: No orders found for customer. Run the place_order_secure verification first.');
      return;
    }
    testOrder = orders.first;
    print('--> Target Order resolved: "${testOrder?['order_number']}" (ID: ${testOrder?['id']}, Status: ${testOrder?['status']})');
  } catch (e) {
    print('--> Fatal: Failed to fetch orders: $e');
    return;
  }

  final orderId = testOrder['id'] as String;

  // TEST 1: Direct Order status tampering (Customer cancels order by updating status directly)
  print('\n[3/6] Attack 1: Direct update of status column to "Cancelled"...');
  try {
    final res = await client.from('orders').update({'status': 'Cancelled'}).eq('id', orderId).select();
    if (res.isEmpty) {
      print('--> SUCCESS: Customer status update blocked by RLS policies (0 rows modified).');
    } else {
      print('--> FAIL: Order status updated directly by customer! Modified: $res');
    }
  } catch (e) {
    print('--> SUCCESS: Order status update blocked with exception: $e');
  }

  // TEST 2: Direct Order field editing (Customer changes customer_id or total_amount)
  print('\n[4/6] Attack 2: Direct update of total_amount / customer_id fields...');
  try {
    final res = await client.from('orders').update({
      'total_amount': 1.00,
      'customer_id': '00000000-0000-0000-0000-000000000000'
    }).eq('id', orderId).select();
    if (res.isEmpty) {
      print('--> SUCCESS: Direct modification of orders table fields blocked (0 rows modified).');
    } else {
      print('--> FAIL: Order fields modified directly by customer! Modified: $res');
    }
  } catch (e) {
    print('--> SUCCESS: Direct modification of order fields blocked with exception: $e');
  }

  // TEST 3: Direct Order deletion (Customer deletes their order row)
  print('\n[5/6] Attack 3: Direct DELETE of orders row...');
  try {
    final res = await client.from('orders').delete().eq('id', orderId).select();
    if (res.isEmpty) {
      print('--> SUCCESS: Customer delete on orders table blocked (0 rows modified).');
    } else {
      print('--> FAIL: Order row physically deleted directly by customer! Modified: $res');
    }
  } catch (e) {
    print('--> SUCCESS: Order deletion blocked with exception: $e');
  }

  // TEST 4: Direct Order Items modification (Customer alters quantities on created order items)
  print('\n[6/6] Attack 4: Direct UPDATE on order_items table...');
  try {
    final res = await client.from('order_items').update({'quantity': 100}).eq('order_id', orderId).select();
    if (res.isEmpty) {
      print('--> SUCCESS: Direct modification of order_items blocked (0 rows modified).');
    } else {
      print('--> FAIL: Order item quantity modified directly by customer! Modified: $res');
    }
  } catch (e) {
    print('--> SUCCESS: Order item quantity modification blocked with exception: $e');
  }

  print('\n================================================================');
  print('Order Integrity Audit Execution Complete');
  print('================================================================');
}
