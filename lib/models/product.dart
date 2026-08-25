import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to `products/{autoId}` — see docs/architecture.md section 1.
class Product {
  final String id;
  final String name;
  final String description;
  final String categoryId;
  final String categoryName;
  final num price;
  final String unit;
  final String imageUrl;
  final num stock;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    this.categoryId = '',
    this.categoryName = '',
    this.price = 0,
    this.unit = 'kg',
    this.imageUrl = '',
    this.stock = 0,
    this.isActive = true,
  });

  bool get isOutOfStock => stock <= 0;

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Product(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      categoryId: (data['categoryId'] ?? '') as String,
      categoryName: (data['categoryName'] ?? '') as String,
      price: (data['price'] ?? 0) as num,
      unit: (data['unit'] ?? 'kg') as String,
      imageUrl: (data['imageUrl'] ?? '') as String,
      stock: (data['stock'] ?? 0) as num,
      isActive: (data['isActive'] ?? true) as bool,
    );
  }
}
