import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/theme/app_theme.dart';
import 'package:uniro1/widgets/weekly_bar_chart.dart';

void main() {
  testWidgets('WeeklyBarChart renders correct labels and handles class and task loads', (tester) async {
    // 2026-10-31 is Saturday
    const weekStart = '2026-10-31';
    final taskLoad = <String, int>{
      '2026-10-31': 0,
      '2026-11-01': 1,
      '2026-11-02': 2,
    };
    final classLoad = <String, int>{
      '2026-10-31': 2, // 2 classes on Saturday
      '2026-11-01': 1, // 1 class on Sunday
      '2026-11-02': 0, // 0 classes on Monday
    };

    String? pressedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppColors.light, Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: WeeklyBarChart(
                weekStart: weekStart,
                load: taskLoad,
                classLoad: classLoad,
                onDayPress: (d) => pressedDay = d,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 7 day labels starting from Saturday: Sa, Su, Mo, Tu, We, Th, Fr
    expect(find.text('Sa'), findsOneWidget);
    expect(find.text('Su'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text('Tu'), findsOneWidget);
    expect(find.text('We'), findsOneWidget);
    expect(find.text('Th'), findsOneWidget);
    expect(find.text('Fr'), findsOneWidget);

    // Verify day numbers
    expect(find.text('31'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap Saturday (Oct 31) which has 2 classes, 0 tasks
    await tester.tap(find.text('Sa'));
    await tester.pumpAndSettle();

    expect(pressedDay, '2026-10-31');
    expect(find.text('2 classes'), findsOneWidget);

    // Tap Sunday (Nov 1) which has 1 class, 1 task
    await tester.tap(find.text('Su'));
    await tester.pumpAndSettle();

    expect(pressedDay, '2026-11-01');
    expect(find.text('1 class, 1 task'), findsOneWidget);

    // Tap Monday (Nov 2) which has 0 classes, 2 tasks
    await tester.tap(find.text('Mo'));
    await tester.pumpAndSettle();

    expect(pressedDay, '2026-11-02');
    expect(find.text('2 tasks'), findsOneWidget);
  });
}
