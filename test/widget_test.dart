// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spam_guard/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build the app and verify onboarding title is present.
    await tester.pumpWidget(const MyApp(initialRoute: '/onboarding'));

    // Allow the onboarding delayed animation/timer to complete in tests.
    await tester.pump(const Duration(milliseconds: 600));

    // Verify that the onboarding screen title is shown.
    expect(find.text('SpamGuard'), findsWidgets);
  });
}
