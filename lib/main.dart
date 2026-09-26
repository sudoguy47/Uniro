import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'services/local_store.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'state/app_state.dart';
import 'widgets/stretch_effect_loader.dart';
import 'widgets/update_dialog.dart';

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

  // ④ Phase 1 Bootstrap: Hydrate SharedPreferences and date formatting BEFORE first frame.
  // Running disk I/O and SharedPreferencesApi.getAll during the native splash phase avoids
  // platform channel IPC contention with the Flutter engine's VSync frame pump.
  await Future.wait([
    LocalStore.instance.init(),
    initializeDateFormatting(),
  ]);

  // Hydrate state directly into RAM before mounting widgets.
  // Frame 1 renders with full hydrated data in a single pass without empty-state flashing.
  app.loadFromStore();

  // ⑤ Mount the widget tree immediately.
  runApp(
    ChangeNotifierProvider.value(
      value: app,
      child: const CampusTrackerApp(),
    ),
  );

  // ⑥ Phase 2 Bootstrap: Defer heavy assets, shader compilation, font parsing, and
  // notification services until after the first frame has rendered, using idle scheduler tasks.
  widgetsBinding.addPostFrameCallback((_) {
    _scheduleDeferredWarmup();
  });
}

/// Schedules non-critical warmup tasks during engine idle time (between VSync intervals).
/// Guarantees that neither startup nor interactive scroll frames suffer GC or raster stalls.
void _scheduleDeferredWarmup() {
  // 1. Preload & compile stretch shader during idle cycles off the frame pipeline
  SchedulerBinding.instance.scheduleTask<void>(
    () async {
      await ShaderCache.preload();
    },
    Priority.idle,
  );

  // 2. Pre-warm font tables and glyph caches during idle cycles
  SchedulerBinding.instance.scheduleTask<void>(
    _prewarmFontsAndAssets,
    Priority.idle,
  );

  // 3. Initialize background notification channels
  SchedulerBinding.instance.scheduleTask<void>(
    () async {
      await NotificationService.instance.init();
      await NotificationService.instance.rescheduleAll(app.tasks);
    },
    Priority.idle,
  );

  // 4. OTA update check — runs AFTER startup fully settles (3s delay) so the
  //    network call never contends with first-run frames, fonts, or shaders.
  SchedulerBinding.instance.scheduleTask<void>(
    _checkForOtaUpdate,
    Priority.idle,
  );
}

/// Checks GitHub Releases for a newer APK and presents the update sheet.
/// Fully fire-and-forget: every failure path silently no-ops.
Future<void> _checkForOtaUpdate() async {
  // Give startup + deferred warmup time to finish before touching the network.
  await Future<void>.delayed(const Duration(seconds: 3));

  try {
    final update = await UpdateService.checkForUpdate();
    final context = CampusTrackerApp.navigatorKey.currentContext;
    if (update != null && context != null && context.mounted) {
      showUpdateSheet(context, update);
    }
  } catch (e) {
    debugPrint('Update check notice: $e');
  }
}

/// Pre-warms the font rendering and text shaping pipeline to prevent font table
/// parsing from dropping frames during startup and subsequent frame cycles.
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
