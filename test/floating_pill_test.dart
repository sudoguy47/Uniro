import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/widgets/notes/floating_note_pill.dart';

/// The New-Note pill must fit narrow phones at large text scales without
/// overflowing (it shrink-fits inside a 240dp cap).
void main() {
  testWidgets('pill fits 320dp at 2.0 text scale', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2.0),
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: FloatingNotePill(
                  onNewNote: () {},
                  onNewChecklist: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('New Note'), findsOneWidget);
    final box =
        tester.getRect(find.byType(FloatingNotePill));
    expect(box.width, lessThanOrEqualTo(320));
  });

  testWidgets('both actions fire', (tester) async {
    var note = 0;
    var list = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingNotePill(
            onNewNote: () => note++,
            onNewChecklist: () => list++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('New Note'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pump();
    expect(note, 1);
    expect(list, 1);
  });
}
