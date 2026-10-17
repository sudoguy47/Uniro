import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/widgets/support_dialog.dart';

/// "Need a hand?" dialog: compact, dismissible, with icon buttons for
/// the configured Telegram and GitHub links.
void main() {
  Future<void> pumpOpener(WidgetTester tester, Size size) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => showSupportDialog(ctx),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows title, message, icon links, and Close',
      (tester) async {
    await pumpOpener(tester, const Size(412, 915));

    expect(find.text('Need a hand?'), findsOneWidget);
    expect(find.textContaining('Diagnostics copied'), findsOneWidget);
    expect(find.textContaining('review before sharing'), findsOneWidget);
    expect(find.text('Telegram Support'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.text('GitHub Profile'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // No launcher plugin in tests: tapping a link fails gracefully
    // with a SnackBar and keeps the dialog open. The launch guard has
    // a 3s timeout, so move the fake clock past it first.
    await tester.tap(find.text('Telegram Support'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open the link."), findsOneWidget);
    expect(find.text('Need a hand?'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Need a hand?'), findsNothing);
  });

  testWidgets('fits 320dp narrow phones', (tester) async {
    await pumpOpener(tester, const Size(320, 640));
    expect(find.text('Need a hand?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
