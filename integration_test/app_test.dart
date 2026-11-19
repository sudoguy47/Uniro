import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:uniro1/app/app.dart';
import 'package:uniro1/app/app_shell.dart';
import 'package:uniro1/main.dart' as app;
import 'package:uniro1/screens/onboarding_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('verify initial screen renders correctly', (tester) async {
    // Launch the real application through its main entry point.
    app.main();

    // Allow asynchronous bootstrap (local storage, state hydration)
    // to complete and mount the root widget.
    // Note: Mascot animations on the onboarding screen repeat indefinitely,
    // so we pump with bounded increments rather than unbounded pumpAndSettle.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(CampusTrackerApp).evaluate().isNotEmpty) {
        break;
      }
    }

    // Pump an additional frame to complete initial rendering and layout passes.
    await tester.pump(const Duration(milliseconds: 500));

    // Verify root application widget is mounted.
    expect(find.byType(CampusTrackerApp), findsOneWidget);

    // Verify that the appropriate initial screen is rendered:
    // OnboardingScreen if onboarding has not been completed,
    // or AppShell if the user has already onboarded.
    final initialScreenFinder = find.byWidgetPredicate(
      (widget) => widget is OnboardingScreen || widget is AppShell,
    );
    expect(initialScreenFinder, findsOneWidget);
  });
}
