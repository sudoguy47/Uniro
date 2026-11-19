import '../models/attendance_record.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../services/local_store.dart';

/// LocalStore key holding the JSON list of attendance records.
const String attendanceStoreKey = 'attendance';

/// Payload prefix used on the attendance prompt notification.
/// Format: `att|<slotId>|<yyyy-MM-dd>`.
const String attendancePayloadPrefix = 'att';

String attendancePayload(String slotId, String date) =>
    '$attendancePayloadPrefix|$slotId|$date';

/// Parses an attendance payload. Returns null when the payload is not an
/// attendance payload or is malformed.
({String slotId, String date})? parseAttendancePayload(String? payload) {
  if (payload == null) return null;
  final parts = payload.split('|');
  if (parts.length < 3) return null;
  if (parts[0] != attendancePayloadPrefix) return null;
  final slotId = parts[1].trim();
  final date = parts[2].trim();
  if (slotId.isEmpty || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    return null;
  }
  return (slotId: slotId, date: date);
}

/// Attended / total × 100. Total = records recorded (never divides by zero).
double attendancePercentage(int attended, int total) =>
    total <= 0 ? 0.0 : (attended / total) * 100.0;

class SubjectAttendanceSummary {
  const SubjectAttendanceSummary({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    this.colorTag,
    required this.total,
    required this.attended,
    required this.missed,
  });

  final String courseId;
  final String courseName;
  final String courseCode;
  final int? colorTag;
  final int total;
  final int attended;
  final int missed;

  double get percentage => attendancePercentage(attended, total);

  /// Calculates how many classes can be missed while maintaining [targetPercent].
  int canBunk(int targetPercent) {
    if (total <= 0 || targetPercent <= 0) return 0;
    if (percentage < targetPercent) return 0;
    final maxTotal = (attended * 100) ~/ targetPercent;
    return (maxTotal - total).clamp(0, 9999);
  }

  /// Calculates how many consecutive classes must be attended to reach [targetPercent].
  int needToAttend(int targetPercent) {
    if (targetPercent <= 0) return 0;
    if (total > 0 && percentage >= targetPercent) return 0;
    if (targetPercent >= 100) return total == 0 ? 1 : 999;
    final num = (targetPercent * total) - (100 * attended);
    final den = 100 - targetPercent;
    final res = (num / den).ceil();
    return res.clamp(0, 9999);
  }

  /// Human-readable actionable insight message.
  String statusMessage(int targetPercent) {
    if (total == 0) return 'No classes recorded yet';
    if (percentage >= targetPercent) {
      final safeToSkip = canBunk(targetPercent);
      if (safeToSkip > 0) {
        return 'Safe to skip $safeToSkip class${safeToSkip == 1 ? '' : 'es'}';
      }
      return 'On track · Don\'t miss next class';
    }
    final needed = needToAttend(targetPercent);
    return 'Attend $needed more class${needed == 1 ? '' : 'es'} to reach $targetPercent%';
  }
}

int calculateOverallCanBunk(int attended, int total, int targetPercent) {
  if (total <= 0 || targetPercent <= 0) return 0;
  final pct = attendancePercentage(attended, total);
  if (pct < targetPercent) return 0;
  final maxTotal = (attended * 100) ~/ targetPercent;
  return (maxTotal - total).clamp(0, 9999);
}

int calculateOverallNeedToAttend(int attended, int total, int targetPercent) {
  if (targetPercent <= 0) return 0;
  if (total > 0 && attendancePercentage(attended, total) >= targetPercent) return 0;
  if (targetPercent >= 100) return total == 0 ? 1 : 999;
  final num = (targetPercent * total) - (100 * attended);
  final den = 100 - targetPercent;
  final res = (num / den).ceil();
  return res.clamp(0, 9999);
}

/// Groups records per course, incorporating registered [courses] so every
/// registered course appears in the overview even before classes are recorded.
List<SubjectAttendanceSummary> summarizeByCourse(
    List<AttendanceRecord> records, {
    List<Course> courses = const [],
}) {
  final byCourse = <String, List<AttendanceRecord>>{};
  final courseMap = <String, Course>{for (final c in courses) c.id: c};

  // Seed with all defined courses first
  for (final c in courses) {
    byCourse[c.id] = [];
  }

  for (final r in records) {
    // Snapshot the display label into the key so renamed/deleted courses
    // do not silently merge into an unrelated subject.
    final key = r.courseId.isNotEmpty ? r.courseId : 'ghost|${r.courseCode}|${r.courseName}';
    byCourse.putIfAbsent(key, () => []).add(r);
  }
  final out = <SubjectAttendanceSummary>[];
  for (final entry in byCourse.entries) {
    final list = entry.value;
    final attended = list.where((r) => r.status == AttendanceStatus.attended).length;
    final course = courseMap[entry.key];
    final display = list.isNotEmpty ? list.last : null;
    final courseName = course?.name ??
        (display != null && display.courseName.isNotEmpty
            ? display.courseName
            : 'Unknown subject');
    final courseCode = course?.code ?? (display?.courseCode ?? '');
    final colorTag = course?.colorTag;

    out.add(SubjectAttendanceSummary(
      courseId: entry.key,
      courseName: courseName,
      courseCode: courseCode,
      colorTag: colorTag,
      total: list.length,
      attended: attended,
      missed: list.length - attended,
    ));
  }
  out.sort((a, b) => a.courseName.toLowerCase().compareTo(b.courseName.toLowerCase()));
  return out;
}

/// Merge two record lists by id; on duplicate occurrence (slotId|date) the
/// entry with the newest [recordedAt] wins. Stable, pure, idempotent.
List<AttendanceRecord> mergeAttendanceRecords(
  List<AttendanceRecord> base,
  List<AttendanceRecord> incoming,
) {
  final byId = <String, AttendanceRecord>{};
  final byOccurrence = <String, String>{}; // occurrenceKey -> id
  void put(AttendanceRecord r) {
    final existingId = byOccurrence[r.occurrenceKey];
    if (existingId != null && existingId != r.id) {
      final existing = byId[existingId]!;
      // Newest recordedAt wins for the same occurrence.
      if (r.recordedAt.compareTo(existing.recordedAt) >= 0) {
        byId.remove(existingId);
        byId[r.id] = r;
        byOccurrence[r.occurrenceKey] = r.id;
      }
      return;
    }
    byId[r.id] = r;
    byOccurrence[r.occurrenceKey] = r.id;
  }

  for (final r in base) {
    put(r);
  }
  for (final r in incoming) {
    put(r);
  }
  return byId.values.toList();
}

/// Reads the raw attendance list from LocalStore. Never throws; a corrupt
/// list yields an empty list with the recovery flag set.
List<AttendanceRecord> readAttendanceRecordsRaw() {
  try {
    final raw = LocalStore.instance.load(attendanceStoreKey);
    if (raw is! List) return [];
    final out = <AttendanceRecord>[];
    for (final j in raw) {
      try {
        if (j is Map) {
          out.add(AttendanceRecord.fromJson(Map<String, dynamic>.from(j)));
        } else {
          LocalStore.instance.markRecovery();
        }
      } catch (_) {
        LocalStore.instance.markRecovery();
      }
    }
    return out;
  } catch (_) {
    return [];
  }
}

void writeAttendanceRecordsRaw(List<AttendanceRecord> records) {
  LocalStore.instance.save(
    attendanceStoreKey,
    records.map((r) => r.toJson()).toList(),
  );
}

/// Upserts one occurrence's record into the raw store. Returns the updated
/// list. Shared by the foreground isolate (via AttendanceState) and the
/// notification background isolate.
List<AttendanceRecord> upsertAttendanceRaw({
  required String slotId,
  required String date,
  required AttendanceStatus status,
  required int startMinutes,
  required int endMinutes,
  String courseId = '',
  String courseName = '',
  String courseCode = '',
}) {
  final records = readAttendanceRecordsRaw();
  final idx = records.indexWhere(
    (r) =>
        (courseId.isEmpty || r.courseId.isEmpty || r.courseId == courseId) &&
        r.slotId == slotId &&
        r.date == date,
  );
  final now = DateTime.now().toIso8601String();
  if (idx >= 0) {
    records[idx] = records[idx].copyWith(
      status: status,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      recordedAt: now,
      courseId: courseId.isNotEmpty ? courseId : records[idx].courseId,
      courseName: courseName.isNotEmpty ? courseName : records[idx].courseName,
      courseCode: courseCode.isNotEmpty ? courseCode : records[idx].courseCode,
    );
  } else {
    records.add(AttendanceRecord(
      slotId: slotId,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      date: date,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      status: status,
      recordedAt: now,
    ));
  }
  writeAttendanceRecordsRaw(records);
  return records;
}

/// Removes one occurrence's record from the raw store. Returns the updated
/// list.
List<AttendanceRecord> removeAttendanceRaw({
  required String slotId,
  required String date,
}) {
  final records = readAttendanceRecordsRaw();
  records.removeWhere((r) => r.slotId == slotId && r.date == date);
  writeAttendanceRecordsRaw(records);
  return records;
}

/// Maps a notification action id to an outcome; null when unrecognized.
AttendanceStatus? attendanceStatusFromActionId(String? actionId) {
  switch (actionId) {
    case 'attended':
      return AttendanceStatus.attended;
    case 'missed':
      return AttendanceStatus.absent;
    default:
      return null;
  }
}

/// Full record write for an attendance notification action. Shared by the
/// foreground path (via AttendanceState) and the background isolate handler.
/// Never throws.
bool recordAttendanceFromNotification({
  required String slotId,
  required String date,
  required String? actionId,
}) {
  try {
    final status = attendanceStatusFromActionId(actionId);
    if (status == null) return false;
    final slot = findSlotRaw(slotId);
    final course = slot != null
        ? findCourseRaw(slot.courseId)
        : (id: '', name: '', code: '');
    upsertAttendanceRaw(
      slotId: slotId,
      date: date,
      status: status,
      startMinutes: slot?.startMinutes ?? 0,
      endMinutes: slot?.endMinutes ?? 0,
      courseId: course.id,
      courseName: course.name,
      courseCode: course.code,
    );
    return true;
  } catch (_) {
    return false;
  }
}

/// Looks up a slot's details by id from the raw store (used by the
/// background isolate, which has no access to RoutineState).
ClassSlot? findSlotRaw(String slotId) {
  try {
    final raw = LocalStore.instance.load('slots');
    if (raw is! List) return null;
    for (final j in raw) {
      try {
        if (j is Map) {
          final slot = ClassSlot.fromJson(Map<String, dynamic>.from(j));
          if (slot.id == slotId) return slot;
        }
      } catch (_) {}
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Course snapshot for the background isolate.
({String id, String name, String code}) findCourseRaw(String courseId) {
  try {
    final raw = LocalStore.instance.load('courses');
    if (raw is! List) return (id: courseId, name: '', code: '');
    for (final j in raw) {
      try {
        if (j is Map) {
          final m = Map<String, dynamic>.from(j);
          if (m['id'] == courseId) {
            return (
              id: courseId,
              name: (m['name'] as String?) ?? '',
              code: (m['code'] as String?) ?? '',
            );
          }
        }
      } catch (_) {}
    }
  } catch (_) {}
  return (id: courseId, name: '', code: '');
}
