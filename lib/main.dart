import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'services/device_channel.dart';
import 'services/error_log.dart';
import 'domain/haptics.dart';
import 'services/local_store.dart';
import 'services/notes_store.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'state/app_state.dart';
import 'state/focus_state.dart';
import 'state/notes_state.dart';
import 'state/routine_state.dart';
import 'widgets/update_dialog.dart';

void main() {
  // Global error capture first, so even bootstrap failures are logged.
  // Local only: last 20 errors, no network.
  ErrorLog.install();
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _NeutralErrorCard();
  }
  runZonedGuarded(() async {
    await _boot();
  }, (error, stack) {
    ErrorLog.record(error, stack, 'zone');
  });
}

/// Small neutral fallback for release builds (no red screen, no trace).
class _NeutralErrorCard extends StatelessWidget {
  const _NeutralErrorCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Something went wrong here.'),
      ),
    );
  }
}

Future<void> _boot() async {
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
  NotesState? notesState;
  bool showOnboarding = true;
  try {
    await Future.wait([
      LocalStore.instance.init(),
      notesStore.load(),
      ErrorLog.init(),
    ]);

    // Hydrate state directly into RAM before mounting widgets.
    app.loadFromStore();
    notesState = NotesState(store: notesStore);
    await routineState.load();
    await focusState.load();
    showOnboarding = !LocalStore.instance.isOnboardingDone;
  } catch (e) {
    debugPrint('Bootstrap notice (mounting defaults): $e');
    LocalStore.instance.markRecovery();
    notesState ??= NotesState(store: notesStore);
    showOnboarding = true;
  }

  // ⑤ Mount the widget tree immediately.
  final readyNotes = notesState;
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider(create: (_) => readyNotes),
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
    _maybeShowRecoveryBanner();
  });
}

/// One-time friendly banner when corrupt data was backed up during boot.
void _maybeShowRecoveryBanner() {
  if (!LocalStore.instance.hadRecovery) return;
  LocalStore.instance.clearRecoveryFlag();
  final nav = CampusTrackerApp.navigatorKey.currentState;
  final ctx = nav?.context;
  if (ctx == null || !ctx.mounted) return;
  ScaffoldMessenger.of(ctx).showSnackBar(
    const SnackBar(
      content: Text("Some data couldn't be read and was backed up."),
      duration: Duration(seconds: 5),
    ),
  );
}

/// One-shot in-app update check. Runs in the background after the first
/// frame; shows the shared update dialog (download + install in the app)
/// only when a newer GitHub release exists. Never throws, never blocks.
Future<void> _checkForUpdateOnce() async {
  final update = await checkForUpdate();
  if (update == null) return;
  final nav = CampusTrackerApp.navigatorKey.currentState;
  if (nav == null || !nav.mounted) return;
  // nav.mounted guards nav.context (same element).
  final ctx = nav.context;
  if (!ctx.mounted) return;
  await showUpdateDialog(ctx, update);
}

/// Schedules non-critical warmup tasks during engine idle time.
void _scheduleDeferredWarmup(RoutineState routineState) {
  // Pre-warm font tables during idle cycles (prevents first-scroll jank).
  // ignore: discarded_futures
  _prewarmFontsAndAssets();

  // Enrich stored errors with real version / API level (best effort).
  Future<void>(() async {
    try {
      String? version;
      try {
        final v = await installedVersion();
        if (v.isNotEmpty) version = v;
      } catch (_) {}
      String? api;
      try {
        api = (await DeviceChannel.getDeviceInfo())?['apiLevel']?.toString();
      } catch (_) {}
      ErrorLog.updateContext(appVersion: version, apiLevel: api);
    } catch (_) {}
  });

  // Prime the haptic capability cache (vibrator present? system touch
  // feedback on?). Defaults assume capable, so this only ever silences
  // haptics that would be no-ops anyway. Best effort, never throws.
  Future<void>(() async {
    try {
      await HapticsCapabilities.refresh();
    } catch (_) {}
  });

  // Initialize background notification channels (idle — never blocks frames).
  Future<void>(() async {
    try {
      await NotificationService.instance.init();
      // Normal launch re-arm; internally skipped when the time-change path
      // below already rebuilt everything.
      final refreshed =
          await NotificationService.instance.checkAndRescheduleIfNeeded(
        tasks: app.tasks,
        courses: routineState.courses,
        slots: routineState.slots,
        name: app.settings.name,
        enabled: app.settings.notificationsEnabled,
      );
      if (!refreshed) {
        // Tasks + daily greeting + class reminders, re-armed every launch.
        await NotificationService.instance.rearmAll(
          tasks: app.tasks,
          courses: routineState.courses,
          slots: routineState.slots,
          name: app.settings.name,
          enabled: app.settings.notificationsEnabled,
        );
      }
    } catch (e) {
      debugPrint('deferred notify warmup notice: $e');
    }
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
