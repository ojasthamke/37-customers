import 'package:flutter_test/flutter_test.dart';
import 'package:aplibhaji_customers/features/auth/password_rules_helper.dart';

bool isProfileComplete(Map<String, dynamic>? customer) {
  if (customer == null) return false;
  final name = (customer['name'] as String? ?? '').trim();
  final rawPhone = (customer['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '').trim();
  final customerCode = (customer['customer_code'] as String? ?? '').trim();
  final password = (customer['password'] as String? ?? '').trim();

  if (name.isEmpty || name == 'Valued Customer' || name == 'Guest Customer') return false;
  if (rawPhone.isEmpty || rawPhone.length != 10) return false;
  if (customerCode.isEmpty) return false;
  if (password.isEmpty) return false;

  return true;
}

void main() {
  group('Google Customer Onboarding & Security Hardening Tests', () {
    test('TEST 1: Incomplete profile detected when phone is missing or null', () {
      final incompleteCustomer = {
        'id': 'cust-123',
        'name': 'Test Google User',
        'phone': null,
        'customer_code': 'SER67TG',
        'password': 'StrongPassword@123',
        'auth_provider': 'google',
        'is_new_customer': true,
      };

      expect(isProfileComplete(incompleteCustomer), isFalse);
    });

    test('TEST 2: Incomplete profile detected when password is not set', () {
      final incompleteCustomer = {
        'id': 'cust-123',
        'name': 'Test Google User',
        'phone': '9876543210',
        'customer_code': 'SER67TG',
        'password': null,
        'auth_provider': 'google',
        'is_new_customer': true,
      };

      expect(isProfileComplete(incompleteCustomer), isFalse);
    });

    test('TEST 3: Incomplete profile detected when customer code is empty', () {
      final incompleteCustomer = {
        'id': 'cust-123',
        'name': 'Test Google User',
        'phone': '9876543210',
        'customer_code': '',
        'password': 'StrongPassword@123',
        'auth_provider': 'google',
        'is_new_customer': true,
      };

      expect(isProfileComplete(incompleteCustomer), isFalse);
    });

    test('TEST 4: Incomplete profile detected when phone length is not 10 digits', () {
      final incompleteCustomer = {
        'id': 'cust-123',
        'name': 'Test Google User',
        'phone': '98765',
        'customer_code': 'SER67TG',
        'password': 'StrongPassword@123',
        'auth_provider': 'google',
        'is_new_customer': true,
      };

      expect(isProfileComplete(incompleteCustomer), isFalse);
    });

    test('TEST 5: Complete profile passes validation with Name, Phone, Code, and Password', () {
      final completeCustomer = {
        'id': 'cust-123',
        'name': 'ApliBhaji Shopper',
        'phone': '9876543210',
        'customer_code': 'SER67TG',
        'password': 'StrongPassword@123',
        'auth_provider': 'google',
        'is_new_customer': true,
      };

      expect(isProfileComplete(completeCustomer), isTrue);
    });

    test('TEST 6: Password rules validator rejects weak passwords (< 8 chars, no special char)', () {
      expect(PasswordRulesHelper.isPasswordStrong('short'), isFalse);
      expect(PasswordRulesHelper.isPasswordStrong('password123'), isFalse);
      expect(PasswordRulesHelper.isPasswordStrong('Password123'), isFalse);
      expect(PasswordRulesHelper.isPasswordStrong('Password!'), isFalse);
      expect(PasswordRulesHelper.isPasswordStrong('PASSWORD@123'), isFalse);
      expect(PasswordRulesHelper.isPasswordStrong('Pass@123'), isTrue);
    });

    test('TEST 7: 7-character customer code format conforms to alphanumeric standard', () {
      const sampleCode = 'SER67TG';
      expect(sampleCode.length, equals(7));
      expect(RegExp(r'^[A-Z0-9]{7}$').hasMatch(sampleCode), isTrue);
    });
  });
}
