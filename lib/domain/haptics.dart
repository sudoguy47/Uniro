import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// App-wide premium haptic language.
///
/// - tap: standard controls (buttons, cards, rows)
/// - select: low-weight toggles (tabs, chips, switches, steppers)
/// - confirm: commits (save, complete, delete)
/// - edge: scroll-boundary "thock", fired by [BoundaryHaptics]
abstract final class PremiumHaptics {
  static void tap() => HapticFeedback.lightImpact();
  static void select() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.mediumImpact();
  static void edge() => HapticFeedback.mediumImpact();
}

/// Fires one [PremiumHaptics.edge] thock per scroll gesture that hits a
/// boundary (top/bottom overscroll, first/last pager page, sheet drag
/// limits). Mounted once around the whole app so every scrollable —
/// dashboard, calendar, notes, sheets — gets it with zero per-screen code.
///
/// One thock per gesture: re-armed on [ScrollStartNotification], plus a
/// 500ms floor so ballistic flings can't machine-gun the motor.
class BoundaryHaptics extends StatefulWidget {
  const BoundaryHaptics({super.key, required this.child});
  final Widget child;

  @override
  State<BoundaryHaptics> createState() => _BoundaryHapticsState();
}

class _BoundaryHapticsState extends State<BoundaryHaptics> {
  bool _armed = true;
  int _lastMs = 0;

  bool _handle(ScrollNotification n) {
    if (n is ScrollStartNotification) {
      _armed = true;
      return false;
    }
    if (n is OverscrollNotification && n.overscroll != 0 && _armed) {
      _armed = false;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastMs > 500) {
        _lastMs = now;
        PremiumHaptics.edge();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handle,
      child: widget.child,
    );
  }
}
