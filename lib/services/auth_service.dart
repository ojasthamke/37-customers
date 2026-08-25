import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

/// Firebase Auth + users/{uid} profile. See docs/architecture.md section 1.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Login with email/password. Throws [FirebaseAuthException] on failure.
  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Register and create users/{uid} doc per the shared schema
  /// (role is always 'customer'; admin is granted manually in the console).
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'customer',
      'addressLine': '',
      'city': '',
      'pincode': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() => _auth.signOut();

  /// Stream of the current user's profile doc.
  Stream<AppUser?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map(
        (doc) => doc.exists ? AppUser.fromDoc(doc) : null);
  }

  Future<AppUser?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? AppUser.fromDoc(doc) : null;
  }

  /// Editable profile fields per docs/architecture.md section 3.
  Future<void> updateProfile(
    String uid, {
    required String name,
    required String phone,
    required String addressLine,
    required String city,
    required String pincode,
  }) {
    return _db.collection('users').doc(uid).update({
      'name': name,
      'phone': phone,
      'addressLine': addressLine,
      'city': city,
      'pincode': pincode,
    });
  }
}
