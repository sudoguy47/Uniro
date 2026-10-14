import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app/app.dart';
import 'services/local_store.dart';
import 'services/notes_store.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'state/app_state.dart';
import 'state/focus_state.dart';
import 'state/notes_state.dart';
import 'state/routine_state.dart';
import 'theme/app_colors.dart';

void main() async {
  // ① Flutter binding initialization
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // ② Edge-to-edge configured synchronously BEFORE widget tree builds
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  ));

  // ③ Device orientation configured
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ④ Phase 1 Bootstrap: Hydrate SharedPreferences BEFORE first frame.
  // NOTE: intl's initializeDateFormatting() intentionally NOT awaited here —
  // the default 'en' locale works without it and preloading every locale
  // wastes ~200ms + RAM on startup. Calendar month names fall back to 'en'.
  final notesStore = NotesStore();
  final routineState = RoutineState();
  final focusState = FocusState();
  await Future.wait([
    LocalStore.instance.init(),
    notesStore.load(),
  ]);

  // Hydrate state directly into RAM before mounting widgets.
  app.loadFromStore();
  final notesState = NotesState(store: notesStore);
  await routineState.load();
  await focusState.load();

  final showOnboarding = !LocalStore.instance.isOnboardingDone;

  // ⑤ Mount the widget tree immediately.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider(create: (_) => notesState),
        ChangeNotifierProvider.value(value: routineState),
        ChangeNotifierProvider.value(value: focusState),
      ],
      child: CampusTrackerApp(showOnboarding: showOnboarding),
    ),
  );

  // ⑥ Phase 2 Bootstrap: defer font warmup + notifications until after
  // the first frame, via idle scheduler tasks.
  widgetsBinding.addPostFrameCallback((_) {
    _scheduleDeferredWarmup(routineState);
    // One-shot GitHub update check (background, silent on failure).
    // ignore: discarded_futures
    _checkForUpdateOnce();
  });
}

/// One-shot in-app update check. Runs in the background after the first
/// frame; shows the "Update available" dialog only when a newer GitHub
/// release exists. Never throws, never blocks.
Future<void> _checkForUpdateOnce() async {
  final update = await checkForUpdate();
  if (update == null) return;
  final nav = CampusTrackerApp.navigatorKey.currentState;
  if (nav == null || !nav.mounted) return;
  // nav.mounted guards nav.context (same element).
  final ctx = nav.context;
  if (!ctx.mounted) return;
  await showDialog<void>(
    context: ctx,
    barrierDismissible: true,
    builder: (dialogCtx) {
      final c = Theme.of(dialogCtx).extension<AppColors>()!;
      return AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('Update available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Version ${update.version} is ready.',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              if (update.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(update.notes.trim(),
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              skipUpdateVersion(update.tag);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Skip this version'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await launchUrl(
                  Uri.parse(update.apkUrl),
                  mode: LaunchMode.externalApplication,
                );
              } catch (e) {
                debugPrint('open apk link notice: $e');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update'),
          ),
        ],
      );
    },
  );
}

/// Schedules non-critical warmup tasks during engine idle time.
void _scheduleDeferredWarmup(RoutineState routineState) {
  // Pre-warm font tables during idle cycles (prevents first-scroll jank).
  // ignore: discarded_futures
  _prewarmFontsAndAssets();

  // Initialize background notification channels (idle — never blocks frames).
  Future<void>(() async {
    await NotificationService.instance.init();
    // Tasks + daily greeting + class reminders, re-armed every launch.
    await NotificationService.instance.rearmAll(
      tasks: app.tasks,
      courses: routineState.courses,
      slots: routineState.slots,
      name: app.settings.name,
      enabled: app.settings.notificationsEnabled,
    );
  });
}

/// Pre-warms the font rendering pipeline to prevent glyph-cache jank.
void _prewarmFontsAndAssets() {
  try {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'CampusTracker 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz',
        style: TextStyle(fontFamily: 'Inter', fontSize: 15),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.dispose();
  } catch (e) {
    debugPrint('Font prewarm notice: $e');
  }
}
