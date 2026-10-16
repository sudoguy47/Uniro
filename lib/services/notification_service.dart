import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../domain/quotes.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../models/task.dart';
import 'device_channel.dart';
import 'local_store.dart';

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

    await resolveLocalTimezone();

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

  /// Resolves tz.local from the OS zone id via the device channel.
  /// Order: exact IANA id -> legacy offset match -> UTC. Never throws.
  /// The winning id is saved to LocalStore ('tz_id') so
  /// [checkAndRescheduleIfNeeded] can detect zone changes.
  Future<void> resolveLocalTimezone() async {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('Timezone db notice: $e');
      return;
    }
    // 1. Exact id from Kotlin (TimeZone.getDefault().id).
    try {
      final id = await DeviceChannel.getTimeZoneId();
      if (id != null && id.isNotEmpty) {
        try {
          String normalizedId = id;
          if (id.startsWith('GMT+') || id.startsWith('GMT-') || id.startsWith('UTC+') || id.startsWith('UTC-')) {
            final match = RegExp(r'(?:GMT|UTC)([+-])(\d{1,2}):?(\d{2})?').firstMatch(id);
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
          debugPrint('Timezone id "$id" unknown, trying offset match');
        }
      }
    } catch (e) {
      debugPrint('Timezone id notice: $e');
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
      debugPrint('Timezone offset notice: $e');
    }
    // 3. Last resort: UTC keeps absoluteTime scheduling working.
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
      LocalStore.instance.save('tz_id', 'UTC');
    } catch (e) {
      debugPrint('Timezone UTC notice: $e');
    }
  }

  /// Requests notification and exact alarm permissions (Android 13+ & iOS).
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
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

  /// Exact alarms need a runtime grant on Android 12+. When denied,
  /// exact scheduling throws — so fall back to inexact (still delivered,
  /// possibly minutes late) instead of losing the notification entirely.
  /// This is the most common reason scheduled notifications never arrive.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (kIsWeb) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final canExact =
          await androidImpl?.canScheduleExactNotifications() ?? false;
      if (canExact) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (e) {
      debugPrint('scheduleMode notice: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
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
            case ReminderType.twoDays:
              triggerDate = dueDateTime.subtract(const Duration(days: 2));
              break;
            case ReminderType.threeDays:
              triggerDate = dueDateTime.subtract(const Duration(days: 3));
              break;
            case ReminderType.sevenDays:
              triggerDate = dueDateTime.subtract(const Duration(days: 7));
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
              androidScheduleMode: await _scheduleMode(),
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
            androidScheduleMode: await _scheduleMode(),
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

  /// Re-arms everything after a permission grant or settings change:
  /// task reminders, the daily greeting, and class reminders.
  /// NOTE: this runs in Dart on launch / resume. Reboot coverage comes
  /// from the plugin's ScheduledNotificationBootReceiver declared in
  /// AndroidManifest.xml (the OS re-fires persisted notifications after
  /// BOOT_COMPLETED / MY_PACKAGE_REPLACED); this method then rebuilds the
  /// full schedule on the next app start.
  Future<void> rearmAll({
    required List<Task> tasks,
    required List<Course> courses,
    required List<ClassSlot> slots,
    required String name,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await rescheduleAll(tasks);
    await scheduleDailyGreeting(
        name: name, enabled: enabled, tasks: tasks, slots: slots);
    await refreshClassReminders(
        courses: courses, slots: slots, enabled: enabled);
  }

  /// Rebuilds tz.local and reschedules everything when the native
  /// time-change flag is set (TimeChangeReceiver saw TIMEZONE_CHANGED /
  /// TIME_SET / DATE_CHANGED) or when the system zone id differs from the
  /// last known one. Called on app launch and on AppLifecycleState.resumed.
  /// Returns true when a refresh + reschedule ran. Never throws.
  Future<bool> checkAndRescheduleIfNeeded({
    required List<Task> tasks,
    required List<Course> courses,
    required List<ClassSlot> slots,
    required String name,
    required bool enabled,
  }) async {
    if (kIsWeb) return false;
    try {
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
      // Force tz.local to rebuild, then rebuild the whole schedule.
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
      debugPrint('checkAndReschedule notice: $e');
      return false;
    }
  }

  /// Re-syncs all notifications for active pending tasks.
  Future<void> rescheduleAll(List<Task> tasks) async {
    if (kIsWeb) return;
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
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('cancelAll notice: $e');
    }
  }

  /// Daily 6:00 AM greeting: schedules distinct daily notifications for the
  /// next 7 days (IDs 900001 to 900007). Each day gets its own quote, class
  /// count, and task count for that specific date.
  /// Scheduling 7 days ahead guarantees delivery every morning even if the
  /// app is closed or the device enters Doze Mode overnight.
  static const int _greetingIdStart = 900001;
  static const int _greetingDaysCount = 7;

  Future<void> scheduleDailyGreeting({
    required String name,
    required bool enabled,
    List<Task> tasks = const [],
    List<ClassSlot> slots = const [],
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    try {
      // Cancel existing potential daily greeting notification IDs (900001 - 900014)
      for (var i = 0; i < 14; i++) {
        try {
          await _notifications.cancel(_greetingIdStart + i);
        } catch (_) {}
      }
      if (!enabled) return;

      final now = DateTime.now();
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

      final scheduleMode = await _scheduleMode();

      for (var dayOffset = 0; dayOffset < _greetingDaysCount; dayOffset++) {
        final date = DateTime(now.year, now.month, now.day)
            .add(Duration(days: dayOffset));
        final targetDateTime =
            DateTime(date.year, date.month, date.day, 6, 0);

        // Skip if 6:00 AM for today has already passed
        if (!targetDateTime.isAfter(now)) continue;

        final todayStr = _ymd(targetDateTime);
        final classCount =
            slots.where((s) => s.weekday == targetDateTime.weekday).length;
        final taskCount = tasks
            .where((t) =>
                t.status == TaskStatus.pending && t.dueDate == todayStr)
            .length;
        final body =
            '${quoteOfTheDay(targetDateTime)}\n${todayAgendaLine(classCount: classCount, taskCount: taskCount)}';

        final id = _greetingIdStart + dayOffset;
        await _notifications.zonedSchedule(
          id,
          'Rise and shine, $name! \u2600\uFE0F',
          body,
          tz.TZDateTime.from(targetDateTime, tz.local),
          details,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'daily_greeting',
        );
      }
    } catch (e) {
      debugPrint('scheduleDailyGreeting notice: $e');
    }
  }

  // Class reminders (Routine tab). Own id range 500000-599999 so ids never
  // collide with task hashes. One notification per slot occurrence for the
  // next 14 days (no infinite weekly repeats). Map "slotId|yyyy-MM-dd" to
  // notification id is persisted so rebuilds cancel precisely.
  static const int _classIdStart = 500000;
  static const int _classIdEnd = 599999;
  static const int _classWindowDays = 14;

  Map<String, int> _classNotifMap() {
    try {
      final raw = LocalStore.instance.load('class_notif_map');
      if (raw is! Map) return {};
      final out = <String, int>{};
      raw.forEach((k, v) {
        try {
          if (v is num) out[k.toString()] = v.toInt();
        } catch (_) {
          LocalStore.instance.markRecovery();
        }
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  int _nextClassNotifId() {
    final raw = LocalStore.instance.load('class_notif_next');
    var next = raw is num ? raw.toInt() : _classIdStart;
    if (next < _classIdStart || next > _classIdEnd) next = _classIdStart;
    LocalStore.instance.save('class_notif_next', next + 1);
    return next;
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _compact12(int mins) {
    final h24 = mins ~/ 60;
    final m = (mins % 60).toString().padLeft(2, '0');
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m ${h24 >= 12 ? 'PM' : 'AM'}';
  }

  NotificationDetails _taskLikeDetails() => const NotificationDetails(
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

  /// Full rebuild: cancels every mapped class reminder, then schedules the
  /// next 14 occurrences of each slot with a reminder. Call after any class
  /// or course change and on app launch (the window is recomputed from
  /// "now", which is what makes timezone changes take effect once
  /// [checkAndRescheduleIfNeeded] has rebuilt tz.local).
  Future<void> refreshClassReminders({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    try {
      final oldMap = _classNotifMap();
      for (final id in oldMap.values) {
        try {
          await _notifications.cancel(id);
        } catch (_) {}
      }
      final map = <String, int>{};
      if (enabled) {
        final byCourse = {for (final c in courses) c.id: c};
        final now = DateTime.now();
        for (final slot in slots) {
          final reminder = slot.reminderMinutesBefore;
          if (reminder == null) continue;
          final course = byCourse[slot.courseId];
          final code = course?.code ?? '';
          final label = code.trim().isNotEmpty
              ? code.trim()
              : (course?.name ?? 'Class');
          for (var d = 0; d < _classWindowDays; d++) {
            final date = DateTime(now.year, now.month, now.day)
                .add(Duration(days: d));
            if (date.weekday != slot.weekday) continue;
            final start =
                date.add(Duration(minutes: slot.startMinutes));
            final fire = start.subtract(Duration(minutes: reminder));
            if (!fire.isAfter(now)) continue;
            final key = '${slot.id}|${_ymd(date)}';
            try {
              final id = _nextClassNotifId();
              final room = (slot.room ?? '').trim();
              await _notifications.zonedSchedule(
                id,
                '$label in $reminder min',
                '${course?.name ?? label} | ${_compact12(slot.startMinutes)}-${_compact12(slot.endMinutes)}${room.isNotEmpty ? ' | $room' : ''}',
                tz.TZDateTime.from(fire, tz.local),
                _taskLikeDetails(),
                androidScheduleMode: await _scheduleMode(),
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: 'class|${slot.id}|${_ymd(date)}',
              );
              map[key] = id;
            } catch (e) {
              debugPrint('class reminder schedule notice: $e');
            }
          }
        }
      }
      LocalStore.instance.save('class_notif_map', map);
    } catch (e) {
      debugPrint('refreshClassReminders notice: $e');
    }
  }

  /// Cancels every mapped reminder for one slot (edit/delete paths).
  Future<void> cancelClassRemindersForSlot(String slotId) async {
    if (kIsWeb || !_initialized) return;
    final map = _classNotifMap();
    final doomed =
        map.entries.where((e) => e.key.startsWith('$slotId|')).toList();
    for (final e in doomed) {
      try {
        await _notifications.cancel(e.value);
      } catch (_) {}
      map.remove(e.key);
    }
    LocalStore.instance.save('class_notif_map', map);
  }

  /// Shows an instant notification immediately (useful for testing & confirmation).
  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
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
    } catch (e) {
      debugPrint('showInstantNotification notice: $e');
    }
  }

  /// Schedules a real notification ~1 minute out so users can verify
  /// delivery with the screen off. Uses the same exact-or-inexact path as
  /// real reminders. Returns true when scheduled. Never throws.
  Future<bool> scheduleTestReminder() async {
    if (kIsWeb) return false;
    try {
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
      final fire = DateTime.now().add(const Duration(minutes: 1));
      await _notifications.zonedSchedule(
        900002,
        'Test reminder',
        'If you see this, reminders work on your phone.',
        tz.TZDateTime.from(fire, tz.local),
        details,
        androidScheduleMode: await _scheduleMode(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_reminder',
      );
      return true;
    } catch (e) {
      debugPrint('scheduleTestReminder notice: $e');
      return false;
    }
  }
}
