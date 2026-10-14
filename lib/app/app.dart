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
      builder: (context, child) =>
          BoundaryHaptics(child: child ?? const SizedBox.shrink()),
      home: showOnboarding
          ? const OnboardingScreen()
          : AppShell(key: AppShell.shellKey),
    );
  }
}
