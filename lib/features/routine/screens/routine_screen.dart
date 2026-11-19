import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/responsive.dart';
import '../../../domain/haptics.dart';
import '../../../models/class_slot.dart';
import '../../../models/course.dart';
import '../../../screens/attendance_screen.dart';
import '../../../screens/courses_screen.dart';
import '../../../services/notification_service.dart';
import '../../../state/app_state.dart';
import '../../../state/attendance_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/class_form_sheet.dart';
import '../logic/routine_constants.dart';
import '../widgets/day_chip.dart';
import '../widgets/empty_day.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/routine_attendance_header.dart';
import '../widgets/routine_card.dart';
import '../widgets/routine_entrance.dart';
import '../widgets/routine_slot_actions_sheet.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({
    super.key,
    this.initialWeekday,
    this.attendanceStatus,
  });

  /// Override the initial selected weekday (1 = Mon .. 7 = Sun).
  /// Falls back to today's weekday when null.
  final int? initialWeekday;

  /// Hook for tests to override the displayed attendance status
  /// without spinning up a fake AttendanceState. Takes (slotId, yyyy-MM-dd)
  /// and returns 'attended', 'absent', or null.
  final String? Function(String slotId, String dateStr)? attendanceStatus;

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late int _weekday;
  String? _leavingId;

  @override
  void initState() {
    super.initState();
    _weekday = widget.initialWeekday ?? DateTime.now().weekday;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAttendancePrompts();
    });
  }

  Future<void> _syncAttendancePrompts() async {
    final routine = context.read<RoutineState>();
    final enabled =
        context.read<AppState>().settings.notificationsEnabled;
    return NotificationService.instance.refreshAttendancePrompts(
      courses: routine.courses,
      slots: routine.slots,
      enabled: enabled,
    );
  }

  void _openForm({ClassSlot? existing}) {
    showClassFormSheet(context, existing: existing);
  }

  void _confirmDelete(ClassSlot slot, Course? course) {
    final c = Theme.of(context).extension<AppColors>()!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('Delete this class?'),
        content: Text(
            '${course?.name ?? 'Class'} on ${courseWeekdayNames[slot.weekday]} will be removed. Its reminders go with it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _leavingId = slot.id);
            },
            child: Text('Delete', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
  }

  void _removeNow(ClassSlot slot) {
    final routine = context.read<RoutineState>();
    final deleted = routine.deleteSlot(slot.id);
    if (deleted == null) return;
    setState(() => _leavingId = null);
    final app = context.read<AppState>();
    final routineNow = context.read<RoutineState>();
    NotificationService.instance.rearmAll(
      tasks: app.tasks,
      courses: routineNow.courses,
      slots: routineNow.slots,
      name: app.settings.name,
      enabled: app.settings.notificationsEnabled,
    );
    AppNotification.show(
      context,
      message: 'Class deleted',
      actionLabel: 'UNDO',
      onAction: () {
        context.read<RoutineState>().addSlot(deleted);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final weekStart =
        context.select((AppState s) => s.settings.weekStartDay);
    final routine = context.watch<RoutineState>();
    AttendanceState? attendance;
    try {
      attendance = context.watch<AttendanceState>();
    } catch (_) {
      attendance = null;
    }
    final attTotal = attendance?.total ?? 0;
    final attAttended = attendance?.attended ?? 0;
    final attMissed = attendance?.missed ?? 0;
    final attPercentage = attendance?.percentage ?? 0.0;
    final minPercent =
        context.select((AppState s) => s.settings.minAttendancePercent);
    final targetColor = attTotal == 0
        ? c.textSecondary
        : (attPercentage >= minPercent ? c.upcoming : c.overdue);
    final today = DateTime.now();
    final days = orderedWeekdays(weekStart);
    final daySlots = routine.slotsForWeekday(_weekday);
    final selectedDate = dateForWeekday(today, weekStart, _weekday);
    final todayStr = ymd(today);
    final selectedStr = ymd(selectedDate);
    final isToday = selectedStr == todayStr;
    final isPast = selectedDate
        .isBefore(DateTime(today.year, today.month, today.day));

    return Scaffold(
      backgroundColor: c.pageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Attendance Overview Card ─────────────────────────────────────
            RoutineAttendanceHeader(
              attTotal: attTotal,
              attAttended: attAttended,
              attMissed: attMissed,
              attPercentage: attPercentage,
              targetColor: targetColor,
            ),

            // ── Top Action Section (Courses, Attendance, Add Class) ───────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.school_outlined,
                      label: 'Courses',
                      onTap: () {
                        PremiumHaptics.tap();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CoursesScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance',
                      onTap: () {
                        PremiumHaptics.tap();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AttendanceScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: QuickActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Class',
                      isPrimary: true,
                      onTap: () {
                        PremiumHaptics.tap();
                        _openForm();
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Day selector.
            SizedBox(
              height: 64,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 7,
                itemBuilder: (context, i) {
                  final w = days[i];
                  final date = dateForWeekday(today, weekStart, w);
                  final selected = w == _weekday;
                  final isTodayChip = ymd(date) == todayStr;
                  return DayChip(
                    weekday: w,
                    date: date.day,
                    selected: selected,
                    isToday: isTodayChip,
                    onTap: () {
                      if (_weekday == w) return;
                      PremiumHaptics.select();
                      setState(() {
                        _weekday = w;
                        _leavingId = null;
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Day classes.
            Expanded(
              child: daySlots.isEmpty
                  ? RoutineEmptyDay(onAdd: () => _openForm())
                  : ListView.builder(
                      key: ValueKey(_weekday),
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, AppInsets.bottomNavClearance(context)),
                      itemCount: daySlots.length,
                      itemBuilder: (context, i) {
                        final slot = daySlots[i];
                        final course = routine.courseById(slot.courseId);
                        final nowMin = today.hour * 60 + today.minute;
                        final running = isToday &&
                            slot.startMinutes <= nowMin &&
                            nowMin < slot.endMinutes;
                        final finished = isPast ||
                            (isToday && nowMin >= slot.endMinutes);
                        final att = widget.attendanceStatus
                                ?.call(slot.id, selectedStr) ??
                            attendance?.statusFor(slot.id, selectedStr);
                        return RoutineEntrance(
                          index: i,
                          child: RoutineCard(
                            slot: slot,
                            course: course,
                            running: running,
                            finished: finished,
                            attendance: att,
                            leaving: _leavingId == slot.id,
                            onLeavingDone: () => _removeNow(slot),
                            onTap: () => RoutineSlotActionsSheet.show(
                              context: context,
                              slot: slot,
                              course: course,
                              dateStr: selectedStr,
                              onEdit: () => _openForm(existing: slot),
                              onDelete: () => _confirmDelete(slot, course),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
