import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product.dart';

/// Reads `products` — customers only see isActive products
/// (docs/architecture.md section 1: false = hidden from customers).
class ProductService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Product>> fetchActiveProducts() async {
    final snap = await _db
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map((doc) => Product.fromDoc(doc)).toList();
  }
}
