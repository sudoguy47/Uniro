import '../domain/ids.dart';

/// One Pomodoro focus block: completed or ended early.
///
/// [linkKind] is 'none', 'course', 'task', or 'class'. [linkName] is a
/// snapshot taken at record time so history survives renames; when the
/// target still exists the UI prefers its live label, otherwise it falls
/// back to this snapshot. Deleting a course/task/class never deletes
/// its sessions.
class FocusSession {
  final String id;
  final String runId;
  final String date;
  final String startedAt;
  final int plannedSec;
  final int focusedSec;
  final String linkKind;
  final String? linkId;
  final String linkName;
  final bool completed;

  FocusSession({
    String? id,
    required this.runId,
    required this.date,
    required this.startedAt,
    required this.plannedSec,
    required this.focusedSec,
    this.linkKind = 'none',
    this.linkId,
    this.linkName = '',
    required this.completed,
  }) : id = id ?? newLocalId();

  Map<String, dynamic> toJson() => {
        'id': id,
        'runId': runId,
        'date': date,
        'startedAt': startedAt,
        'plannedSec': plannedSec,
        'focusedSec': focusedSec,
        'linkKind': linkKind,
        'linkId': linkId,
        'linkName': linkName,
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) {
    // Migrate pre-link records (v2): courseId/courseName -> course link.
    final legacyCourseId = j['courseId'] as String?;
    final legacyTaskId = j['taskId'] as String?;
    return FocusSession(
      id: j['id'] as String?,
      runId: j['runId'] as String? ?? (j['id'] as String? ?? ''),
      date: j['date'] as String? ?? '',
      startedAt: j['startedAt'] as String? ?? '',
      plannedSec: (j['plannedSec'] as num?)?.toInt() ?? 0,
      focusedSec: (j['focusedSec'] as num?)?.toInt() ??
          ((j['minutes'] as num?)?.toInt() ?? 0) * 60,
      linkKind: j['linkKind'] as String? ??
          (legacyCourseId != null
              ? 'course'
              : (legacyTaskId != null ? 'task' : 'none')),
      linkId: j['linkId'] as String? ?? legacyCourseId ?? legacyTaskId,
      linkName: j['linkName'] as String? ??
          (j['courseName'] as String? ?? ''),
      completed: j['completed'] as bool? ?? true,
    );
  }
}
