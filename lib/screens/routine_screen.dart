import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import 'package:provider/provider.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import '../widgets/class_form_sheet.dart';

/// Routine tab: weekly class schedule.
///
/// - 7-day selector ordered from the week-start setting, today highlighted,
///   selected day as a 200ms animated pill.
/// - Day cards: 12h time range, code + name with course color bar, room,
///   teacher. Running class → Now badge; finished → dimmed (+ attendance
///   check via [attendanceStatus] hook, wired in the attendance step).
/// - Tap → sheet (Edit / Delete with confirm + undo / Attendance row).
/// - Entrance: fade + 12px slide, 30ms stagger on day change; delete plays
///   shrink + fade. Honors reduce-motion.
class RoutineScreen extends StatefulWidget {
  const RoutineScreen({
    super.key,
    this.attendanceStatus,
  });

  /// Hook (attendance step): returns 'attended' | 'absent' | null for a
  /// slot on a yyyy-MM-dd date. Null = hook not wired yet.
  final String? Function(String slotId, String date)? attendanceStatus;

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
    _weekday = DateTime.now().weekday;
  }

  /// Weekdays ordered from [weekStart] (1–7, DateTime convention).
  static List<int> orderedWeekdays(int weekStart) {
    return List.generate(7, (i) => ((weekStart - 1 + i) % 7) + 1);
  }

  /// Calendar date of [weekday] in the current week (per [weekStart]).
  static DateTime dateForWeekday(DateTime today, int weekStart, int weekday) {
    final base = today
        .subtract(Duration(days: (today.weekday - weekStart + 7) % 7));
    return DateTime(base.year, base.month, base.day)
        .add(Duration(days: (weekday - weekStart + 7) % 7));
  }

  static String ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _refreshReminders() {
    final routine = context.read<RoutineState>();
    final enabled = context.read<AppState>().settings.notificationsEnabled;
    return NotificationService.instance.refreshClassReminders(
      courses: routine.courses,
      slots: routine.slots,
      enabled: enabled,
    );
  }

  void _openForm({ClassSlot? existing}) {
    showClassFormSheet(context, existing: existing);
  }

  void _openCardSheet(ClassSlot slot, Course? course) {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: c.textSecondary),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _openForm(existing: slot);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.overdue),
              title:
                  Text('Delete', style: TextStyle(color: c.overdue)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(slot, course);
              },
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.fact_check_outlined,
                  color: c.textTertiary),
              title: Text('Attendance — coming next',
                  style: TextStyle(color: c.textTertiary)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
    final removed = context.read<RoutineState>().deleteSlot(slot.id);
    _refreshReminders();
    if (!mounted || removed == null) {
      setState(() => _leavingId = null);
      return;
    }
    setState(() => _leavingId = null);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Class deleted'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              context.read<RoutineState>().restoreSlot(removed);
              _refreshReminders();
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final weekStart =
        context.select((AppState s) => s.settings.weekStartDay);
    final routine = context.watch<RoutineState>();
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
            // Header. Title shrinks by ellipsis; the button keeps a
            // measured slot and shrink-fits so the Row never overflows
            // at 320dp / large text.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: LayoutBuilder(builder: (context, cons) {
                final btnW =
                    (cons.maxWidth * 0.42).clamp(96.0, 170.0);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Routine',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: btnW,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            PremiumHaptics.tap();
                            _openForm();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Add class',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
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
                  final isTodayChip =
                      ymd(date) == todayStr;
                  return _DayChip(
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
                  ? _EmptyDay(onAdd: () => _openForm())
                  : ListView.builder(
                      key: ValueKey(_weekday),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: daySlots.length,
                      itemBuilder: (context, i) {
                        final slot = daySlots[i];
                        final course =
                            routine.courseById(slot.courseId);
                        final nowMin =
                            today.hour * 60 + today.minute;
                        final running = isToday &&
                            slot.startMinutes <= nowMin &&
                            nowMin < slot.endMinutes;
                        final finished = isPast ||
                            (isToday && nowMin >= slot.endMinutes);
                        final att = widget.attendanceStatus
                            ?.call(slot.id, selectedStr);
                        return _Entrance(
                          index: i,
                          child: _RoutineCard(
                            slot: slot,
                            course: course,
                            running: running,
                            finished: finished,
                            attendance: att,
                            leaving: _leavingId == slot.id,
                            onLeavingDone: () => _removeNow(slot),
                            onTap: () =>
                                _openCardSheet(slot, course),
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

const courseWeekdayNames = <int, String>{
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Day chip: short name + date; selected = 200ms animated pill.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.weekday,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int weekday;
  final int date;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  static const _names = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.navActiveBg : c.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? c.navActiveBg
                : (isToday ? c.accent : c.border),
            width: isToday && !selected ? 2 : 1,
          ),
        ),
        alignment: Alignment.center,
        // Shrink-fit: identical at normal sizes, scales down instead of
        // throwing at extreme text scales.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _names[weekday],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? c.navActiveText
                      : (isToday ? c.accent : c.textSecondary),
                ),
              ),
              Text(
                '$date',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color:
                      selected ? c.navActiveText : c.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrance: fade + 12px slide-up, 30ms stagger. Skipped on reduce-motion.
class _Entrance extends StatefulWidget {
  const _Entrance({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final noAnim =
        MediaQueryData.fromView(View.of(context)).disableAnimations;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.13), // ≈12px on a ~90px card
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (noAnim) {
      _ctrl.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: widget.index * 30), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

/// Day class card with Now badge / dimmed-finished + shrink-fade delete-out.
class _RoutineCard extends StatefulWidget {
  const _RoutineCard({
    required this.slot,
    required this.course,
    required this.running,
    required this.finished,
    required this.attendance,
    required this.leaving,
    required this.onLeavingDone,
    required this.onTap,
  });

  final ClassSlot slot;
  final Course? course;
  final bool running;
  final bool finished;
  final String? attendance;
  final bool leaving;
  final VoidCallback onLeavingDone;
  final VoidCallback onTap;

  @override
  State<_RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<_RoutineCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _out;
  bool _playedOut = false;

  @override
  void initState() {
    super.initState();
    _out = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void didUpdateWidget(covariant _RoutineCard old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !_playedOut) {
      _playedOut = true;
      _out.reverse(from: 1.0).then((_) {
        if (mounted) widget.onLeavingDone();
      });
    }
  }

  @override
  void dispose() {
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final course = widget.course;
    final barColor = course?.colorTag != null
        ? Color(course!.colorTag!)
        : c.accent;
    final checked =
        widget.attendance != null && widget.attendance!.isNotEmpty;

    Widget card = Opacity(
      opacity: widget.finished ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _title(course),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.running)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Now',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      if (checked)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.check_circle_rounded,
                              size: 18, color: c.upcoming),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _range(context),
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                  ..._metaLines(c),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.leaving) {
      card = SizeTransition(
        sizeFactor: _out,
        alignment: Alignment.bottomCenter,
        child: FadeTransition(opacity: _out, child: card),
      );
    }

    return GestureDetector(
      onTap: () {
        if (widget.leaving) return;
        PremiumHaptics.tap();
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }

  String _title(Course? course) {
    if (course == null) return 'Class';
    final code = (course.code ?? '').trim();
    return code.isNotEmpty ? '$code · ${course.name}' : course.name;
  }

  String _range(BuildContext context) {
    TimeOfDay t(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return '${t(widget.slot.startMinutes).format(context)} – ${t(widget.slot.endMinutes).format(context)}';
  }

  List<Widget> _metaLines(AppColors c) {
    final course = widget.course;
    final bits = <String>[];
    final room =
        (widget.slot.room ?? course?.room ?? '').trim();
    if (room.isNotEmpty) bits.add(room);
    final teacher = (course?.teacher ?? '').trim();
    if (teacher.isNotEmpty) bits.add(teacher);
    if (bits.isEmpty) return const [];
    return [
      const SizedBox(height: 2),
      Text(
        bits.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: c.textTertiary),
      ),
    ];
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined,
              size: 44, color: c.textTertiary),
          const SizedBox(height: 10),
          Text(
            'No classes this day',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              PremiumHaptics.tap();
              onAdd();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Add class',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
