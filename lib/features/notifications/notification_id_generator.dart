import 'dart:convert';
import '../../services/local_store.dart';

/// Constants and ID generation logic for notifications.
class NotificationIdGenerator {
  NotificationIdGenerator._();

  static const int greetingIdStart = 900001;
  static const int greetingDaysCount = 7;

  static const int classIdStart = 500000;
  static const int classIdEnd = 599999;
  static const int classWindowDays = 14;

  static const int attendanceIdStart = 600000;
  static const int attendanceIdEnd = 699999;
  static const int attendanceWindowDays = 14;

  /// Stable, deterministic 31-bit FNV-1a hash over utf8 bytes of [raw], masked
  /// with 0x7FFFFFFF. Collision-resistant and constant across platforms/runs.
  static int makeNotificationId(String taskId, [String? suffix]) {
    final raw = suffix != null ? '$taskId:$suffix' : taskId;
    final bytes = utf8.encode(raw);
    var hash = 0x811c9dc5; // 32-bit FNV-1a offset basis (2166136261)
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF; // 32-bit FNV prime (16777619)
    }
    return hash & 0x7FFFFFFF;
  }

  static int nextClassNotifId() {
    final raw = LocalStore.instance.load('class_notif_next');
    var next = raw is num ? raw.toInt() : classIdStart;
    if (next < classIdStart || next > classIdEnd) next = classIdStart;
    LocalStore.instance.save('class_notif_next', next + 1);
    return next;
  }

  static int nextAttendanceNotifId() {
    final raw = LocalStore.instance.load('attendance_notif_next');
    var next = raw is num ? raw.toInt() : attendanceIdStart;
    if (next < attendanceIdStart || next > attendanceIdEnd) {
      next = attendanceIdStart;
    }
    LocalStore.instance.save('attendance_notif_next', next + 1);
    return next;
  }
}
