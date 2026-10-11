import '../domain/ids.dart';

/// One weekly class-schedule entry (Page 2 of the dashboard pager).
///
/// Times are 24h `HH:mm` strings (lexicographically sortable).
/// [dayOfWeek]: 0 = Monday … 6 = Sunday.
class ClassRoutineEntry {
  final String id;
  final String subjectName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;

  ClassRoutineEntry({
    String? id,
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.room,
  }) : id = id ?? newLocalId();

  static const dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const dayChips = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  /// Minutes since midnight — for sorting and end-after-start validation.
  static int minutesOf(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }

  ClassRoutineEntry copyWith({
    String? subjectName,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    bool clearRoom = false,
  }) =>
      ClassRoutineEntry(
        id: id,
        subjectName: subjectName ?? this.subjectName,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        room: clearRoom ? null : (room ?? this.room),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'room': room,
      };

  factory ClassRoutineEntry.fromJson(Map<String, dynamic> j) =>
      ClassRoutineEntry(
        id: j['id'] as String?,
        subjectName: j['subjectName'] as String? ?? '',
        dayOfWeek: (j['dayOfWeek'] as num?)?.toInt().clamp(0, 6) ?? 0,
        startTime: j['startTime'] as String? ?? '09:00',
        endTime: j['endTime'] as String? ?? '10:00',
        room: j['room'] as String?,
      );
}
