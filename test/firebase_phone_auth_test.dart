import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/core/services/phone_auth_service.dart';
import 'package:aplibhaji_customers/features/auth/auth_provider.dart';
import 'package:aplibhaji_customers/features/auth/phone_login_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Firebase Phone Number Authentication Unit Tests', () {
    test('1. Phone Number Normalization: 10-digit Indian numbers convert to E.164 (+91)', () {
      expect(PhoneAuthService.formatE164('9876543210'), equals('+919876543210'));
      expect(PhoneAuthService.formatE164('98765 43210'), equals('+919876543210'));
      expect(PhoneAuthService.formatE164('+919876543210'), equals('+919876543210'));
      expect(PhoneAuthService.formatE164('919876543210'), equals('+919876543210'));
      expect(PhoneAuthService.formatE164('+14155552671'), equals('+14155552671'));
    });

    test('2. Profile Completion Checker: detects completed vs incomplete profile', () {
      final container = ProviderContainer();
      final notifier = container.read(authProvider.notifier);

      // Incomplete customer profile
      expect(notifier.isProfileComplete(null), isFalse);
      expect(notifier.isProfileComplete({'name': 'Valued Customer', 'phone': '9876543210'}), isFalse);
      expect(notifier.isProfileComplete({'name': 'Ojas Thamke', 'phone': '9876543210'}), isFalse);

      // Complete customer profile
      expect(
        notifier.isProfileComplete({
          'name': 'Ojas Thamke',
          'phone': '9876543210',
          'customer_code': 'OK1025',
          'password': 'secret_password_123',
        }),
        isTrue,
      );
    });
  });

  group('PhoneLoginSheet Widget Tests', () {
    testWidgets('3. PhoneLoginSheet renders phone number field and Get OTP button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PhoneLoginSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifies Step 1 UI
      expect(find.text('Mobile Number Login'), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('GET OTP CODE'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('4. PhoneLoginSheet validates invalid 10-digit mobile number on press', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PhoneLoginSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter short number
      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('GET OTP CODE'));
      await tester.pumpAndSettle();

      // Expect validation error
      expect(find.text('Please enter a valid 10-digit number'), findsOneWidget);
    });
  });
}
