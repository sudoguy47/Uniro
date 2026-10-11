import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/greetings.dart';
import '../models/task.dart';

class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance => _instance ??= NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const String channelId = 'campus_tracker_reminders';
  static const String channelName = 'Task Reminders';
  static const String channelDescription =
      'Notifications and scheduled reminders for campus tasks, classes, and exams';

  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    try {
      tz.initializeTimeZones();
      // Set to local location if available
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      // Find or set timezone based on local offset
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(loc);
          break;
        }
      }
    } catch (e) {
      debugPrint('Timezone init notice: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked: payload=${response.payload}');
      },
    );

    // Create the notification channel. Permissions are NEVER requested here —
    // init runs on every cold start and a surprise system dialog on top of
    // onboarding is both ugly and store-screenshot poison. Permission is
    // requested only from explicit user actions: the onboarding
    // "Enable Reminders" button and the Profile notifications toggle
    // (see requestPermissions).
    final androidImpl = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidImpl.createNotificationChannel(androidChannel);
    }

    _initialized = true;
  }

  /// Requests notification and exact alarm permissions (Android 13+ & iOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    // TEMP-DIAG: find who calls this at startup. Remove after diagnosis.
    debugPrint('DIAG requestPermissions called\n${StackTrace.current}');
    try {
      if (!_initialized) await init();
      final androidImpl = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final notifGranted =
            await androidImpl.requestNotificationsPermission() ?? false;
        await androidImpl.requestExactAlarmsPermission();
        return notifGranted;
      }
      return true;
    } catch (e) {
      debugPrint('requestPermissions notice: $e');
      return false;
    }
  }

  /// Calculates a stable integer ID for notifications
  int _makeNotificationId(String taskId, [String? suffix]) {
    final raw = suffix != null ? '$taskId:$suffix' : taskId;
    return raw.hashCode.abs() % 2147483647;
  }

  /// Schedules notifications for a task based on due date/time and reminders.
  Future<void> scheduleForTask(Task task) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    if (task.status == TaskStatus.completed) {
      await cancelForTask(task);
      return;
    }

    try {
      // Parse base dueDate
      final dateParts = task.dueDate.split('-');
      if (dateParts.length < 3) return;
      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final day = int.parse(dateParts[2]);

      int hour = 9;
      int minute = 0;
      if (task.hasTime && task.dueTime != null && task.dueTime!.contains(':')) {
        final timeParts = task.dueTime!.split(':');
        hour = int.tryParse(timeParts[0]) ?? 9;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }

      final dueDateTime = DateTime(year, month, day, hour, minute);

      const notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          sound: 'default',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final typeLabel = task.type.name.toUpperCase();
      final title = '[$typeLabel] ${task.title}';
      final timeFormatted =
          task.hasTime && task.dueTime != null ? ' at ${task.dueTime}' : '';
      final body = 'Due on ${task.dueDate}$timeFormatted';

      // 1. If explicit reminders exist, schedule each reminder
      if (task.reminders.isNotEmpty) {
        for (final reminder in task.reminders) {
          DateTime triggerDate;
          switch (reminder.type) {
            case ReminderType.atTime:
              triggerDate = dueDateTime;
              break;
            case ReminderType.oneHour:
              triggerDate = dueDateTime.subtract(const Duration(hours: 1));
              break;
            case ReminderType.oneDay:
              triggerDate = dueDateTime.subtract(const Duration(days: 1));
              break;
            case ReminderType.threeDays:
              triggerDate = dueDateTime.subtract(const Duration(days: 3));
              break;
            case ReminderType.oneWeek:
              triggerDate = dueDateTime.subtract(const Duration(days: 7));
              break;
            case ReminderType.custom:
              final days = reminder.customDays ?? 1;
              triggerDate = dueDateTime.subtract(Duration(days: days));
              break;
          }

          if (triggerDate.isAfter(DateTime.now())) {
            final id = _makeNotificationId(task.id, reminder.id);
            reminder.notificationId = id.toString();
            final tzTrigger = tz.TZDateTime.from(triggerDate, tz.local);

            await _notifications.zonedSchedule(
              id,
              title,
              '$body (${reminder.type.name})',
              tzTrigger,
              notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: task.id,
            );
          }
        }
      } else {
        // 2. Default reminder: schedule at due date/time if in future
        if (dueDateTime.isAfter(DateTime.now())) {
          final id = _makeNotificationId(task.id);
          final tzTrigger = tz.TZDateTime.from(dueDateTime, tz.local);

          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzTrigger,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );
        }
      }
    } catch (e) {
      debugPrint('scheduleForTask error: $e');
    }
  }

  /// Cancels all scheduled notifications for a task.
  Future<void> cancelForTask(Task task) async {
    if (kIsWeb || !_initialized) return;
    try {
      // Cancel main task ID
      await _notifications.cancel(_makeNotificationId(task.id));
      // Cancel any reminder IDs
      for (final reminder in task.reminders) {
        await _notifications.cancel(_makeNotificationId(task.id, reminder.id));
        if (reminder.notificationId != null) {
          final id = int.tryParse(reminder.notificationId!);
          if (id != null) {
            await _notifications.cancel(id);
          }
        }
      }
    } catch (e) {
      debugPrint('cancelForTask error: $e');
    }
  }

  /// Re-syncs all notifications for active pending tasks.
  Future<void> rescheduleAll(List<Task> tasks) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await cancelAll();
    for (final task in tasks) {
      if (task.status == TaskStatus.pending) {
        await scheduleForTask(task);
      }
    }
  }

  /// Cancels all notifications.
  Future<void> cancelAll() async {
    if (kIsWeb || !_initialized) return;
    await _notifications.cancelAll();
  }

  /// Daily 6:00 AM greeting + life motivation. Uses a stable id so every
  /// re-schedule overwrites the previous one instead of stacking. Repeats
  /// daily via [DateTimeComponents.time]; re-armed on every app start
  /// (covers reboots) and whenever the name / toggle changes.
  Future<void> scheduleDailyGreeting({
    required String name,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    const id = 900001;
    try {
      if (!enabled) {
        await _notifications.cancel(id);
        return;
      }
      final now = DateTime.now();
      var next = DateTime(now.year, now.month, now.day, 6, 0);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notifications.zonedSchedule(
        id,
        'Rise and shine, $name! \u2600\uFE0F',
        lifeQuoteOfTheDay(now),
        tz.TZDateTime.from(next, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_greeting',
      );
    } catch (e) {
      debugPrint('scheduleDailyGreeting notice: $e');
    }
  }

  /// Shows an instant notification immediately (useful for testing & confirmation).
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
