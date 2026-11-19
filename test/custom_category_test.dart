import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/domain/task_utils.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/state/app_state.dart';
import 'package:uniro1/state/routine_state.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/theme/app_theme.dart';
import 'package:uniro1/widgets/new_task_sheet.dart';
import 'package:uniro1/widgets/task_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task Model - customCategory', () {
    test('toJson and fromJson preserve customCategory', () {
      final task = Task(
        title: 'Prepare math notes',
        type: TaskType.custom,
        customCategory: 'Weekly CT',
        dueDate: '2026-11-10',
        priority: TaskPriority.high,
      );

      final json = task.toJson();
      expect(json['customCategory'], equals('Weekly CT'));

      final restored = Task.fromJson(json);
      expect(restored.customCategory, equals('Weekly CT'));
      expect(restored.type, equals(TaskType.custom));
    });

    test('fromJson handles legacy tasks without customCategory', () {
      final legacyJson = {
        'id': 'legacy_1',
        'title': 'Legacy custom task',
        'type': 'custom',
        'dueDate': '2026-11-10',
        'priority': 'medium',
        'status': 'pending',
        'reminders': <dynamic>[],
        'createdAt': '2026-11-01T00:00:00.000',
      };

      final task = Task.fromJson(legacyJson);
      expect(task.customCategory, isNull);
      expect(task.type, equals(TaskType.custom));
      expect(taskCategoryLabel(task), equals('Custom'));
    });

    test('copyWith updates and clears customCategory', () {
      final task = Task(
        title: 'Groceries',
        type: TaskType.custom,
        customCategory: 'Shopping',
        dueDate: '2026-11-10',
        priority: TaskPriority.low,
      );

      final updated = task.copyWith(customCategory: 'Personal Work');
      expect(updated.customCategory, equals('Personal Work'));

      final cleared = updated.copyWith(clearCustomCategory: true);
      expect(cleared.customCategory, isNull);
    });

    test('fromJson safely falls back to defaults on unknown or corrupt enums', () {
      final corruptJson = {
        'id': 'corrupt_1',
        'title': 'Corrupt Task',
        'type': 'non_existent_type_foo',
        'dueDate': '2026-11-10',
        'priority': 'super_urgent_unknown',
        'status': 'in_progress_unknown',
        'reminders': [
          {
            'id': 'rem_1',
            'type': 'unknown_reminder_type',
          }
        ],
      };

      final task = Task.fromJson(corruptJson);
      expect(task.type, equals(TaskType.other));
      expect(task.priority, equals(TaskPriority.medium));
      expect(task.status, equals(TaskStatus.pending));
      expect(task.reminders.first.type, equals(ReminderType.atTime));
    });
  });

  group('taskCategoryLabel and subtitleText', () {
    test('returns customCategory for custom tasks when specified', () {
      final task = Task(
        title: 'Weekly revision',
        type: TaskType.custom,
        customCategory: 'Weekly CT',
        dueDate: '2026-11-10',
        priority: TaskPriority.medium,
      );

      expect(taskCategoryLabel(task), equals('Weekly CT'));
      expect(subtitleText(task, TaskUrgency.upcoming), contains('Weekly CT'));
    });

    test('falls back to "Custom" if customCategory is empty or null', () {
      final taskNull = Task(
        title: 'Hiking',
        type: TaskType.custom,
        dueDate: '2026-11-10',
        priority: TaskPriority.low,
      );
      final taskBlank = Task(
        title: 'Hiking',
        type: TaskType.custom,
        customCategory: '   ',
        dueDate: '2026-11-10',
        priority: TaskPriority.low,
      );

      expect(taskCategoryLabel(taskNull), equals('Custom'));
      expect(taskCategoryLabel(taskBlank), equals('Custom'));
    });

    test('preserves predefined category names', () {
      expect(formatPredefinedTaskType(TaskType.assignment), equals('Assignment'));
      expect(formatPredefinedTaskType(TaskType.exam), equals('Exam'));
      expect(formatPredefinedTaskType(TaskType.ct), equals('Class Test (CT)'));
      expect(formatPredefinedTaskType(TaskType.viva), equals('Viva'));
      expect(formatPredefinedTaskType(TaskType.presentation), equals('Presentation'));
      expect(formatPredefinedTaskType(TaskType.lab), equals('Lab'));
      expect(formatPredefinedTaskType(TaskType.project), equals('Project'));
    });
  });

  group('NewTaskSheet Custom Category UI', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStore.instance.init();
    });

    testWidgets('shows custom category text field when Custom is selected',
        (tester) async {
      final appState = AppState();
      final routineState = RoutineState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<RoutineState>.value(value: routineState),
          ],
          child: MaterialApp(
            theme: AppTheme.build(AppColors.dark, Brightness.dark),
            home: Scaffold(
              body: NewTaskSheet(
                initialType: TaskType.custom,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom Category input field should be visible
      expect(find.text('CUSTOM CATEGORY NAME'), findsOneWidget);
      expect(find.text('Weekly CT'), findsOneWidget); // suggestion chip
      expect(find.text('Personal Work'), findsOneWidget); // suggestion chip
      expect(find.text('Outdoor Activities'), findsOneWidget); // suggestion chip

      // Tap on a suggestion chip
      await tester.tap(find.text('Weekly CT'));
      await tester.pumpAndSettle();

      // Enter task title
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Algorithms Class Test'),
          'Algorithm CT 2');
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('Save Task'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.tasks.length, equals(1));
      final savedTask = appState.tasks.first;
      expect(savedTask.title, equals('Algorithm CT 2'));
      expect(savedTask.type, equals(TaskType.custom));
      expect(savedTask.customCategory, equals('Weekly CT'));
    });

    testWidgets('user can type arbitrary custom category name', (tester) async {
      final appState = AppState();
      final routineState = RoutineState();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<RoutineState>.value(value: routineState),
          ],
          child: MaterialApp(
            theme: AppTheme.build(AppColors.dark, Brightness.dark),
            home: Scaffold(
              body: NewTaskSheet(
                initialType: TaskType.custom,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Type custom category name
      final customCategoryFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText ==
                'e.g. Weekly CT, Personal Work, Shopping...',
      );
      expect(customCategoryFinder, findsOneWidget);

      await tester.enterText(customCategoryFinder, 'Going Outside');
      await tester.pumpAndSettle();

      // Enter task title
      await tester.enterText(
          find.widgetWithText(TextField, 'e.g. Algorithms Class Test'),
          'Walk in park');
      await tester.pumpAndSettle();

      // Save task
      await tester.tap(find.text('Save Task'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.tasks.length, equals(1));
      final savedTask = appState.tasks.first;
      expect(savedTask.title, equals('Walk in park'));
      expect(savedTask.type, equals(TaskType.custom));
      expect(savedTask.customCategory, equals('Going Outside'));
      expect(taskCategoryLabel(savedTask), equals('Going Outside'));
    });

    testWidgets('edit custom category from TaskDetailSheet', (tester) async {
      final appState = AppState();
      final routineState = RoutineState();
      final task = Task(
        title: 'Weekly revision',
        type: TaskType.custom,
        customCategory: 'Weekly CT',
        dueDate: '2026-11-10',
        priority: TaskPriority.medium,
      );
      appState.addTask(task);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: appState),
            ChangeNotifierProvider<RoutineState>.value(value: routineState),
          ],
          child: MaterialApp(
            theme: AppTheme.build(AppColors.dark, Brightness.dark),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showTaskDetailSheet(ctx, task),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Weekly CT'), findsWidgets);

      // Tap edit icon next to category
      final editIconFinder = find.byIcon(Icons.edit_outlined);
      expect(editIconFinder, findsOneWidget);
      await tester.tap(editIconFinder);
      await tester.pumpAndSettle();

      expect(find.text('Edit Category Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Weekly Quiz');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      expect(appState.tasks.first.customCategory, equals('Weekly Quiz'));
      expect(find.textContaining('Weekly Quiz'), findsWidgets);
    });
  });
}
