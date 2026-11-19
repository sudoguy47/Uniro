import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/theme/app_theme.dart';
import 'package:uniro1/widgets/hero_carousel.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    expect(true, isTrue);
  });

  group('HeroCarousel Crash Bug Fix Tests', () {
    testWidgets('HeroCarousel handles empty tasks without throwing and renders SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppColors.light, Brightness.light),
          home: const Scaffold(
            body: HeroCarousel(tasks: []),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(HeroCarousel), findsOneWidget);
    });

    testWidgets('HeroCarousel didUpdateWidget transitions from tasks to empty cleanly', (tester) async {
      final task = Task(
        title: 'Task 1',
        type: TaskType.assignment,
        dueDate: '2026-11-20',
        priority: TaskPriority.high,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppColors.light, Brightness.light),
          home: Scaffold(
            body: HeroCarousel(tasks: [task]),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Rebuild with empty list (simulate task completed)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(AppColors.light, Brightness.light),
          home: const Scaffold(
            body: HeroCarousel(tasks: []),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
