import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

/// Reads `categories` — only active ones, sorted by sortOrder.
class CategoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Category>> fetchActiveCategories() async {
    final snap = await _db
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .get();
    final categories =
        snap.docs.map((doc) => Category.fromDoc(doc)).toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }
}
