# 01. Design Tokens — Flutter (`theme/`)

> GymMane-এর `app_colors.dart` + `app_theme.dart` exact same pattern.

---

## app_colors.dart

```dart
import 'package:flutter/material.dart';

// GymMane GymColors pattern — ThemeExtension
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.pageBg,
    required this.cardBg,
    required this.cardBgRaised,
    required this.inputBg,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.overdue,
    required this.overdueLight,
    required this.dueToday,
    required this.upcoming,
    required this.navBg,
    required this.navActiveBg,
    required this.navActiveText,
    required this.navInactive,
    required this.chartBarRed,
    required this.chartBarGold,
    required this.chartBarEmpty,
    required this.fabBg,
    required this.fabIcon,
    required this.toggleActive,
    required this.toggleInactive,
  });

  final Color pageBg;
  final Color cardBg;
  final Color cardBgRaised;
  final Color inputBg;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color overdue;
  final Color overdueLight;
  final Color dueToday;
  final Color upcoming;
  final Color navBg;
  final Color navActiveBg;
  final Color navActiveText;
  final Color navInactive;
  final Color chartBarRed;
  final Color chartBarGold;
  final Color chartBarEmpty;
  final Color fabBg;
  final Color fabIcon;
  final Color toggleActive;
  final Color toggleInactive;

  // ── Light Mode ──────────────────────────────────────────────
  static const light = AppColors(
    pageBg:         Color(0xFFEDE8DF),
    cardBg:         Color(0xFFFFFFFF),
    cardBgRaised:   Color(0xFFF5F0E8),
    inputBg:        Color(0xFFF5F0E8),
    border:         Color(0xFFE0D9CF),
    borderLight:    Color(0xFFEDE8E0),
    textPrimary:    Color(0xFF1A1713),
    textSecondary:  Color(0xFF6B6057),
    textTertiary:   Color(0xFF9E9589),
    accent:         Color(0xFFE8963C),
    accentLight:    Color(0xFFFDF0E0),
    accentDark:     Color(0xFFC67C28),
    overdue:        Color(0xFFD94F3D),
    overdueLight:   Color(0xFFFCE8E5),
    dueToday:       Color(0xFFE8963C),
    upcoming:       Color(0xFF5A8A5A),
    navBg:          Color(0xFFFFFFFF),
    navActiveBg:    Color(0xFF1A1713),
    navActiveText:  Color(0xFFFFFFFF),
    navInactive:    Color(0xFF9E9589),
    chartBarRed:    Color(0xFFD94F3D),
    chartBarGold:   Color(0xFFC9962A),
    chartBarEmpty:  Color(0xFFE8E3DC),
    fabBg:          Color(0xFF1A1713),
    fabIcon:        Color(0xFFFFFFFF),
    toggleActive:   Color(0xFFE8963C),
    toggleInactive: Color(0xFFD0C9C0),
  );

  // ── Dark Mode ───────────────────────────────────────────────
  static const dark = AppColors(
    pageBg:         Color(0xFF0F0E0C),
    cardBg:         Color(0xFF1C1A17),
    cardBgRaised:   Color(0xFF252219),
    inputBg:        Color(0xFF2A2620),
    border:         Color(0xFF3A3630),
    borderLight:    Color(0xFF302C26),
    textPrimary:    Color(0xFFF5F0E8),
    textSecondary:  Color(0xFF9E9589),
    textTertiary:   Color(0xFF6B6057),
    accent:         Color(0xFFE8963C),
    accentLight:    Color(0xFF2A1F0A),
    accentDark:     Color(0xFFC67C28),
    overdue:        Color(0xFFD94F3D),
    overdueLight:   Color(0xFF2A0E0A),
    dueToday:       Color(0xFFE8963C),
    upcoming:       Color(0xFF5A8A5A),
    navBg:          Color(0xFF1C1A17),
    navActiveBg:    Color(0xFFF5F0E8),
    navActiveText:  Color(0xFF1A1713),
    navInactive:    Color(0xFF6B6057),
    chartBarRed:    Color(0xFFD94F3D),
    chartBarGold:   Color(0xFFC9962A),
    chartBarEmpty:  Color(0xFF2A2620),
    fabBg:          Color(0xFFF5F0E8),
    fabIcon:        Color(0xFF1A1713),
    toggleActive:   Color(0xFFE8963C),
    toggleInactive: Color(0xFF3A3630),
  );

  @override
  AppColors copyWith({Color? pageBg, /* ...rest */}) => this;

  @override
  AppColors lerp(AppColors? other, double t) => this;
}

// Shortcut helper — use anywhere:
// final c = Theme.of(context).extension<AppColors>()!;
```

---

## app_theme.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';

class AppTheme {
  // ── Typography shortcuts (GymMane AppTheme.d / .f / .s)
  // AppTheme.display  → large bold headings
  // AppTheme.heading  → section titles
  // AppTheme.body     → regular text
  // AppTheme.label    → small caps labels

  static ThemeData build(AppColors c, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: c.pageBg,
      fontFamily: 'Inter',

      // ── GymMane: Zero ripple (splashColor: transparent) ──
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,

      // ── ThemeExtension: AppColors ──
      extensions: [c],

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: c.pageBg,
        elevation: 0,
        systemOverlayStyle: brightness == Brightness.light
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: c.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
    );
  }

  // Motion tokens (GymMane pattern)
  static const micro   = Duration(milliseconds: 140);
  static const fast    = Duration(milliseconds: 200);
  static const screen  = Duration(milliseconds: 260);
  static const navGlide= Duration(milliseconds: 340);
  static const modal   = Duration(milliseconds: 320);

  static const easeOutCubic = Curves.easeOutCubic;
  // GymMane Interval(0.3, 1.0)
  static const switchIn  = Interval(0.3, 1.0, curve: Curves.easeOutCubic);
  // GymMane Interval(0.6, 1.0)
  static const switchOut = Interval(0.6, 1.0, curve: Curves.easeOutCubic);
}
```
