import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../core/logger.dart';
import '../../services/device_channel.dart';
import '../../services/local_store.dart';

/// Timezone resolution, runtime permissions, and Android schedule modes.
class NotificationPermissions {
  NotificationPermissions._();

  /// Resolves tz.local from the OS zone id via the device channel.
  /// Order: exact IANA id -> legacy offset match -> UTC. Never throws.
  /// The winning id is saved to LocalStore ('tz_id') so
  /// [checkAndRescheduleIfNeeded] can detect zone changes.
  static Future<void> resolveLocalTimezone() async {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      AppLog.w('Timezone db notice', e);
      return;
    }
    // 1. Exact id from Kotlin (TimeZone.getDefault().id).
    try {
      final id = await DeviceChannel.getTimeZoneId();
      if (id != null && id.isNotEmpty) {
        try {
          String normalizedId = id;
          if (id.startsWith('GMT+') ||
              id.startsWith('GMT-') ||
              id.startsWith('UTC+') ||
              id.startsWith('UTC-')) {
            final match =
                RegExp(r'(?:GMT|UTC)([+-])(\d{1,2}):?(\d{2})?').firstMatch(id);
            if (match != null) {
              final sign = match.group(1);
              final hours = int.tryParse(match.group(2) ?? '0') ?? 0;
              final etcSign = sign == '+' ? '-' : '+';
              normalizedId = 'Etc/GMT$etcSign$hours';
            }
          }
          tz.setLocalLocation(tz.getLocation(normalizedId));
          LocalStore.instance.save('tz_id', normalizedId);
          return;
        } catch (_) {
          // Unknown to the tz database: fall through to offset match.
          AppLog.d('Timezone id "$id" unknown, trying offset match');
        }
      }
    } catch (e) {
      AppLog.w('Timezone id notice', e);
    }
    // 2. Legacy offset match (prioritize active population regions)
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      tz.Location? bestMatch;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          bestMatch ??= loc;
          if (loc.name.startsWith('Asia/') ||
              loc.name.startsWith('America/') ||
              loc.name.startsWith('Europe/') ||
              loc.name.startsWith('Africa/') ||
              loc.name.startsWith('Australia/')) {
            bestMatch = loc;
            break;
          }
        }
      }
      if (bestMatch != null) {
        tz.setLocalLocation(bestMatch);
        LocalStore.instance.save('tz_id', bestMatch.name);
        return;
      }
    } catch (e) {
      AppLog.w('Timezone offset notice', e);
    }
    // 3. Last resort: UTC keeps absoluteTime scheduling working.
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
      LocalStore.instance.save('tz_id', 'UTC');
    } catch (e) {
      AppLog.w('Timezone UTC notice', e);
    }
  }

  /// Requests notification and exact alarm permissions (Android 13+ & iOS).
  static Future<bool> requestPermissions(
      FlutterLocalNotificationsPlugin plugin) async {
    if (kIsWeb) return false;
    try {
      final androidImpl = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final notifGranted =
            await androidImpl.requestNotificationsPermission() ?? false;
        await androidImpl.requestExactAlarmsPermission();
        return notifGranted;
      }
      return true;
    } catch (e) {
      AppLog.w('requestPermissions notice', e);
      return false;
    }
  }

  /// Exact alarms need a runtime grant on Android 12+. When denied,
  /// exact scheduling throws — so fall back to inexact (still delivered,
  /// possibly minutes late) instead of losing the notification entirely.
  /// This is the most common reason scheduled notifications never arrive.
  static Future<AndroidScheduleMode> getScheduleMode(
      FlutterLocalNotificationsPlugin plugin) async {
    if (kIsWeb) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final androidImpl = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await androidImpl?.canScheduleExactNotifications() ?? false;
      if (canExact) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (e) {
      AppLog.w('scheduleMode notice', e);
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
