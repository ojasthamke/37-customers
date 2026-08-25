import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to entries of `orders.items` — `{ productId, name, price, quantity, unit, imageUrl }`.
class OrderItem {
  final String productId;
  final String name;
  final num price;
  final int quantity;
  final String unit;
  final String imageUrl;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.unit = '',
    this.imageUrl = '',
  });

  num get lineTotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: (map['productId'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      price: (map['price'] ?? 0) as num,
      quantity: (map['quantity'] ?? 0) as int,
      unit: (map['unit'] ?? '') as String,
      imageUrl: (map['imageUrl'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'unit': unit,
        'imageUrl': imageUrl,
      };
}

/// Maps to `orders/{autoId}` — see docs/architecture.md section 1.
class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String addressLine;
  final String city;
  final String pincode;
  final List<OrderItem> items;
  final num totalAmount;
  final String status;
  final DateTime? createdAt;

  const OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.addressLine,
    required this.city,
    required this.pincode,
    required this.items,
    required this.totalAmount,
    required this.status,
    this.createdAt,
  });

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawItems = (data['items'] as List<dynamic>? ?? []);
    final created = data['createdAt'];
    return OrderModel(
      id: doc.id,
      customerId: (data['customerId'] ?? '') as String,
      customerName: (data['customerName'] ?? '') as String,
      customerPhone: (data['customerPhone'] ?? '') as String,
      addressLine: (data['addressLine'] ?? '') as String,
      city: (data['city'] ?? '') as String,
      pincode: (data['pincode'] ?? '') as String,
      items: rawItems
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      totalAmount: (data['totalAmount'] ?? 0) as num,
      status: (data['status'] ?? 'placed') as String,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}
