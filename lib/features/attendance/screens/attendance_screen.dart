import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/responsive.dart';
import '../../../domain/attendance_logic.dart';
import '../../../domain/haptics.dart';
import '../../../models/attendance_record.dart';
import '../../../models/course.dart';
import '../../../screens/courses_screen.dart';
import '../../../state/app_state.dart';
import '../../../state/attendance_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../widgets/empty_attendance.dart';
import '../widgets/history_list.dart';
import '../widgets/manual_log_sheet.dart';
import '../widgets/overall_stats_card.dart';
import '../widgets/record_options_sheet.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_filter_chips.dart';
import '../widgets/target_picker_sheet.dart';

/// Dedicated attendance overview: overall stats with target setter,
/// per-subject summaries for all courses, manual attendance logger,
/// and full historical record management. Fully offline.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  /// Subject filter applied to the history list; null = all subjects.
  String? _historyFilter;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final attendance = context.watch<AttendanceState>();
    final routine = context.watch<RoutineState>();
    final app = context.watch<AppState>();
    final minPercent = app.settings.minAttendancePercent;
    final records = attendance.records;
    final courses = routine.courses;
    final summaries = summarizeByCourse(records, courses: courses);

    final targetColor = attendance.total == 0
        ? c.textTertiary
        : (attendance.percentage >= minPercent ? c.upcoming : c.overdue);

    final canBunkCount = calculateOverallCanBunk(
        attendance.attended, attendance.total, minPercent);
    final needCount = calculateOverallNeedToAttend(
        attendance.attended, attendance.total, minPercent);

    final hasContent = records.isNotEmpty || courses.isNotEmpty;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Attendance',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _openManualLogSheet(courses: courses),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Log Class',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !hasContent
                  ? EmptyAttendance(
                      onAddCourse: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CoursesScreen(),
                          ),
                        );
                      },
                      onLogClass: () => _openManualLogSheet(courses: courses),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                          16, 4, 16, AppInsets.bottomNavClearance(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Overall overview Card ──
                          OverallStatsCard(
                            percentage: attendance.percentage,
                            attended: attendance.attended,
                            total: attendance.total,
                            missed: attendance.missed,
                            minPercent: minPercent,
                            targetColor: targetColor,
                            canBunkCount: canBunkCount,
                            needCount: needCount,
                            onOpenTargetSheet: () => _openTargetSheet(minPercent),
                          ),
                          const SizedBox(height: 20),

                          // ── Subject-wise summary Header ──
                          Row(
                            children: [
                              Text(
                                'By subject',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '(${summaries.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: c.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const CoursesScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.settings_outlined, size: 14),
                                label: const Text('Manage courses',
                                    style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: c.textSecondary,
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ── Subject Cards ──
                          for (final s in summaries)
                            SubjectAttendanceCard(
                              summary: s,
                              minPercent: minPercent,
                              onIncrement: _incrementAttendance,
                              onDecrement: _decrementAttendance,
                              onQuickMark: _quickMarkAttendance,
                              onLogForCourse: (summary) =>
                                  _openManualLogSheet(courses: courses, preselectedCourseId: summary.courseId),
                            ),

                          const SizedBox(height: 20),

                          // ── History Header ──
                          Row(
                            children: [
                              Text(
                                'History',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${records.length} record${records.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (summaries.isNotEmpty)
                            SubjectFilterChips(
                              summaries: summaries,
                              selected: _historyFilter,
                              onChanged: (v) =>
                                  setState(() => _historyFilter = v),
                            ),
                          const SizedBox(height: 6),

                          AttendanceHistoryList(
                            records: records,
                            filter: _historyFilter,
                            onTapRecord: _showRecordOptions,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick 1-tap marking for today
  Future<void> _quickMarkAttendance(
    SubjectAttendanceSummary summary,
    AttendanceStatus status,
  ) async {
    PremiumHaptics.tap();
    final attendance = context.read<AttendanceState>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final rec = await attendance.logManual(
      courseId: summary.courseId,
      courseName: summary.courseName,
      courseCode: summary.courseCode,
      date: today,
      status: status,
    );

    if (!mounted) return;
    final isAttended = status == AttendanceStatus.attended;
    if (isAttended) {
      AppNotification.success(
        context,
        'Marked ${summary.courseName} as Attended',
        actionLabel: 'Undo',
        onAction: () => attendance.clearById(rec.id),
      );
    } else {
      AppNotification.warning(
        context,
        'Marked ${summary.courseName} as Missed',
        actionLabel: 'Undo',
        onAction: () => attendance.clearById(rec.id),
      );
    }
  }

  /// Increments attended count by 1 for this subject
  Future<void> _incrementAttendance(SubjectAttendanceSummary summary) async {
    PremiumHaptics.confirm();
    final attendance = context.read<AttendanceState>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final rec = await attendance.logManual(
      courseId: summary.courseId,
      courseName: summary.courseName,
      courseCode: summary.courseCode,
      date: today,
      status: AttendanceStatus.attended,
    );

    if (!mounted) return;
    AppNotification.success(
      context,
      '+1 Attended for ${summary.courseName}',
      actionLabel: 'Undo',
      onAction: () => attendance.clearById(rec.id),
    );
  }

  /// Decrements attended count by 1 for this subject
  Future<void> _decrementAttendance(SubjectAttendanceSummary summary) async {
    final attendance = context.read<AttendanceState>();
    final removed = await attendance.removeLatestAttended(summary.courseId);

    if (removed == null) {
      PremiumHaptics.tap();
      if (!mounted) return;
      AppNotification.warning(
        context,
        'No attended classes to decrement for ${summary.courseName}',
      );
      return;
    }

    PremiumHaptics.tap();
    if (!mounted) return;
    AppNotification.info(
      context,
      '-1 Attended for ${summary.courseName}',
      actionLabel: 'Undo',
      onAction: () => attendance.restoreRecord(removed),
    );
  }

  /// Open Target percentage picker bottom sheet
  Future<void> _openTargetSheet(int currentTarget) async {
    final app = context.read<AppState>();
    await TargetPickerSheet.show(
      context: context,
      currentTarget: currentTarget,
      onSaveTarget: (target) {
        app.updateSettings(app.settings.copyWith(minAttendancePercent: target));
      },
    );
  }

  /// Open manual attendance logger bottom sheet
  Future<void> _openManualLogSheet({
    required List<Course> courses,
    String? preselectedCourseId,
  }) async {
    await ManualLogSheet.show(
      context: context,
      courses: courses,
      preselectedCourseId: preselectedCourseId,
    );
  }

  Future<void> _showRecordOptions(AttendanceRecord record) async {
    await RecordOptionsSheet.show(
      context: context,
      record: record,
    );
  }
}
