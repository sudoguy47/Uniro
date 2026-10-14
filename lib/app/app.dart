import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/haptics.dart';
import '../models/settings.dart';
import '../screens/onboarding_screen.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class CampusTrackerApp extends StatelessWidget {
  const CampusTrackerApp({super.key, this.showOnboarding = false});

  final bool showOnboarding;

  /// System text-size accessibility is honored but clamped: below 1.0 text
  /// must never shrink (legibility floor), above 1.3 layouts are verified
  /// (see test/responsive_test.dart) but full-bleed 2.0x would break
  /// fixed-height cards, so it is capped.
  static const double kMinTextScale = 1.0;
  static const double kMaxTextScale = 1.3;

  /// Global navigator key so non-widget code (e.g. the OTA update checker in
  /// main.dart) can present dialogs/bottom sheets over the app.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final theme = context.select((AppState s) => s.settings.theme);
    final isDark = theme == AppThemeMode.dark ||
        (theme == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final colors = isDark ? AppColors.dark : AppColors.light;

    final themeMode = switch (theme) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.build(colors, Brightness.light),
      darkTheme: AppTheme.build(AppColors.dark, Brightness.dark),
      themeMode: themeMode,
      // Global edge-haptic layer: every scrollable in the app (lists,
      // pagers, sheets) thocks once per boundary-hit gesture.
      // Text scale is clamped here so every screen inherits the cap.
      builder: (context, child) {
        final base = MediaQuery.textScalerOf(context).clamp(
              minScaleFactor: kMinTextScale,
              maxScaleFactor: kMaxTextScale,
            );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: base),
          child: BoundaryHaptics(child: child ?? const SizedBox.shrink()),
        );
      },
      home: showOnboarding
          ? const OnboardingScreen()
          : AppShell(key: AppShell.shellKey),
    );
  }
}
