import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';
import '../domain/attendance_logic.dart';
import '../features/notifications/notification_channels.dart';
import '../features/notifications/notification_permissions.dart';
import '../features/notifications/notification_scheduler.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../models/task.dart';
import 'device_channel.dart';
import 'local_store.dart';

/// Top-level background entry point for attendance action taps while the
/// app is backgrounded or terminated. Runs in a fresh background isolate:
/// it can only touch persisted storage (SharedPreferences via LocalStore),
/// never UI/state. Must stay top-level and @pragma('vm:entry-point').
@pragma('vm:entry-point')
void attendanceNotificationBackgroundHandler(NotificationResponse response) {
  try {
    final parsed = parseAttendancePayload(response.payload);
    if (parsed == null) return;
    // The background isolate gets a fresh LocalStore shell; init() is
    // required before load/save.
    LocalStore.instance.init().then((_) {
      recordAttendanceFromNotification(
        slotId: parsed.slotId,
        date: parsed.date,
        actionId: response.actionId,
      );
    }).catchError((_) {});
  } catch (_) {
    // Never let a background handler crash the isolate.
  }
}

/// Facade and coordinator service for local notifications.
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();
  NotificationService._() {
    _scheduler = NotificationScheduler(_notifications);
  }

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  late final NotificationScheduler _scheduler;
  bool _initialized = false;

  /// Bound by the app (main.dart) so a foreground attendance tap triggers
  /// an immediate state refresh + RAM update. Optional; null-safe.
  static void Function(String slotId, String date, String? actionId)?
      _attendanceActionListener;

  static set attendanceActionListener(
      void Function(String slotId, String date, String? actionId)? listener) {
    _attendanceActionListener = listener;
  }

  static const String channelId = NotificationChannels.channelId;
  static const String channelName = NotificationChannels.channelName;
  static const String channelDescription =
      NotificationChannels.channelDescription;

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    await resolveLocalTimezone();

    final initSettings = NotificationChannels.createInitializationSettings();

    try {
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final parsed = parseAttendancePayload(response.payload);
          if (parsed != null) {
            // Foreground/tap-while-running path: record synchronously through
            // the shared raw-store helper, then let the app (if any widget is
            // listening) pull the fresh records. Never throws.
            recordAttendanceFromNotification(
              slotId: parsed.slotId,
              date: parsed.date,
              actionId: response.actionId,
            );
            // Give any live state a chance to reload from disk.
            _attendanceActionListener?.call(
                parsed.slotId, parsed.date, response.actionId);
            return;
          }
          AppLog.d('Notification clicked: payload=${response.payload}');
        },
        onDidReceiveBackgroundNotificationResponse:
            attendanceNotificationBackgroundHandler,
      );

      // Create the notification channel. Permissions are NEVER requested here.
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        await androidImpl
            .createNotificationChannel(NotificationChannels.defaultAndroidChannel);
      }
    } catch (e) {
      AppLog.w('NotificationService initialize notice', e);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_id_v2_migrated') != true) {
        await _notifications.cancelAll();
      }
    } catch (e) {
      AppLog.w('notif_id_v2 migration notice in init', e);
    }

    _initialized = true;
  }

  Future<void> resolveLocalTimezone() =>
      NotificationPermissions.resolveLocalTimezone();

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();
    return NotificationPermissions.requestPermissions(_notifications);
  }

  Future<void> scheduleForTask(Task task) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.scheduleForTask(task);
  }

  Future<void> cancelForTask(Task task) async {
    if (kIsWeb || !_initialized) return;
    return _scheduler.cancelForTask(task);
  }

  Future<void> rearmAll({
    required List<Task> tasks,
    required List<Course> courses,
    required List<ClassSlot> slots,
    required String name,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_id_v2_migrated') != true) {
        await cancelAll();
        await prefs.setBool('notif_id_v2_migrated', true);
      }
    } catch (_) {}
    await rescheduleAll(tasks);
    await scheduleDailyGreeting(
        name: name, enabled: enabled, tasks: tasks, slots: slots);
    await refreshClassReminders(
        courses: courses, slots: slots, enabled: enabled);
    await refreshAttendancePrompts(
        courses: courses, slots: slots, enabled: enabled);
  }

  Future<bool> checkAndRescheduleIfNeeded({
    required List<Task> tasks,
    required List<Course> courses,
    required List<ClassSlot> slots,
    required String name,
    required bool enabled,
  }) async {
    if (kIsWeb) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('notif_id_v2_migrated') ?? false;
      if (!migrated) {
        _initialized = false;
        await init();
        await cancelAll();
        await rearmAll(
          tasks: tasks,
          courses: courses,
          slots: slots,
          name: name,
          enabled: enabled,
        );
        await prefs.setBool('notif_id_v2_migrated', true);
        await DeviceChannel.clearNeedsReschedule();
        return true;
      }

      final flag = await DeviceChannel.getNeedsReschedule();
      final currentId = await DeviceChannel.getTimeZoneId();
      final stored = LocalStore.instance.load('tz_id') as String?;
      final tzChanged =
          currentId != null && stored != null && currentId != stored;
      if (!flag && !tzChanged) {
        if (currentId != null && stored == null) {
          LocalStore.instance.save('tz_id', currentId);
        }
        return false;
      }
      _initialized = false;
      await init();
      await rearmAll(
        tasks: tasks,
        courses: courses,
        slots: slots,
        name: name,
        enabled: enabled,
      );
      await DeviceChannel.clearNeedsReschedule();
      if (currentId != null) LocalStore.instance.save('tz_id', currentId);
      return true;
    } catch (e) {
      AppLog.w('checkAndReschedule notice', e);
      return false;
    }
  }

  Future<void> rescheduleAll(List<Task> tasks) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.rescheduleAll(tasks);
  }

  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    try {
      await _notifications.cancelAll();
    } catch (e) {
      AppLog.w('cancelAll notice', e);
    }
  }

  Future<void> scheduleDailyGreeting({
    required String name,
    required bool enabled,
    List<Task> tasks = const [],
    List<ClassSlot> slots = const [],
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.scheduleDailyGreeting(
      name: name,
      enabled: enabled,
      tasks: tasks,
      slots: slots,
    );
  }

  Future<void> refreshClassReminders({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.refreshClassReminders(
      courses: courses,
      slots: slots,
      enabled: enabled,
    );
  }

  Future<void> cancelClassRemindersForSlot(String slotId) async {
    if (kIsWeb || !_initialized) return;
    return _scheduler.cancelClassRemindersForSlot(slotId);
  }

  Future<void> refreshAttendancePrompts({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.refreshAttendancePrompts(
      courses: courses,
      slots: slots,
      enabled: enabled,
    );
  }

  Future<void> cancelAttendancePromptsForSlot(String slotId) async {
    if (kIsWeb || !_initialized) return;
    return _scheduler.cancelAttendancePromptsForSlot(slotId);
  }

  Future<void> cancelAttendancePromptFor(String slotId, String date) async {
    if (kIsWeb || !_initialized) return;
    return _scheduler.cancelAttendancePromptFor(slotId, date);
  }

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    return _scheduler.showInstantNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<bool> scheduleTestReminder() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();
    return _scheduler.scheduleTestReminder();
  }
}
