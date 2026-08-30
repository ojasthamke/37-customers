import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/main.dart';

void main() {
  testWidgets('Login Screen input and validation test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const ProviderScope(child: ApliBhajiApp()));
    await tester.pumpAndSettle();

    // Splash screen loads first. We wait 3 seconds for transition
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Tap the Option A button "I have created my password" first to open login form
    final optionButtonFinder = find.text('I have created my password');
    expect(optionButtonFinder, findsOneWidget);
    await tester.tap(optionButtonFinder);
    await tester.pumpAndSettle();

    // 1. Verify customer code text field and button exist
    final codeFieldFinder = find.widgetWithText(TextFormField, 'Customer Code');
    final continueButtonFinder = find.text('SIGN IN');

    expect(codeFieldFinder, findsOneWidget);
    expect(continueButtonFinder, findsOneWidget);

    // 2. Tap Code field and enter text
    await tester.tap(codeFieldFinder);
    await tester.pump();
    await tester.enterText(codeFieldFinder, 'OK1025');
    await tester.pump();
    expect(find.text('OK1025'), findsOneWidget);
  });
}
