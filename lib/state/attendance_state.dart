import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/attendance_logic.dart';
import '../models/attendance_record.dart';
import '../services/notification_service.dart';

/// In-RAM attendance records (mirrors RoutineState's pattern):
/// debounced writes, loaded before first frame in main.dart, refresh() pulls
/// changes written by the notification background isolate.
class AttendanceState extends ChangeNotifier {
  List<AttendanceRecord> _records = [];
  bool _disposed = false;

  List<AttendanceRecord> get records {
    final copy = List<AttendanceRecord>.of(_records);
    copy.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(copy);
  }

  int get total => _records.length;
  int get attended =>
      _records.where((r) => r.status == AttendanceStatus.attended).length;
  int get missed => total - attended;
  double get percentage => attendancePercentage(attended, total);

  /// 'attended' | 'absent' | null — null when the occurrence has no record.
  String? statusFor(String slotId, String date) {
    for (final r in _records) {
      if (r.slotId == slotId && r.date == date) {
        return r.status == AttendanceStatus.attended ? 'attended' : 'absent';
      }
    }
    return null;
  }

  List<AttendanceRecord> historyForCourse(String? courseId) {
    final list = courseId == null
        ? List<AttendanceRecord>.of(_records)
        : _records.where((r) => r.courseId == courseId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Loads from the raw store. Never throws.
  Future<void> load() async {
    _records = readAttendanceRecordsRaw();
    notifyListeners();
  }

  /// Re-reads the raw store (e.g. after the background isolate wrote a
  /// record while the app was closed). Never throws.
  Future<void> refresh() async {
    if (_disposed) return;
    final latest = readAttendanceRecordsRaw();
    if (_sameRecords(_records, latest)) return;
    _records = latest;
    notifyListeners();
  }

  bool _sameRecords(List<AttendanceRecord> a, List<AttendanceRecord> b) {
    if (a.length != b.length) return false;
    final sa = a.map((r) => '${r.id}:${r.recordedAt}').toSet();
    final sb = b.map((r) => '${r.id}:${r.recordedAt}').toSet();
    return sa.length == sb.length && sa.containsAll(sb);
  }

  /// Removes the most recent attended record for [courseId] (sorted by date,
  /// then recordedAt, descending). Returns the removed [AttendanceRecord], or
  /// null if none exists.
  Future<AttendanceRecord?> removeLatestAttended(String courseId) async {
    final attended = _records
        .where((r) => r.courseId == courseId && r.status == AttendanceStatus.attended)
        .toList();
    if (attended.isEmpty) return null;

    attended.sort((a, b) {
      final dateCmp = b.date.compareTo(a.date);
      if (dateCmp != 0) return dateCmp;
      return b.recordedAt.compareTo(a.recordedAt);
    });

    final latest = attended.first;
    await clearById(latest.id);
    return latest;
  }

  /// Restores an exact record (preserving original id, date, slotId, and timestamps).
  Future<void> restoreRecord(AttendanceRecord record) async {
    _records.removeWhere((r) => r.id == record.id);
    _records.add(record);
    writeAttendanceRecordsRaw(_records);
    notifyListeners();
  }

  /// Removes all attendance records for a deleted course.
  Future<void> clearForCourse(String courseId) async {
    _records.removeWhere((r) => r.courseId == courseId);
    writeAttendanceRecordsRaw(_records);
    notifyListeners();
  }

  /// Marks one occurrence. Upserts (never duplicates) and cancels the
  /// pending "did you attend?" prompt for that occurrence.
  Future<void> mark({
    required String slotId,
    required String date,
    required AttendanceStatus status,
    int startMinutes = 0,
    int endMinutes = 0,
    String courseId = '',
    String courseName = '',
    String courseCode = '',
  }) async {
    final existingIdx = _records.indexWhere(
      (r) =>
          (courseId.isEmpty || r.courseId.isEmpty || r.courseId == courseId) &&
          r.slotId == slotId &&
          r.date == date,
    );

    if (existingIdx >= 0) {
      final existing = _records[existingIdx];
      final updated = existing.copyWith(
        status: status,
        startMinutes: startMinutes != 0 ? startMinutes : existing.startMinutes,
        endMinutes: endMinutes != 0 ? endMinutes : existing.endMinutes,
        courseId: courseId.isNotEmpty ? courseId : existing.courseId,
        courseName: courseName.isNotEmpty ? courseName : existing.courseName,
        courseCode: courseCode.isNotEmpty ? courseCode : existing.courseCode,
        recordedAt: DateTime.now().toIso8601String(),
      );
      _records[existingIdx] = updated;
      writeAttendanceRecordsRaw(_records);
      notifyListeners();
      unawaited(NotificationService.instance
          .cancelAttendancePromptFor(slotId, date));
      return;
    }

    _records = upsertAttendanceRaw(
      slotId: slotId,
      date: date,
      status: status,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
    );
    notifyListeners();
    unawaited(NotificationService.instance
        .cancelAttendancePromptFor(slotId, date));
  }

  /// Removes one occurrence's record.
  Future<void> clear({
    required String slotId,
    required String date,
  }) async {
    _records = removeAttendanceRaw(slotId: slotId, date: date);
    notifyListeners();
  }

  /// Manually logs an attendance record for a course on a given date.
  /// Enforces uniqueness per [courseId] + [slotId] + [date]; if a record
  /// already exists for that triple, its status is updated instead of adding another.
  Future<AttendanceRecord> logManual({
    required String courseId,
    required String courseName,
    String courseCode = '',
    required String date,
    required AttendanceStatus status,
    int startMinutes = 0,
    int endMinutes = 0,
    String? slotId,
  }) async {
    final effectiveSlotId = slotId ?? 'manual_$courseId';
    final existingIdx = _records.indexWhere(
      (r) =>
          r.courseId == courseId &&
          r.slotId == effectiveSlotId &&
          r.date == date,
    );

    if (existingIdx >= 0) {
      final existing = _records[existingIdx];
      final updated = existing.copyWith(
        status: status,
        courseName: courseName.isNotEmpty ? courseName : existing.courseName,
        courseCode: courseCode.isNotEmpty ? courseCode : existing.courseCode,
        startMinutes: startMinutes != 0 ? startMinutes : existing.startMinutes,
        endMinutes: endMinutes != 0 ? endMinutes : existing.endMinutes,
        recordedAt: DateTime.now().toIso8601String(),
      );
      _records[existingIdx] = updated;
      writeAttendanceRecordsRaw(_records);
      notifyListeners();
      return updated;
    }

    _records = upsertAttendanceRaw(
      slotId: effectiveSlotId,
      date: date,
      status: status,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
    );
    notifyListeners();
    return _records.firstWhere(
      (r) =>
          r.courseId == courseId &&
          r.slotId == effectiveSlotId &&
          r.date == date,
    );
  }

  /// Removes one record by id.
  Future<void> clearById(String id) async {
    final idx = _records.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    _records.removeAt(idx);
    writeAttendanceRecordsRaw(_records);
    notifyListeners();
  }

  /// Upsert-style merge used by backup import. Newest recordedAt wins per
  /// occurrence. Persists immediately.
  Future<void> mergeBackup(List<AttendanceRecord> incoming) async {
    if (incoming.isEmpty) return;
    _records = mergeAttendanceRecords(_records, incoming);
    writeAttendanceRecordsRaw(_records);
    notifyListeners();
  }

  /// Foreground tap on the attendance prompt. Writes through the same
  /// raw-store path used by the background isolate, then refreshes RAM.
  Future<void> handleNotificationAction(
    String slotId,
    String date,
    String? actionId,
  ) async {
    final wrote = recordAttendanceFromNotification(
      slotId: slotId,
      date: date,
      actionId: actionId,
    );
    if (!wrote) return;
    _records = readAttendanceRecordsRaw();
    notifyListeners();
    unawaited(NotificationService.instance
        .cancelAttendancePromptFor(slotId, date));
  }

  void persistNow() {
    if (_disposed) return;
    writeAttendanceRecordsRaw(_records);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
