import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/logger.dart';
import '../../domain/attendance_logic.dart';
import '../../domain/quotes.dart';
import '../../models/class_slot.dart';
import '../../models/course.dart';
import '../../models/task.dart';
import '../../services/local_store.dart';
import 'notification_channels.dart';
import 'notification_id_generator.dart';
import 'notification_permissions.dart';

/// Handles scheduling and cancelling of notifications for tasks, daily greetings,
/// class reminders, and attendance prompts.
class NotificationScheduler {
  final FlutterLocalNotificationsPlugin _notifications;

  NotificationScheduler(this._notifications);

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _compact12(int mins) {
    final h24 = mins ~/ 60;
    final m = (mins % 60).toString().padLeft(2, '0');
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m ${h24 >= 12 ? 'PM' : 'AM'}';
  }

  // ── Task Reminders ──────────────────────────────────────────────────────────

  /// Schedules notifications for a task based on due date/time and reminders.
  Future<void> scheduleForTask(Task task) async {
    if (kIsWeb) return;
    if (task.status == TaskStatus.completed) {
      await cancelForTask(task);
      return;
    }

    try {
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

      final typeLabel = (task.type == TaskType.custom &&
              task.customCategory != null &&
              task.customCategory!.trim().isNotEmpty)
          ? task.customCategory!.trim().toUpperCase()
          : (task.type == TaskType.ct ? 'CT' : task.type.name.toUpperCase());
      final title = '[$typeLabel] ${task.title}';
      final timeFormatted =
          task.hasTime && task.dueTime != null ? ' at ${task.dueTime}' : '';
      final body = 'Due on ${task.dueDate}$timeFormatted';

      final scheduleMode =
          await NotificationPermissions.getScheduleMode(_notifications);

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
            case ReminderType.oneWeek:
              triggerDate = dueDateTime.subtract(const Duration(days: 7));
              break;
            case ReminderType.custom:
              final days = reminder.customDays ?? 1;
              triggerDate = dueDateTime.subtract(Duration(days: days));
              break;
          }

          if (triggerDate.isAfter(DateTime.now())) {
            final id = NotificationIdGenerator.makeNotificationId(
                task.id, reminder.id);
            reminder.notificationId = id.toString();
            final tzTrigger = tz.TZDateTime.from(triggerDate, tz.local);

            await _notifications.zonedSchedule(
              id,
              title,
              '$body (${reminder.type.name})',
              tzTrigger,
              NotificationChannels.taskDetails,
              androidScheduleMode: scheduleMode,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: task.id,
            );
          }
        }
      } else {
        // 2. Default reminder: schedule at due date/time if in future
        if (dueDateTime.isAfter(DateTime.now())) {
          final id = NotificationIdGenerator.makeNotificationId(task.id);
          final tzTrigger = tz.TZDateTime.from(dueDateTime, tz.local);

          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzTrigger,
            NotificationChannels.taskDetails,
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );
        }
      }
    } catch (e) {
      AppLog.w('scheduleForTask error', e);
    }
  }

  /// Cancels all scheduled notifications for a task.
  Future<void> cancelForTask(Task task) async {
    if (kIsWeb) return;
    try {
      await _notifications
          .cancel(NotificationIdGenerator.makeNotificationId(task.id));
      for (final reminder in task.reminders) {
        await _notifications.cancel(
            NotificationIdGenerator.makeNotificationId(task.id, reminder.id));
        if (reminder.notificationId != null) {
          final id = int.tryParse(reminder.notificationId!);
          if (id != null) {
            await _notifications.cancel(id);
          }
        }
      }
    } catch (e) {
      AppLog.w('cancelForTask error', e);
    }
  }

  /// Re-syncs all notifications for active pending tasks.
  Future<void> rescheduleAll(List<Task> tasks) async {
    if (kIsWeb) return;
    await _notifications.cancelAll();
    for (final task in tasks) {
      if (task.status == TaskStatus.pending) {
        await scheduleForTask(task);
      }
    }
  }

  // ── Daily Greeting ──────────────────────────────────────────────────────────

  Future<void> scheduleDailyGreeting({
    required String name,
    required bool enabled,
    List<Task> tasks = const [],
    List<ClassSlot> slots = const [],
  }) async {
    if (kIsWeb) return;
    try {
      for (var i = 0; i < 14; i++) {
        try {
          await _notifications
              .cancel(NotificationIdGenerator.greetingIdStart + i);
        } catch (_) {}
      }
      if (!enabled) return;

      final now = DateTime.now();
      final scheduleMode =
          await NotificationPermissions.getScheduleMode(_notifications);

      for (var dayOffset = 0;
          dayOffset < NotificationIdGenerator.greetingDaysCount;
          dayOffset++) {
        final date = DateTime(now.year, now.month, now.day)
            .add(Duration(days: dayOffset));
        final targetDateTime =
            DateTime(date.year, date.month, date.day, 6, 0);

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

        final id = NotificationIdGenerator.greetingIdStart + dayOffset;
        await _notifications.zonedSchedule(
          id,
          'Rise and shine, $name! \u2600\uFE0F',
          body,
          tz.TZDateTime.from(targetDateTime, tz.local),
          NotificationChannels.greetingDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'daily_greeting',
        );
      }
    } catch (e) {
      AppLog.w('scheduleDailyGreeting notice', e);
    }
  }

  // ── Class Reminders ─────────────────────────────────────────────────────────

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

  Future<void> refreshClassReminders({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
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
        final scheduleMode =
            await NotificationPermissions.getScheduleMode(_notifications);

        for (final slot in slots) {
          final reminder = slot.reminderMinutesBefore;
          if (reminder == null) continue;
          final course = byCourse[slot.courseId];
          final code = course?.code ?? '';
          final label = code.trim().isNotEmpty
              ? code.trim()
              : (course?.name ?? 'Class');
          for (var d = 0; d < NotificationIdGenerator.classWindowDays; d++) {
            final date = DateTime(now.year, now.month, now.day)
                .add(Duration(days: d));
            if (date.weekday != slot.weekday) continue;
            final start = date.add(Duration(minutes: slot.startMinutes));
            final fire = start.subtract(Duration(minutes: reminder));
            if (!fire.isAfter(now)) continue;
            final key = '${slot.id}|${_ymd(date)}';
            try {
              final id = NotificationIdGenerator.nextClassNotifId();
              final room = (slot.room ?? '').trim();
              await _notifications.zonedSchedule(
                id,
                '$label in $reminder min',
                '${course?.name ?? label} | ${_compact12(slot.startMinutes)}-${_compact12(slot.endMinutes)}${room.isNotEmpty ? ' | $room' : ''}',
                tz.TZDateTime.from(fire, tz.local),
                NotificationChannels.taskDetails,
                androidScheduleMode: scheduleMode,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: 'class|${slot.id}|${_ymd(date)}',
              );
              map[key] = id;
            } catch (e) {
              AppLog.w('class reminder schedule notice', e);
            }
          }
        }
      }
      LocalStore.instance.save('class_notif_map', map);
    } catch (e) {
      AppLog.w('refreshClassReminders notice', e);
    }
  }

  Future<void> cancelClassRemindersForSlot(String slotId) async {
    if (kIsWeb) return;
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
    await cancelAttendancePromptsForSlot(slotId);
  }

  // ── Attendance Prompts ──────────────────────────────────────────────────────

  Map<String, int> _attendanceNotifMap() {
    try {
      final raw = LocalStore.instance.load('attendance_notif_map');
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

  Future<void> refreshAttendancePrompts({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    if (kIsWeb) return;
    try {
      final oldMap = _attendanceNotifMap();
      for (final id in oldMap.values) {
        try {
          await _notifications.cancel(id);
        } catch (_) {}
      }
      final map = <String, int>{};
      if (enabled) {
        final byCourse = {for (final c in courses) c.id: c};
        final recorded = readAttendanceRecordsRaw()
            .map((r) => r.occurrenceKey)
            .toSet();
        final now = DateTime.now();
        final scheduleMode =
            await NotificationPermissions.getScheduleMode(_notifications);

        for (final slot in slots) {
          final course = byCourse[slot.courseId];
          final code = course?.code ?? '';
          final label =
              code.trim().isNotEmpty ? code.trim() : (course?.name ?? 'Class');
          for (var d = 0; d < NotificationIdGenerator.attendanceWindowDays; d++) {
            final date = DateTime(now.year, now.month, now.day)
                .add(Duration(days: d));
            if (date.weekday != slot.weekday) continue;
            final end = date.add(Duration(minutes: slot.endMinutes));
            if (!end.isAfter(now)) continue;
            final key = '${slot.id}|${_ymd(date)}';
            if (recorded.contains(key)) continue;
            try {
              final id = NotificationIdGenerator.nextAttendanceNotifId();
              final room = (slot.room ?? '').trim();
              final roomSuffix = room.isNotEmpty ? ' | $room' : '';
              await _notifications.zonedSchedule(
                id,
                'Attendance: $label',
                'Did you attend ${course?.name ?? label}? '
                    '${_compact12(slot.startMinutes)}-${_compact12(slot.endMinutes)}$roomSuffix',
                tz.TZDateTime.from(end, tz.local),
                NotificationChannels.attendanceDetails,
                androidScheduleMode: scheduleMode,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
                payload: attendancePayload(slot.id, _ymd(date)),
              );
              map[key] = id;
            } catch (e) {
              AppLog.w('attendance prompt schedule notice', e);
            }
          }
        }
      }
      LocalStore.instance.save('attendance_notif_map', map);
    } catch (e) {
      AppLog.w('refreshAttendancePrompts notice', e);
    }
  }

  Future<void> cancelAttendancePromptsForSlot(String slotId) async {
    if (kIsWeb) return;
    final map = _attendanceNotifMap();
    final doomed =
        map.entries.where((e) => e.key.startsWith('$slotId|')).toList();
    for (final e in doomed) {
      try {
        await _notifications.cancel(e.value);
      } catch (_) {}
      map.remove(e.key);
    }
    LocalStore.instance.save('attendance_notif_map', map);
  }

  Future<void> cancelAttendancePromptFor(String slotId, String date) async {
    if (kIsWeb) return;
    final map = _attendanceNotifMap();
    final key = '$slotId|$date';
    final id = map.remove(key);
    if (id != null) {
      try {
        await _notifications.cancel(id);
      } catch (_) {}
      LocalStore.instance.save('attendance_notif_map', map);
    }
  }

  // ── Instant & Test Notifications ───────────────────────────────────────────

  Future<void> showInstantNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    try {
      await _notifications.show(
        DateTime.now().millisecond,
        title,
        body,
        NotificationChannels.taskDetails,
        payload: payload,
      );
    } catch (e) {
      AppLog.w('showInstantNotification notice', e);
    }
  }

  Future<bool> scheduleTestReminder() async {
    if (kIsWeb) return false;
    try {
      final scheduleMode =
          await NotificationPermissions.getScheduleMode(_notifications);
      final fire = DateTime.now().add(const Duration(minutes: 1));
      await _notifications.zonedSchedule(
        900002,
        'Test reminder',
        'If you see this, reminders work on your phone.',
        tz.TZDateTime.from(fire, tz.local),
        NotificationChannels.taskDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_reminder',
      );
      return true;
    } catch (e) {
      AppLog.w('scheduleTestReminder notice', e);
      return false;
    }
  }
}
