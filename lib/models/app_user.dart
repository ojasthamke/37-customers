import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps to `users/{uid}` — see docs/architecture.md section 1.
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String addressLine;
  final String city;
  final String pincode;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'customer',
    this.addressLine = '',
    this.city = '',
    this.pincode = '',
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      name: (data['name'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      phone: (data['phone'] ?? '') as String,
      role: (data['role'] ?? 'customer') as String,
      addressLine: (data['addressLine'] ?? '') as String,
      city: (data['city'] ?? '') as String,
      pincode: (data['pincode'] ?? '') as String,
    );
  }
}
