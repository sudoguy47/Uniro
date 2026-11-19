import '../domain/ids.dart';

/// Attendance outcome for one class occurrence.
enum AttendanceStatus { attended, absent }

/// yyyy-MM-dd comparison helpers shared by records and summaries.
String _statusName(AttendanceStatus s) =>
    s == AttendanceStatus.attended ? 'attended' : 'absent';

AttendanceStatus attendanceStatusFromName(String? raw) =>
    raw == 'attended' ? AttendanceStatus.attended : AttendanceStatus.absent;

/// One attendance record for a single class occurrence
/// ([slotId] + [date] — the pair is unique).
///
/// [courseName], [courseCode], [startMinutes] and [endMinutes] are snapshots
/// taken at record time so history stays meaningful after a course is
/// renamed, deleted or rescheduled.
class AttendanceRecord {
  final String id;
  final String slotId;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String date; // 'yyyy-MM-dd'
  final int startMinutes;
  final int endMinutes;
  final AttendanceStatus status;
  final String recordedAt; // ISO-8601

  AttendanceRecord({
    String? id,
    required this.slotId,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.status,
    String? recordedAt,
  })  : id = id ?? newLocalId(),
        recordedAt = recordedAt ?? DateTime.now().toIso8601String();

  /// Stable dedup key for one occurrence of one slot.
  String get occurrenceKey => '$slotId|$date';

  AttendanceRecord copyWith({
    String? courseId,
    String? courseName,
    String? courseCode,
    int? startMinutes,
    int? endMinutes,
    AttendanceStatus? status,
    String? recordedAt,
  }) =>
      AttendanceRecord(
        id: id,
        slotId: slotId,
        courseId: courseId ?? this.courseId,
        courseName: courseName ?? this.courseName,
        courseCode: courseCode ?? this.courseCode,
        date: date,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        status: status ?? this.status,
        recordedAt: recordedAt ?? this.recordedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slotId': slotId,
        'courseId': courseId,
        'courseName': courseName,
        'courseCode': courseCode,
        'date': date,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'status': _statusName(status),
        'recordedAt': recordedAt,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: j['id'] as String?,
        slotId: j['slotId'] as String? ?? '',
        courseId: j['courseId'] as String? ?? '',
        courseName: j['courseName'] as String? ?? '',
        courseCode: j['courseCode'] as String? ?? '',
        date: j['date'] as String? ?? '',
        startMinutes: (j['startMinutes'] as num?)?.toInt() ?? 0,
        endMinutes: (j['endMinutes'] as num?)?.toInt() ?? 0,
        status: attendanceStatusFromName(j['status'] as String?),
        recordedAt: j['recordedAt'] as String?,
      );
}
