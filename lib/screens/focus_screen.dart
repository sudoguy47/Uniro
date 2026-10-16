import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/focus_logic.dart';
import '../domain/haptics.dart';
import '../models/task.dart';
import '../screens/courses_screen.dart';
import '../screens/focus_summary_screen.dart';
import '../state/app_state.dart';
import '../state/focus_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import '../widgets/flip_card.dart';

const _presets = [25, 45, 60];

/// Course-based Pomodoro timer.
///
/// Course is required before starting. Timing is wall-clock based, pause
/// freezes both countdown and recorded time, and only focus time is ever
/// recorded — never break or paused time.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  FocusState get _st => context.read<FocusState>();

  IconData _linkIcon(String kind) => switch (kind) {
        'course' => Icons.school_outlined,
        'task' => Icons.assignment_outlined,
        'class' => Icons.class_outlined,
        _ => Icons.block_rounded,
      };

  /// Live display label for a link target, with snapshot-safe fallbacks.
  String _linkLabel(String kind, String? id) {
    final routine = context.read<RoutineState>();
    switch (kind) {
      case 'course':
        final c = id == null ? null : routine.courseById(id);
        if (c == null) return 'Removed course';
        final code = c.code ?? '';
        return code.isNotEmpty ? '$code · ${c.name}' : c.name;
      case 'task':
        try {
          return context
              .read<AppState>()
              .tasks
              .firstWhere((e) => e.id == id)
              .title;
        } catch (_) {
          return 'Removed task';
        }
      case 'class':
        for (final s in routine.slots) {
          if (s.id == id) {
            final course = routine.courseById(s.courseId);
            final code = course?.code ?? '';
            final base = course == null
                ? 'Removed course'
                : (code.isNotEmpty
                    ? '$code · ${course.name}'
                    : course.name);
            return '$base · ${weekdayShort(s.weekday)} '
                '${slotClock(s.startMinutes)}';
          }
        }
        return 'Removed class';
      default:
        return 'Free focus';
    }
  }

  void _syncLinkName() {
    final st = _st;
    st.setLiveLinkName(_linkLabel(st.linkKind, st.linkId));
  }

  // ── Actions ──

  void _onStart() {
    final st = _st;
    _syncLinkName();
    PremiumHaptics.tap();
    st.start();
  }

  Future<void> _onRestart() async {
    final st = _st;
    if (st.phase == FocusPhase.idle && !st.pendingBreak) {
      PremiumHaptics.tap();
      st.restart();
      return;
    }
    final c = Theme.of(context).extension<AppColors>()!;
    final focused = st.focusedSoFar();
    final saveLine = focused > 0 && st.phase == FocusPhase.focus
        ? 'Your ${formatDuration(focused)} of focus so far will be saved as an ended-early session. '
        : '';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('Restart timer?'),
        content: Text(
            '${saveLine}The clock resets to the full ${st.phase == FocusPhase.breakTime ? st.breakMin : st.focusMin}-minute ${st.phase == FocusPhase.breakTime ? 'break' : 'focus'} and keeps running.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restart', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    _syncLinkName();
    PremiumHaptics.confirm();
    final saved = st.restart();
    if (saved > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved ${formatDuration(saved)} as ended early.')));
    }
  }

  Future<void> _onEnd() async {
    final st = _st;
    if (st.phase == FocusPhase.idle && !st.pendingBreak) return;
    if (st.phase == FocusPhase.breakTime) {
      PremiumHaptics.tap();
      st.endSession();
      return;
    }
    final c = Theme.of(context).extension<AppColors>()!;
    final focused = st.focusedSoFar();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('End session?'),
        content: Text(focused > 0
            ? 'Your ${formatDuration(focused)} of focus will be saved as an ended-early session and the timer will stop.'
            : 'The timer will stop. Nothing is recorded yet.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End session', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    _syncLinkName();
    PremiumHaptics.confirm();
    final saved = st.endSession();
    if (saved > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved ${formatDuration(saved)} as ended early.')));
    }
  }

  // ── Sheets ──

  void _openCourseSheet() {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CourseSheet(),
    );
  }

  void _openCustomize() {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CustomizeSheet(),
    );
  }

  void _openSummary() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FocusSummaryScreen()),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.read<FocusState>();
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        elevation: 0,
        title: Text('Focus',
            style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Study summary',
            icon: Icon(Icons.bar_chart_rounded, color: c.textPrimary),
            onPressed: () {
              PremiumHaptics.select();
              _openSummary();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, cons) {
          final landscape = cons.maxWidth > cons.maxHeight;
          final compact = MediaQuery.sizeOf(context).height < 640;
          final gap = compact ? 12.0 : 16.0;

          return ValueListenableBuilder<int>(
            valueListenable: st.struct,
            builder: (context, _, __) {
              final locked = st.active;
              return Column(
                children: [
                  _courseSelector(c, st, locked),
                  SizedBox(height: gap),
                  Expanded(
                    child: _clock(c, st, !reduce, landscape),
                  ),
                  if (st.pendingBreak &&
                      st.phase == FocusPhase.idle)
                    _breakOffer(c, st),
                  SizedBox(height: gap),
                  _presetsRow(c, st, locked),
                  SizedBox(height: gap),
                  _controls(c, st),
                  const SizedBox(height: 8),
                  _todayLine(c, st),
                  // Clear the floating nav bar (68dp) + 12px gap — unless
                  // hidden while the focus timer ticks.
                  SizedBox(
                      height: (st.running && !st.paused) ? 12 : 92),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  Widget _courseSelector(AppColors c, FocusState st, bool locked) {
    final label = _linkLabel(st.linkKind, st.linkId);
    Widget row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(_linkIcon(st.linkKind), color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
          ),
          Icon(Icons.expand_more_rounded, color: c.textSecondary),
        ],
      ),
    );
    if (locked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Opacity(opacity: 0.55, child: IgnorePointer(child: row)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          PremiumHaptics.select();
          _openCourseSheet();
        },
        child: row,
      ),
    );
  }

  Widget _clock(
      AppColors c, FocusState st, bool animated, bool landscape) {
    Widget minutes = FlipCard(
      value: st.minPair,
      animated: animated,
    );
    Widget seconds = FlipCard(
      value: st.secPair,
      animated: animated,
    );
    minutes = ExcludeSemantics(child: minutes);
    seconds = ExcludeSemantics(child: seconds);

    final Widget stack = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: landscape
          ? Row(
              children: [
                Expanded(child: minutes),
                const SizedBox(width: 16),
                Expanded(child: seconds),
              ],
            )
          : Column(
              children: [
                Expanded(child: minutes),
                const SizedBox(height: 16),
                Expanded(child: seconds),
              ],
            ),
    );

    Widget clock = stack;
    if (st.paused) {
      clock = AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 0.6,
        child: stack,
      );
    }
    return ValueListenableBuilder<String>(
      valueListenable: st.semanticsN,
      builder: (context, label, _) => Semantics(
        label: label,
        excludeSemantics: true,
        child: clock,
      ),
    );
  }

  Widget _breakOffer(AppColors c, FocusState st) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Focus complete! Take a ${st.breakMin}-min break?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    PremiumHaptics.select();
                    st.dismissBreakOffer();
                  },
                  child: Text('Skip',
                      style: TextStyle(color: c.textSecondary)),
                ),
                FilledButton(
                  onPressed: () {
                    PremiumHaptics.tap();
                    st.startBreak();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start break'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetsRow(AppColors c, FocusState st, bool locked) {
    Widget chip(String label, bool on, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                PremiumHaptics.select();
                onTap();
              },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? c.accent.withValues(alpha: 0.16)
                : c.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: on ? c.accent : c.border, width: on ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: on ? c.accent : c.textSecondary)),
        ),
      );
    }

    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final p in _presets) ...[
            chip('$p min', st.focusMin == p,
                locked ? null : () => st.setFocusMinutes(p)),
            const SizedBox(width: 8),
          ],
          chip('Customize', false,
              locked ? null : _openCustomize),
        ],
      ),
    );
    if (locked) return Opacity(opacity: 0.55, child: row);
    return row;
  }

  Widget _controls(AppColors c, FocusState st) {
    final idle = st.phase == FocusPhase.idle && !st.active;
    final canEnd = st.active;
    final centerLabel = !st.running
        ? 'Start focus'
        : st.paused
            ? 'Resume'
            : 'Pause';
    final centerIcon = !st.running
        ? Icons.play_arrow_rounded
        : st.paused
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded;

    VoidCallback? restartTap;
    if (idle && !st.pendingBreak) {
      restartTap = null;
    } else if (idle) {
      restartTap = () {
        PremiumHaptics.tap();
        st.restart();
      };
    } else {
      restartTap = _onRestart;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _FocusBtn(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              outlinedColor: c.textPrimary,
              borderColor: c.border,
              onTap: restartTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _FocusBtn(
              icon: centerIcon,
              iconSize: 20,
              label: centerLabel,
              fill: c.accent,
              outlinedColor: Colors.white,
              onTap: () {
                if (!st.running) {
                  _onStart();
                } else if (st.paused) {
                  PremiumHaptics.tap();
                  st.resume();
                } else {
                  PremiumHaptics.tap();
                  st.pause();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FocusBtn(
              icon: Icons.stop_rounded,
              label: 'End',
              outlinedColor: c.overdue,
              borderColor: c.overdue.withValues(alpha: 0.5),
              onTap: !canEnd ? null : _onEnd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayLine(AppColors c, FocusState st) {
    final total = st.totalFocusedSec(
        forLinkKind: st.linkKind,
        forLinkId: st.linkId,
        date: FocusState.todayStr());
    final label =
        st.linkKind == 'none' ? 'free focus' : _linkLabel(st.linkKind, st.linkId);
    return Text(
      'Today in $label: ${formatDuration(total)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: c.textSecondary),
    );
  }
}

/// Focus control button with fixed height and a scale-down label row:
/// at 320dp / large text the content shrinks instead of overflowing.
class _FocusBtn extends StatelessWidget {
  const _FocusBtn({
    required this.icon,
    required this.label,
    required this.outlinedColor,
    this.iconSize = 18,
    this.fill,
    this.borderColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color outlinedColor;
  final double iconSize;
  final Color? fill;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: outlinedColor),
          const SizedBox(width: 6),
          Text(label,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: outlinedColor)),
        ],
      ),
    );
    content = SizedBox(height: 52, child: Center(child: content));
    if (fill != null) {
      return Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap == null
                  ? null
                  : () {
                      onTap!();
                    },
              child: content,
            ),
          ),
        ),
      );
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: borderColor ?? outlinedColor, width: 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// Link picker sheet: None + courses + pending tasks + classes, with
/// search. Empty state routes to the app's course manager instead of
/// inventing its own add flow.
class _CourseSheet extends StatefulWidget {
  const _CourseSheet();

  @override
  State<_CourseSheet> createState() => _CourseSheetState();
}

class _CourseSheetState extends State<_CourseSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.watch<RoutineState>();
    final courses = routine.courses;
    final tasks = context
        .watch<AppState>()
        .tasks
        .where((t) => t.status == TaskStatus.pending)
        .toList();
    final slots = List.of(routine.slots)
      ..sort((a, b) {
        final w = a.weekday.compareTo(b.weekday);
        return w != 0 ? w : a.startMinutes.compareTo(b.startMinutes);
      });
    final st = context.read<FocusState>();

    final q = _q.trim().toLowerCase();
    bool hit(String s) => q.isEmpty || s.toLowerCase().contains(q);
    final fc = courses
        .where((e) =>
            hit(e.name) || hit(e.code ?? ''))
        .toList();
    final ft = tasks
        .where((e) => hit(e.title))
        .take(30)
        .toList();
    final fs = slots.where((s) {
      final course = routine.courseById(s.courseId);
      return hit(course?.name ?? '') ||
          hit(course?.code ?? '') ||
          hit(weekdayShort(s.weekday));
    }).toList();
    final allEmpty = fc.isEmpty && ft.isEmpty && fs.isEmpty;

    String classLabelOf(dynamic s) {
      final course = routine.courseById(s.courseId as String);
      final code = course?.code ?? '';
      final base = course == null
          ? 'Removed course'
          : (code.isNotEmpty ? '$code · ${course.name}' : course.name);
      return '$base · ${weekdayShort(s.weekday as int)} '
          '${slotClock(s.startMinutes as int)}';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('Link this session',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search courses, tasks, classes…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: c.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text('None (free focus)'),
                      trailing: st.linkKind == 'none'
                          ? Icon(Icons.check_rounded, color: c.accent)
                          : null,
                      onTap: () {
                        PremiumHaptics.select();
                        st.selectLink(kind: 'none');
                        Navigator.pop(context);
                      },
                    ),
                    if (fc.isNotEmpty)
                      const _SectionLabel('COURSES'),
                    for (final course in fc)
                      ListTile(
                        leading: Icon(Icons.school_outlined,
                            color: c.accent),
                        title: Text(
                            (course.code ?? '').isNotEmpty
                                ? '${course.code} · ${course.name}'
                                : course.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'course' &&
                                st.linkId == course.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'course', id: course.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (ft.isNotEmpty)
                      const _SectionLabel('TASKS'),
                    for (final task in ft)
                      ListTile(
                        leading: Icon(Icons.assignment_outlined,
                            color: c.accent),
                        title: Text(task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'task' &&
                                st.linkId == task.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'task', id: task.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (fs.isNotEmpty)
                      const _SectionLabel('CLASSES'),
                    for (final slot in fs)
                      ListTile(
                        leading: Icon(Icons.class_outlined,
                            color: c.accent),
                        title: Text(classLabelOf(slot),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'class' &&
                                st.linkId == slot.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'class', id: slot.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (allEmpty) _emptyLinks(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyLinks(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined,
                  color: c.textSecondary, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nothing to link yet. Add your courses first so focus time lands in the right place.',
                  style: TextStyle(
                      fontSize: 14, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                PremiumHaptics.tap();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CoursesScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Add a course',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}

/// Focus/break duration editor (minutes only).
class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet();

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late int _focus;
  late int _breakM;

  @override
  void initState() {
    super.initState();
    final st = context.read<FocusState>();
    _focus = st.focusMin;
    _breakM = st.breakMin;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.read<FocusState>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Custom durations',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _stepRow(c, 'Focus', '$_focus min', _focus, 5, 120,
                (v) => setState(() => _focus = v)),
            _stepRow(c, 'Break', '$_breakM min', _breakM, 1, 30,
                (v) => setState(() => _breakM = v)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  PremiumHaptics.tap();
                  st.setDurations(focus: _focus, breakM: _breakM);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(AppColors c, String label, String value, int v,
      int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            onPressed: () {
              PremiumHaptics.select();
              onChanged((v - 1).clamp(min, max));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              PremiumHaptics.select();
              onChanged((v + 1).clamp(min, max));
            },
          ),
        ],
      ),
    );
  }
}
