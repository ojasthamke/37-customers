import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../models/order.dart';

/// Creates and reads `orders` per the shared schema
/// (docs/architecture.md section 1). Customer app always creates
/// orders with status 'placed'.
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates the order doc and returns the new order id.
  Future<String> placeOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String addressLine,
    required String city,
    required String pincode,
    required List<OrderItem> items,
    required num totalAmount,
  }) async {
    final ref = await _db.collection('orders').add({
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'addressLine': addressLine,
      'city': city,
      'pincode': pincode,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': OrderStatus.placed,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Current user's orders, newest first.
  Stream<List<OrderModel>> watchMyOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => OrderModel.fromDoc(doc)).toList());
  }
}
