import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app/app.dart';
import 'services/local_store.dart';
import 'services/notes_store.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'state/notes_state.dart';

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
  await Future.wait([
    LocalStore.instance.init(),
    notesStore.load(),
  ]);

  // Hydrate state directly into RAM before mounting widgets.
  app.loadFromStore();
  final notesState = NotesState(store: notesStore);

  final showOnboarding = !LocalStore.instance.isOnboardingDone;

  // ⑤ Mount the widget tree immediately.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider(create: (_) => notesState),
      ],
      child: CampusTrackerApp(showOnboarding: showOnboarding),
    ),
  );

  // ⑥ Phase 2 Bootstrap: defer font warmup + notifications until after
  // the first frame, via idle scheduler tasks.
  widgetsBinding.addPostFrameCallback((_) {
    _scheduleDeferredWarmup();
  });
}

/// Schedules non-critical warmup tasks during engine idle time.
void _scheduleDeferredWarmup() {
  // Pre-warm font tables during idle cycles (prevents first-scroll jank).
  // ignore: discarded_futures
  _prewarmFontsAndAssets();

  // Initialize background notification channels (idle — never blocks frames).
  Future<void>(() async {
    await NotificationService.instance.init();
    await NotificationService.instance.rescheduleAll(app.tasks);
    // Daily 6 AM greeting + life motivation (re-arms every launch).
    await NotificationService.instance.scheduleDailyGreeting(
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
