import 'dart:convert';
import 'package:crypto/crypto.dart';

class SecurityHelper {
  SecurityHelper._();

  static const String _salt = 'orderkart_customer_salt_2026_secure';

  /// Hashes a plaintext password using SHA-256 with a secure constant salt.
  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final salted = '$_salt:${password.trim()}';
    final bytes = utf8.encode(salted);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verifies if a plaintext password matches a stored hash.
  static bool verifyPassword(String password, String storedHash) {
    if (password.isEmpty || storedHash.isEmpty) return false;
    final computedHash = hashPassword(password);
    return computedHash == storedHash;
  }
}
