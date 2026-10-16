import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_channel.dart';

/// App-wide premium haptic language.
///
/// - tap: standard controls (buttons, cards, rows)
/// - select: low-weight toggles (tabs, chips, switches, steppers)
/// - confirm: commits (save, complete, delete)
/// - edge: scroll-boundary "thock", fired by [BoundaryHaptics]
///
/// Every entry point is gated on [HapticsCapabilities.available], so a
/// device without a vibrator or with system touch feedback disabled stays
/// silent instead of wasting Binder calls and battery. All UI haptics go
/// through Flutter's system path (no direct Vibrator use), which keeps
/// OEM intensity curves and user settings intact.
abstract final class PremiumHaptics {
  static void tap() {
    if (HapticsCapabilities.available) HapticFeedback.lightImpact();
  }

  static void select() {
    if (!HapticsCapabilities.available) return;
    // Some HALs (observed on Realme/ColorOS) silently drop the predefined
    // tick behind selectionClick; those devices get a light tap instead so
    // the press is still felt. Capable devices keep the designed feel.
    if (HapticsCapabilities.selectionTickSupported) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  static void confirm() {
    if (HapticsCapabilities.available) HapticFeedback.mediumImpact();
  }

  static void edge() {
    if (HapticsCapabilities.available) HapticFeedback.mediumImpact();
  }
}

/// Cached haptic capability. Defaults assume a capable device (preserves
/// current behavior when the platform state is still unknown); [refresh]
/// corrects the cache from the native side. Never throws.
class HapticsCapabilities {
  static bool _hasVibrator = true;
  static bool _touchEnabled = true;
  static bool _selectionTickSupported = true;

  static bool get hasVibrator => _hasVibrator;
  static bool get touchEnabled => _touchEnabled;
  static bool get selectionTickSupported => _selectionTickSupported;
  static bool get available => _hasVibrator && _touchEnabled;

  @visibleForTesting
  static void debugSet(
      {bool? hasVibrator,
      bool? touchEnabled,
      bool? selectionTickSupported}) {
    if (hasVibrator != null) _hasVibrator = hasVibrator;
    if (touchEnabled != null) _touchEnabled = touchEnabled;
    if (selectionTickSupported != null) {
      _selectionTickSupported = selectionTickSupported;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _hasVibrator = true;
    _touchEnabled = true;
    _selectionTickSupported = true;
  }

  /// Queries the device channel once and caches the result. Unknown
  /// (null) answers leave the previous value in place. Never throws.
  static Future<void> refresh() async {
    try {
      final h = await DeviceChannel.hasVibrator();
      if (h != null) _hasVibrator = h;
    } catch (_) {}
    try {
      final t = await DeviceChannel.isTouchHapticsEnabled();
      if (t != null) _touchEnabled = t;
    } catch (_) {}
    try {
      final s = await DeviceChannel.supportsSelectionTick();
      if (s != null) _selectionTickSupported = s;
    } catch (_) {}
  }
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

  /// Pure throttle decision, extracted for unit tests.
  /// [armed] is the per-gesture latch, [nowMs]/[lastMs] are epoch millis.
  static bool shouldThock({
    required bool armed,
    required int nowMs,
    required int lastMs,
    int floorMs = 500,
  }) {
    if (!armed) return false;
    return nowMs - lastMs > floorMs;
  }

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
      if (BoundaryHaptics.shouldThock(
          armed: true, nowMs: now, lastMs: _lastMs)) {
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
