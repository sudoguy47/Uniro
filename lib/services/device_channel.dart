import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around the app's own `dev.sudoguy.uniro/device`
/// MethodChannel (see MainActivity.kt). Every call is guarded and returns
/// a safe default so a platform failure never crashes the app.
class DeviceChannel {
  static const _channel = MethodChannel('dev.sudoguy.uniro/device');

  /// IANA id from `TimeZone.getDefault().id`, e.g. "Asia/Dhaka".
  static Future<String?> getTimeZoneId() async {
    try {
      final v = await _channel.invokeMethod<String>('getTimeZoneId');
      if (v != null && v.isNotEmpty) return v;
      return null;
    } on PlatformException catch (e) {
      debugPrint('device getTimeZoneId notice: $e');
      return null;
    } on MissingPluginException catch (e) {
      debugPrint('device getTimeZoneId missing plugin: $e');
      return null;
    } catch (e) {
      debugPrint('device getTimeZoneId notice: $e');
      return null;
    }
  }

  /// Flag written by the native TimeChangeReceiver on
  /// TIMEZONE_CHANGED / TIME_SET / DATE_CHANGED.
  static Future<bool> getNeedsReschedule() async {
    try {
      final v = await _channel.invokeMethod<bool>('getNeedsReschedule');
      return v ?? false;
    } on PlatformException catch (e) {
      debugPrint('device getNeedsReschedule notice: $e');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('device getNeedsReschedule missing plugin: $e');
      return false;
    } catch (e) {
      debugPrint('device getNeedsReschedule notice: $e');
      return false;
    }
  }

  static Future<void> clearNeedsReschedule() async {
    try {
      await _channel.invokeMethod('clearNeedsReschedule');
    } on PlatformException catch (e) {
      debugPrint('device clearNeedsReschedule notice: $e');
    } on MissingPluginException catch (e) {
      debugPrint('device clearNeedsReschedule missing plugin: $e');
    } catch (e) {
      debugPrint('device clearNeedsReschedule notice: $e');
    }
  }

  /// {apiLevel: int, manufacturer: String, model: String}, or null.
  static Future<Map<String, dynamic>?> getDeviceInfo() async {
    try {
      final v =
          await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
      return v == null ? null : Map<String, dynamic>.from(v);
    } catch (e) {
      debugPrint('device getDeviceInfo notice: $e');
      return null;
    }
  }

  /// Null when the state cannot be determined.
  static Future<bool?> areNotificationsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('areNotificationsEnabled');
    } catch (e) {
      debugPrint('device areNotificationsEnabled notice: $e');
      return null;
    }
  }

  /// Null when the state cannot be determined. True on API < 31.
  static Future<bool?> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms');
    } catch (e) {
      debugPrint('device canScheduleExactAlarms notice: $e');
      return null;
    }
  }

  /// Null when the state cannot be determined.
  static Future<bool?> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
    } catch (e) {
      debugPrint('device battery notice: $e');
      return null;
    }
  }

  /// Opens the system battery-optimization list (falls back to app details).
  static Future<bool> openBatteryOptimizationSettings() async {
    try {
      final v = await _channel
          .invokeMethod<bool>('openBatteryOptimizationSettings');
      return v ?? false;
    } catch (e) {
      debugPrint('device openBattery notice: $e');
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      final v = await _channel.invokeMethod<bool>('openAppSettings');
      return v ?? false;
    } catch (e) {
      debugPrint('device openAppSettings notice: $e');
      return false;
    }
  }

  /// Null when the state cannot be determined (e.g. non-Android platform).
  static Future<bool?> hasVibrator() async {
    try {
      return await _channel.invokeMethod<bool>('hasVibrator');
    } catch (e) {
      debugPrint('device hasVibrator notice: $e');
      return null;
    }
  }

  /// System "Touch feedback" toggle. Null when it cannot be determined.
  static Future<bool?> isTouchHapticsEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isTouchHapticsEnabled');
    } catch (e) {
      debugPrint('device touchHaptics notice: $e');
      return null;
    }
  }

  /// Whether the motor supports the predefined tick behind selection
  /// clicks. Null when it cannot be determined (fail-open: callers keep
  /// the designed feel).
  static Future<bool?> supportsSelectionTick() async {
    try {
      return await _channel.invokeMethod<bool>('supportsSelectionTick');
    } catch (e) {
      debugPrint('device selectionTick notice: $e');
      return null;
    }
  }

  /// Photo/gallery permission state: 'granted', 'denied',
  /// 'permanentlyDenied' or 'unknown'. Never throws.
  static Future<String> getStoragePermissionStatus() async {
    try {
      final v =
          await _channel.invokeMethod<String>('getStoragePermissionStatus');
      return v ?? 'unknown';
    } catch (e) {
      debugPrint('device storageStatus notice: $e');
      return 'unknown';
    }
  }

  /// Requests the API-appropriate gallery permission and returns the
  /// resulting state. Returns 'permanentlyDenied' when the system will
  /// no longer show the dialog (open app settings instead). Never throws.
  static Future<String> requestStoragePermission() async {
    try {
      final v =
          await _channel.invokeMethod<String>('requestStoragePermission');
      return v ?? 'unknown';
    } catch (e) {
      debugPrint('device storageRequest notice: $e');
      return 'unknown';
    }
  }
}
