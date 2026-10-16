import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/app/app_shell.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/screens/onboarding_screen.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/services/notes_store.dart';
import 'package:uniro1/state/app_state.dart';
import 'package:uniro1/state/focus_state.dart';
import 'package:uniro1/state/notes_state.dart';
import 'package:uniro1/state/routine_state.dart';
import 'package:uniro1/theme/app_colors.dart';
import 'package:uniro1/theme/app_theme.dart';
import 'package:uniro1/widgets/flip_card.dart';
import 'package:uniro1/widgets/hero_carousel.dart';
import 'package:uniro1/widgets/weekly_bar_chart.dart';

/// Small screens + large text audit (Phase 2B).
///
/// Pumps the real shell (all 5 tabs) and the riskiest fixed-size widgets
/// at 320x640 with text scales 1.0 / 1.3 / 2.0. Any RenderFlex overflow
/// throws during layout and fails the test via [takeException].
/// The app clamps text to 1.3 in production ([CampusTrackerApp] builder),
/// but widgets must survive raw 2.0 without throwing.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  Future<Widget> shelledApp() async {
    final appState = AppState()..loadFromStore();
    final notesStore = NotesStore();
    await notesStore.load();
    final routine = RoutineState();
    await routine.load();
    final focus = FocusState();
    await focus.load();
    final notes = NotesState(store: notesStore);
    // MaterialApp supplies Theme/AppColors — without it every screen
    // throws on the AppColors null-check. Light theme here; dark mode is
    // covered on emulators per RELEASE_CHECKLIST.md.
    return MaterialApp(
      theme: AppTheme.build(AppColors.light, Brightness.light),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: routine),
          ChangeNotifierProvider.value(value: focus),
          ChangeNotifierProvider(create: (_) => notes),
        ],
        child: const AppShell(),
      ),
    );
  }

  Future<void> setSurface(
      WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize =
        Size(size.width * 3, size.height * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue());
  }

  void drainExceptions(WidgetTester tester, String where) {
    final errors = <Object>[];
    Object? err = tester.takeException();
    while (err != null) {
      errors.add(err);
      err = tester.takeException();
    }
    if (errors.isNotEmpty) {
      final first = errors.first;
      final details =
          first is FlutterError ? first.toStringDeep() : '$first';
      debugPrint('RESPONSIVE-FAILURE@${where.toString()}: $details');
      fail('$where threw ${errors.length} error(s): ${details.split('\n').first}');
    }
  }

  Future<void> tourTabs(WidgetTester tester) async {
    for (final label in [
      'Routine',
      'Focus',
      'Notes',
      'Profile',
      'Dashboard'
    ]) {
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 500));
      drainExceptions(tester, 'tab $label');
    }
  }

  group('shell at 320x640', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('no overflow at text scale $scale', (tester) async {
        await setSurface(tester, const Size(320, 640), scale);
        await tester.pumpWidget(await shelledApp());
        await tester.pump(const Duration(seconds: 1));
        drainExceptions(tester, 'launch@$scale');
        await tourTabs(tester);
      });
    }
  });

  testWidgets('360x740 at 1.3 tours clean', (tester) async {
    await setSurface(tester, const Size(360, 740), 1.3);
    await tester.pumpWidget(await shelledApp());
    await tester.pump(const Duration(seconds: 1));
    drainExceptions(tester, 'launch');
    await tourTabs(tester);
  });

  testWidgets('onboarding at 320x640 / 1.3', (tester) async {
    await setSurface(tester, const Size(320, 640), 1.3);
    final appState = AppState()..loadFromStore();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
        ],
        child: MaterialApp(
          theme: AppTheme.build(AppColors.light, Brightness.light),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    drainExceptions(tester, 'onboarding');
    // Swipe through all slides.
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 500));
      drainExceptions(tester, 'onboarding slide $i');
    }
  });

  testWidgets('fixed-size widgets survive raw 2.0 at 320dp', (tester) async {
    await setSurface(tester, const Size(320, 640), 2.0);
    final longTask = Task(
      title: 'A very long task title that must ellipsize instead of throwing',
      description:
          'An equally long description that spans multiple lines and must be cut off gracefully without breaking layout.',
      type: TaskType.assignment,
      dueDate: '2026-10-20',
      dueTime: '10:00',
      hasTime: true,
      priority: TaskPriority.high,
    );
    final minPair = ValueNotifier<String>('25');
    final secPair = ValueNotifier<String>('00');
    addTearDown(minPair.dispose);
    addTearDown(secPair.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(AppColors.light, Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 320,
              child: Column(
              children: [
                SizedBox(
                  width: 288,
                  child: HeroCarousel(tasks: [longTask]),
                ),
                const WeeklyBarChart(
                  weekStart: '2026-10-12',
                  load: {'2026-10-14': 123},
                  selectedDay: '2026-10-14',
                ),
                SizedBox(
                  width: 288,
                  height: 220,
                  child: Column(
                    children: [
                      Expanded(child: FlipCard(value: minPair)),
                      const SizedBox(height: 12),
                      Expanded(child: FlipCard(value: secPair)),
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    // TEMP-DIAG swallow disabled to surface the full dump.
    // drainExceptions(tester, 'fixed widgets @2.0');
  });
}
