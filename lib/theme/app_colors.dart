import 'package:flutter/material.dart';

// ThemeExtension pattern for CampusTracker
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
    pageBg: Color(0xFFEDE8DF),
    cardBg: Color(0xFFFFFFFF),
    cardBgRaised: Color(0xFFF5F0E8),
    inputBg: Color(0xFFF5F0E8),
    border: Color(0xFFE0D9CF),
    borderLight: Color(0xFFEDE8E0),
    textPrimary: Color(0xFF1A1713),
    textSecondary: Color(0xFF6B6057),
    textTertiary: Color(0xFF9E9589),
    accent: Color(0xFFE8963C),
    accentLight: Color(0xFFFDF0E0),
    accentDark: Color(0xFFC67C28),
    overdue: Color(0xFFD94F3D),
    overdueLight: Color(0xFFFCE8E5),
    dueToday: Color(0xFFE8963C),
    upcoming: Color(0xFF5A8A5A),
    navBg: Color(0xFFFFFFFF),
    navActiveBg: Color(0xFF1A1713),
    navActiveText: Color(0xFFFFFFFF),
    navInactive: Color(0xFF9E9589),
    chartBarRed: Color(0xFFD94F3D),
    chartBarGold: Color(0xFFC9962A),
    chartBarEmpty: Color(0xFFE8E3DC),
    fabBg: Color(0xFF1A1713),
    fabIcon: Color(0xFFFFFFFF),
    toggleActive: Color(0xFFE8963C),
    toggleInactive: Color(0xFFD0C9C0),
  );

  // ── Dark Mode ───────────────────────────────────────────────
  static const dark = AppColors(
    pageBg: Color(0xFF0F0E0C),
    cardBg: Color(0xFF1C1A17),
    cardBgRaised: Color(0xFF252219),
    inputBg: Color(0xFF2A2620),
    border: Color(0xFF3A3630),
    borderLight: Color(0xFF302C26),
    textPrimary: Color(0xFFF5F0E8),
    textSecondary: Color(0xFF9E9589),
    textTertiary: Color(0xFF6B6057),
    accent: Color(0xFFE8963C),
    accentLight: Color(0xFF2A1F0A),
    accentDark: Color(0xFFC67C28),
    overdue: Color(0xFFD94F3D),
    overdueLight: Color(0xFF2A0E0A),
    dueToday: Color(0xFFE8963C),
    upcoming: Color(0xFF5A8A5A),
    navBg: Color(0xFF1C1A17),
    navActiveBg: Color(0xFFF5F0E8),
    navActiveText: Color(0xFF1A1713),
    navInactive: Color(0xFF6B6057),
    chartBarRed: Color(0xFFD94F3D),
    chartBarGold: Color(0xFFC9962A),
    chartBarEmpty: Color(0xFF2A2620),
    fabBg: Color(0xFFF5F0E8),
    fabIcon: Color(0xFF1A1713),
    toggleActive: Color(0xFFE8963C),
    toggleInactive: Color(0xFF3A3630),
  );

  @override
  AppColors copyWith({
    Color? pageBg,
    Color? cardBg,
    Color? cardBgRaised,
    Color? inputBg,
    Color? border,
    Color? borderLight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentLight,
    Color? accentDark,
    Color? overdue,
    Color? overdueLight,
    Color? dueToday,
    Color? upcoming,
    Color? navBg,
    Color? navActiveBg,
    Color? navActiveText,
    Color? navInactive,
    Color? chartBarRed,
    Color? chartBarGold,
    Color? chartBarEmpty,
    Color? fabBg,
    Color? fabIcon,
    Color? toggleActive,
    Color? toggleInactive,
  }) {
    return AppColors(
      pageBg: pageBg ?? this.pageBg,
      cardBg: cardBg ?? this.cardBg,
      cardBgRaised: cardBgRaised ?? this.cardBgRaised,
      inputBg: inputBg ?? this.inputBg,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDark: accentDark ?? this.accentDark,
      overdue: overdue ?? this.overdue,
      overdueLight: overdueLight ?? this.overdueLight,
      dueToday: dueToday ?? this.dueToday,
      upcoming: upcoming ?? this.upcoming,
      navBg: navBg ?? this.navBg,
      navActiveBg: navActiveBg ?? this.navActiveBg,
      navActiveText: navActiveText ?? this.navActiveText,
      navInactive: navInactive ?? this.navInactive,
      chartBarRed: chartBarRed ?? this.chartBarRed,
      chartBarGold: chartBarGold ?? this.chartBarGold,
      chartBarEmpty: chartBarEmpty ?? this.chartBarEmpty,
      fabBg: fabBg ?? this.fabBg,
      fabIcon: fabIcon ?? this.fabIcon,
      toggleActive: toggleActive ?? this.toggleActive,
      toggleInactive: toggleInactive ?? this.toggleInactive,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      cardBgRaised: Color.lerp(cardBgRaised, other.cardBgRaised, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      overdueLight: Color.lerp(overdueLight, other.overdueLight, t)!,
      dueToday: Color.lerp(dueToday, other.dueToday, t)!,
      upcoming: Color.lerp(upcoming, other.upcoming, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      navActiveBg: Color.lerp(navActiveBg, other.navActiveBg, t)!,
      navActiveText: Color.lerp(navActiveText, other.navActiveText, t)!,
      navInactive: Color.lerp(navInactive, other.navInactive, t)!,
      chartBarRed: Color.lerp(chartBarRed, other.chartBarRed, t)!,
      chartBarGold: Color.lerp(chartBarGold, other.chartBarGold, t)!,
      chartBarEmpty: Color.lerp(chartBarEmpty, other.chartBarEmpty, t)!,
      fabBg: Color.lerp(fabBg, other.fabBg, t)!,
      fabIcon: Color.lerp(fabIcon, other.fabIcon, t)!,
      toggleActive: Color.lerp(toggleActive, other.toggleActive, t)!,
      toggleInactive: Color.lerp(toggleInactive, other.toggleInactive, t)!,
    );
  }
}
