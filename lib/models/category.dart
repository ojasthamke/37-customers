import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to `categories/{autoId}` — see docs/architecture.md section 1.
class Category {
  final String id;
  final String name;
  final String imageUrl;
  final bool isActive;
  final int sortOrder;

  const Category({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory Category.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return Category(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      imageUrl: (data['imageUrl'] ?? '') as String,
      isActive: (data['isActive'] ?? true) as bool,
      sortOrder: (data['sortOrder'] ?? 0) as int,
    );
  }
}
