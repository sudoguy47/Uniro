import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/focus_logic.dart';
import '../models/focus_session.dart';
import '../state/app_state.dart';
import '../state/focus_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';

enum _Range { today, week, all }

/// Course-wise study summary: filter chips, totals, and session history
/// grouped by course. History survives renames (live name preferred) and
/// deletes (snapshot fallback).
class FocusSummaryScreen extends StatefulWidget {
  const FocusSummaryScreen({super.key});

  @override
  State<FocusSummaryScreen> createState() => _FocusSummaryScreenState();
}

class _FocusSummaryScreenState extends State<FocusSummaryScreen> {
  _Range _range = _Range.today;

  String _linkName(
      RoutineState routine, AppState app, FocusSession s) {
    switch (s.linkKind) {
      case 'course':
        final live = s.linkId == null
            ? null
            : routine.courseById(s.linkId!);
        if (live == null) {
          return s.linkName.isEmpty
              ? 'Removed course'
              : '${s.linkName} · removed';
        }
        final code = live.code ?? '';
        return code.isNotEmpty ? '$code · ${live.name}' : live.name;
      case 'task':
        try {
          return app.tasks.firstWhere((e) => e.id == s.linkId).title;
        } catch (_) {
          return s.linkName.isEmpty
              ? 'Removed task'
              : '${s.linkName} · removed';
        }
      case 'class':
        for (final slot in routine.slots) {
          if (slot.id == s.linkId) {
            final course = routine.courseById(slot.courseId);
            final code = course?.code ?? '';
            final base = course == null
                ? 'Removed course'
                : (code.isNotEmpty
                    ? '$code · ${course.name}'
                    : course.name);
            return '$base · ${weekdayShort(slot.weekday)} '
                '${slotClock(slot.startMinutes)}';
          }
        }
        return s.linkName.isEmpty
            ? 'Removed class'
            : '${s.linkName} · removed';
      default:
        return 'Free focus';
    }
  }

  IconData _linkIcon(String kind) => switch (kind) {
        'course' => Icons.school_outlined,
        'task' => Icons.assignment_outlined,
        'class' => Icons.class_outlined,
        _ => Icons.block_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.watch<FocusState>();
    final routine = context.watch<RoutineState>();
    final app = context.watch<AppState>();
    final today = FocusState.todayStr();
    final week = weekStartMonday(DateTime.now());

    final String? date = _range == _Range.today ? today : null;
    final String? weekStart = _range == _Range.week ? week : null;

    final totalSec =
        st.totalFocusedSec(date: date, weekStart: weekStart);
    final count = st.sessionCount(date: date, weekStart: weekStart);
    final sessions = st.history(date: date, weekStart: weekStart);

    // Group newest-first history by display link name.
    final groups = <String, List<FocusSession>>{};
    for (final s in sessions) {
      final name = _linkName(routine, app, s);
      groups.putIfAbsent(name, () => []).add(s);
    }

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        elevation: 0,
        title: Text('Study summary',
            style: TextStyle(
                color: c.textPrimary, fontWeight: FontWeight.w800)),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _filters(c),
          const SizedBox(height: 12),
          _totals(c, totalSec, count),
          const SizedBox(height: 16),
          if (sessions.isEmpty)
            _empty(c)
          else
            for (final entry in groups.entries) ...[
              _groupHeader(c, entry.key, entry.value.first.linkKind,
                  entry.value),
              const SizedBox(height: 8),
              for (final s in entry.value) _sessionRow(c, s),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _filters(AppColors c) {
    Widget chip(String label, _Range r) {
      final on = _range == r;
      return GestureDetector(
        onTap: () => setState(() => _range = r),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: on ? c.accent.withValues(alpha: 0.16) : c.cardBg,
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Today', _Range.today),
        chip('This week', _Range.week),
        chip('All time', _Range.all),
      ],
    );
  }

  Widget _totals(AppColors c, int totalSec, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(c, formatDuration(totalSec), 'Focused'),
          ),
          Container(width: 1, height: 36, color: c.border),
          Expanded(
            child: _stat(c, '$count',
                'Session${count == 1 ? '' : 's'}'),
          ),
        ],
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }

  Widget _empty(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_outlined, size: 40, color: c.textSecondary),
          const SizedBox(height: 10),
          Text('No sessions here yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('Finish a focus session and it will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
      ),
    );
  }

  Widget _groupHeader(
      AppColors c, String name, String kind, List<FocusSession> list) {
    var total = 0;
    for (final s in list) {
      total += s.focusedSec;
    }
    return Row(
      children: [
        Icon(_linkIcon(kind), size: 16, color: c.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary)),
        ),
        Text('${formatDuration(total)} · ${list.length}',
            style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }

  Widget _sessionRow(AppColors c, FocusSession s) {
    final label = StringBuffer(focusStartLabel(s.startedAt));
    if (s.date != FocusState.todayStr() && s.date.isNotEmpty) {
      if (label.isNotEmpty) label.write(' · ');
      label.write(s.date);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDuration(s.focusedSec),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                    label.isEmpty
                        ? 'Planned ${formatDuration(s.plannedSec)}'
                        : '${label.toString()} · planned ${formatDuration(s.plannedSec)}',
                    style: TextStyle(
                        fontSize: 12, color: c.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (s.completed ? c.upcoming : c.dueToday)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(s.completed ? 'Done' : 'Ended early',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color:
                        s.completed ? c.upcoming : c.dueToday)),
          ),
        ],
      ),
    );
  }
}
