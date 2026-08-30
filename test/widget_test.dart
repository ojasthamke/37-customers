import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aplibhaji_customers/main.dart';

void main() {
  testWidgets('Splash screen loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: ApliBhajiApp()));

    // Verify that splash screen branding elements are found.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Let the splash screen timer expire and transition
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  });
}
