import 'dart:ui';
import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import '../theme/app_colors.dart';

enum AppNotificationType { success, error, warning, info }

/// Modern floating glassmorphic in-app notification / toast.
///
/// Designed to float gracefully above the bottom navigation bar without
/// overlapping, using translucent surfaces, subtle background blur, soft
/// borders, clean typography, and responsive insets.
class AppNotification {
  static void show(
    BuildContext context, {
    required String message,
    AppNotificationType type = AppNotificationType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final c = Theme.of(context).extension<AppColors>() ?? AppColors.dark;

    // Detect if bottom nav is present in the current view hierarchy
    // AppShell hosts the bottom navigation bar with height 68 + safeArea
    final isAppShellPresent =
        context.findAncestorWidgetOfExactType<Scaffold>() != null &&
            _isInsideAppShell(context);

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomMargin = isAppShellPresent
        ? 68.0 + bottomPadding + 14.0
        : bottomPadding + 16.0;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        padding: EdgeInsets.zero,
        duration: duration,
        content: _FloatingToastContent(
          message: message,
          type: type,
          colors: c,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(
      context,
      message: message,
      type: AppNotificationType.success,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    show(
      context,
      message: message,
      type: AppNotificationType.error,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3200),
  }) {
    show(
      context,
      message: message,
      type: AppNotificationType.warning,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    show(
      context,
      message: message,
      type: AppNotificationType.info,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  static bool _isInsideAppShell(BuildContext context) {
    // If the widget hierarchy includes the tab views or AppShell
    bool found = false;
    context.visitAncestorElements((element) {
      final widgetName = element.widget.runtimeType.toString();
      if (widgetName.contains('AppShell') ||
          widgetName.contains('DashboardScreen') ||
          widgetName.contains('RoutineScreen') ||
          widgetName.contains('FocusScreen') ||
          widgetName.contains('NotesScreen') ||
          widgetName.contains('ProfileScreen')) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }
}

class _FloatingToastContent extends StatelessWidget {
  const _FloatingToastContent({
    required this.message,
    required this.type,
    required this.colors,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppNotificationType type;
  final AppColors colors;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = colors;

    // Visual attributes per type (tasteful, non-garish tints)
    final (icon, iconColor, bgGlow) = switch (type) {
      AppNotificationType.success => (
          Icons.check_circle_rounded,
          const Color(0xFF4E9A68),
          const Color(0x1F4E9A68),
        ),
      AppNotificationType.error => (
          Icons.error_outline_rounded,
          const Color(0xFFD9534F),
          const Color(0x1FD9534F),
        ),
      AppNotificationType.warning => (
          Icons.warning_amber_rounded,
          const Color(0xFFE8963C),
          const Color(0x1FE8963C),
        ),
      AppNotificationType.info => (
          Icons.info_outline_rounded,
          c.accent,
          c.accent.withValues(alpha: 0.12),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.cardBgRaised.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: c.border.withValues(alpha: 0.8),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bgGlow,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                    height: 1.3,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    PremiumHaptics.tap();
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction!();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.accent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
