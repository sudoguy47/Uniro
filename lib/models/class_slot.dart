import '../domain/ids.dart';

/// One weekly class occurrence (Routine tab).
///
/// Times are minutes since midnight (easy math + sorting).
/// [weekday] uses DateTime convention: 1 = Monday … 7 = Sunday.
/// [reminderMinutesBefore]: null = no reminder, else 15/10/5/30…
class ClassSlot {
  final String id;
  final String courseId;
  final int weekday;
  final int startMinutes;
  final int endMinutes;
  final String? room;
  final int? reminderMinutesBefore;
  /// True for built-in example content ("Use examples" seed).
  final bool isSample;

  ClassSlot({
    String? id,
    required this.courseId,
    required this.weekday,
    required this.startMinutes,
    required this.endMinutes,
    this.room,
    this.reminderMinutesBefore = 15,
    this.isSample = false,
  }) : id = id ?? newLocalId();

  ClassSlot copyWith({
    String? courseId,
    int? weekday,
    int? startMinutes,
    int? endMinutes,
    String? room,
    bool clearRoom = false,
    int? reminderMinutesBefore,
    bool clearReminder = false,
    bool? isSample,
  }) =>
      ClassSlot(
        id: id,
        courseId: courseId ?? this.courseId,
        weekday: weekday ?? this.weekday,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        room: clearRoom ? null : (room ?? this.room),
        reminderMinutesBefore: clearReminder
            ? null
            : (reminderMinutesBefore ?? this.reminderMinutesBefore),
        isSample: isSample ?? this.isSample,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseId': courseId,
        'weekday': weekday,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'room': room,
        'reminderMinutesBefore': reminderMinutesBefore,
        if (isSample) 'isSample': true,
      };

  factory ClassSlot.fromJson(Map<String, dynamic> j) => ClassSlot(
        id: j['id'] as String?,
        courseId: j['courseId'] as String? ?? '',
        weekday: (j['weekday'] as num?)?.toInt().clamp(1, 7) ?? 1,
        startMinutes: (j['startMinutes'] as num?)?.toInt() ?? 540,
        endMinutes: (j['endMinutes'] as num?)?.toInt() ?? 630,
        room: j['room'] as String?,
        reminderMinutesBefore:
            (j['reminderMinutesBefore'] as num?)?.toInt(),
        isSample: j['isSample'] as bool? ?? false,
      );
}

/// Pure overlap test (same weekday assumed by callers): true when the two
/// [start,end) minute ranges intersect. Unit-tested.
bool slotsOverlapMinutes(
    int aStart, int aEnd, int bStart, int bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

/// Pure: does [candidate] overlap any slot in [others] on the same weekday?
/// [ignoreId] skips the slot being edited.
bool slotOverlapsAny({
  required int weekday,
  required int startMinutes,
  required int endMinutes,
  required List<ClassSlot> others,
  String? ignoreId,
}) {
  for (final o in others) {
    if (o.weekday != weekday) continue;
    if (ignoreId != null && o.id == ignoreId) continue;
    if (slotsOverlapMinutes(
        startMinutes, endMinutes, o.startMinutes, o.endMinutes)) {
      return true;
    }
  }
  return false;
}
