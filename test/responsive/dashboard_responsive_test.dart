import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/app/app_shell.dart';
import 'package:uniro1/models/class_slot.dart';
import 'package:uniro1/models/course.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/screens/dashboard_screen.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/services/notes_store.dart';
import 'package:uniro1/state/app_state.dart';
import 'package:uniro1/state/attendance_state.dart';
import 'package:uniro1/state/focus_state.dart';
import 'package:uniro1/state/notes_state.dart';
import 'package:uniro1/state/routine_state.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/theme/app_theme.dart';
import 'package:uniro1/widgets/hero_carousel.dart';
import 'package:uniro1/widgets/next_class_card.dart';
import 'package:uniro1/widgets/task_card.dart';
import 'package:uniro1/widgets/weekly_bar_chart.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  Future<Widget> buildDashboardTestApp({
    AppState? appState,
    RoutineState? routineState,
    FocusState? focusState,
    NotesState? notesState,
    AttendanceState? attendanceState,
  }) async {
    final app = appState ?? (AppState()..loadFromStore());
    final notesStore = NotesStore();
    await notesStore.load();
    final routine = routineState ?? RoutineState();
    await routine.load();
    final focus = focusState ?? FocusState();
    await focus.load();
    final notes = notesState ?? NotesState(store: notesStore);
    final attendance = attendanceState ?? AttendanceState();
    await attendance.load();

    // Seed dummy data if empty so all dashboard widgets render real content
    if (app.tasks.isEmpty) {
      app.addTask(
        Task(
          title: 'CS101 Algorithm Assignment 1',
          description: 'Submit PDF report with sorting algorithm benchmark analysis.',
          type: TaskType.assignment,
          dueDate: '2026-10-25',
          dueTime: '23:59',
          hasTime: true,
          priority: TaskPriority.high,
        ),
      );
      app.addTask(
        Task(
          title: 'Physics Midterm Exam Prep',
          description: 'Review chapters 1-5 problem sets and practice test.',
          type: TaskType.exam,
          dueDate: '2026-10-28',
          dueTime: '10:00',
          hasTime: true,
          priority: TaskPriority.high,
        ),
      );
    }

    if (routine.courses.isEmpty) {
      routine.addCourse(
        Course(
          id: 'course_1',
          name: 'Computer Science 101',
          code: 'CS101',
          colorTag: 0xFF4A90E2,
        ),
      );
    }

    if (routine.slots.isEmpty) {
      final now = DateTime.now();
      routine.addSlot(
        ClassSlot(
          courseId: 'course_1',
          weekday: now.weekday,
          startMinutes: 8 * 60,
          endMinutes: 23 * 60 + 59,
          room: 'Room 302',
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(AppColors.light, Brightness.light),
      darkTheme: AppTheme.build(AppColors.dark, Brightness.dark),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: app),
          ChangeNotifierProvider.value(value: routine),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider.value(value: notes),
          ChangeNotifierProvider.value(value: attendance),
        ],
        child: const AppShell(initialTab: AppTab.dashboard),
      ),
    );
  }

  void configureViewport(WidgetTester tester, Size logicalSize, {double pixelRatio = 3.0}) {
    tester.view.physicalSize = Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio);
    tester.view.devicePixelRatio = pixelRatio;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  void checkForLayoutErrors(WidgetTester tester, String scenario) {
    final List<Object> errors = [];
    Object? err = tester.takeException();
    while (err != null) {
      errors.add(err);
      err = tester.takeException();
    }
    if (errors.isNotEmpty) {
      final first = errors.first;
      final details = first is FlutterError ? first.toStringDeep() : '$first';
      fail('Layout/Rendering Error during [$scenario]: ${details.split('\n').first}');
    }
  }

  group('Dashboard Responsive Viewport Tests', () {
    const viewports = <String, Size>{
      '320x568 (Compact Phone)': Size(320, 568),
      '393x852 (Standard Phone)': Size(393, 852),
      '440x956 (Large Phone)': Size(440, 956),
    };

    for (final entry in viewports.entries) {
      final label = entry.key;
      final size = entry.value;

      testWidgets('Dashboard renders without overflow or exception at $label', (tester) async {
        configureViewport(tester, size);

        final widget = await buildDashboardTestApp();
        await tester.pumpWidget(widget);
        await tester.pump(const Duration(milliseconds: 500));

        checkForLayoutErrors(tester, '$label - Initial Render');

        // Verify key Dashboard UI elements exist
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(NextClassCard), findsOneWidget);
        expect(find.byType(HeroCarousel), findsOneWidget);
        expect(find.byType(WeeklyBarChart), findsOneWidget);

        // Test scrolling down the CustomScrollView feed
        final scrollableFinder = find.byType(CustomScrollView);
        expect(scrollableFinder, findsOneWidget);

        await tester.drag(scrollableFinder, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 500));

        checkForLayoutErrors(tester, '$label - Scroll Down');

        // Scroll back up
        await tester.drag(scrollableFinder, const Offset(0, 300));
        await tester.pump(const Duration(milliseconds: 500));

        checkForLayoutErrors(tester, '$label - Scroll Up');
      });

      testWidgets('Dashboard handles text scale 1.3 at $label', (tester) async {
        configureViewport(tester, size);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(() => tester.platformDispatcher.clearTextScaleFactorTestValue());

        final widget = await buildDashboardTestApp();
        await tester.pumpWidget(widget);
        await tester.pump(const Duration(milliseconds: 500));

        // Scroll down to ensure TaskCard is built and visible. The weekly
        // agenda added height above the list, so drag further than before.
        final scrollableFinder = find.byType(CustomScrollView);
        if (scrollableFinder.evaluate().isNotEmpty) {
          await tester.drag(scrollableFinder, const Offset(0, -900));
          await tester.pump(const Duration(milliseconds: 500));
        }

        checkForLayoutErrors(tester, '$label - Text Scale 1.3');

        // Verify TaskCard renders without RenderFlex overflow
        expect(find.byType(TaskCard), findsWidgets);
      });
    }

    testWidgets('Dashboard modal popover "+" handles compact viewport (320x568)', (tester) async {
      configureViewport(tester, const Size(320, 568));

      final widget = await buildDashboardTestApp();
      await tester.pumpWidget(widget);
      await tester.pump(const Duration(milliseconds: 500));

      // Find "+" button or plus action and tap it
      final plusFinder = find.byIcon(Icons.add_rounded);
      if (plusFinder.evaluate().isNotEmpty) {
        await tester.tap(plusFinder.first);
        await tester.pump(const Duration(milliseconds: 500));

        checkForLayoutErrors(tester, '320x568 - Plus Popover');

        // Verify popover options appear
        expect(find.text('Create task'), findsOneWidget);
        expect(find.text('Add class routine'), findsOneWidget);
      }
    });
  });
}
