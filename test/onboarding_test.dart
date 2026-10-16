import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/screens/onboarding_screen.dart';

/// Onboarding setup-page behavior. Uses fixed pumps (mascots animate
/// forever, so pumpAndSettle would hang).
Future<void> _nextPage(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('OnboardingScreen setup', () {
    testWidgets('has no Skip button', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('keyboard is dismissed when leaving the name page',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await _nextPage(tester); // 0 -> 1
      await _nextPage(tester); // 1 -> 2 (name)
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.enterText(find.byType(TextField), 'Sreyas');
      await tester.pump(const Duration(milliseconds: 200));
      await _nextPage(tester); // 2 -> 3 (reminders)
      // Keyboard dismissed: the test keyboard is hidden and the
      // reminders slide is showing.
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Enable Reminders'), findsOneWidget);
    });

    testWidgets('Next and Enable Reminders taps do not throw',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await _nextPage(tester);
      await _nextPage(tester);
      await tester.enterText(find.byType(TextField), 'Sreyas');
      await tester.pump(const Duration(milliseconds: 200));
      await _nextPage(tester); // reminders page
      await tester.tap(find.text('Enable Reminders'));
      await tester.pump(const Duration(milliseconds: 300));
      // Permission request fails without a plugin but must not throw.
      expect(find.text('Enable Reminders'), findsOneWidget);
    });

    testWidgets('empty name blocks advance with a hint', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      await _nextPage(tester); // 0 -> 1
      await _nextPage(tester); // 1 -> 2 (name)
      expect(find.byType(TextField), findsOneWidget);
      // Empty name: Next goes nowhere and explains why.
      await tester.tap(find.text('Next'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Please enter your name to continue.'), findsOneWidget);
      // Let the hint dismiss, then a name lets the user through.
      await tester.pump(const Duration(seconds: 3));
      await tester.enterText(find.byType(TextField), 'Sreyas');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Sreyas'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await _nextPage(tester); // 2 -> 3 with a name
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Enable Reminders'), findsOneWidget);
    });
  });
}
