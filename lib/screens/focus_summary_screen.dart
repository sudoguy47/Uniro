import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../domain/focus_logic.dart';
import '../domain/haptics.dart';
import '../models/focus_session.dart';
import '../state/app_state.dart';
import '../state/focus_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';

enum _Range { today, week, all }

/// Human-readable screen-time duration format: e.g. "2 hrs, 59 mins", "45 mins", "0 mins"
String formatScreenTime(int totalSeconds) {
  final m = (totalSeconds / 60).round();
  if (m == 0) return '0 mins';
  final h = m ~/ 60;
  final rm = m % 60;
  if (h == 0) return '$rm min${rm == 1 ? '' : 's'}';
  if (rm == 0) return '$h hr${h == 1 ? '' : 's'}';
  return '$h hr${h == 1 ? '' : 's'}, $rm min${rm == 1 ? '' : 's'}';
}

/// Android Digital Wellbeing / Battery style Study Summary screen.
class FocusSummaryScreen extends StatefulWidget {
  const FocusSummaryScreen({super.key});

  @override
  State<FocusSummaryScreen> createState() => _FocusSummaryScreenState();
}

class _FocusSummaryScreenState extends State<FocusSummaryScreen> {
  _Range _range = _Range.today;
  String? _selectedDate; // specific day selected from the bar chart

  @override
  void initState() {
    super.initState();
    _selectedDate = FocusState.todayStr();
  }

  String _linkName(RoutineState routine, AppState app, FocusSession s) {
    switch (s.linkKind) {
      case 'course':
        final live = s.linkId == null ? null : routine.courseById(s.linkId!);
        if (live == null) {
          return s.linkName.isEmpty ? 'Removed course' : '${s.linkName} · removed';
        }
        final code = live.code ?? '';
        return code.isNotEmpty ? '$code · ${live.name}' : live.name;
      case 'task':
        try {
          return app.tasks.firstWhere((e) => e.id == s.linkId).title;
        } catch (_) {
          return s.linkName.isEmpty ? 'Removed task' : '${s.linkName} · removed';
        }
      case 'class':
        for (final slot in routine.slots) {
          if (slot.id == s.linkId) {
            final course = routine.courseById(slot.courseId);
            final code = course?.code ?? '';
            final base = course == null
                ? 'Removed course'
                : (code.isNotEmpty ? '$code · ${course.name}' : course.name);
            return '$base · ${weekdayShort(slot.weekday)} '
                '${slotClock(slot.startMinutes)}';
          }
        }
        return s.linkName.isEmpty ? 'Removed class' : '${s.linkName} · removed';
      default:
        return 'Free focus';
    }
  }

  IconData _linkIcon(String kind) => switch (kind) {
        'course' => Icons.school_outlined,
        'task' => Icons.assignment_outlined,
        'class' => Icons.class_outlined,
        _ => Icons.timer_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.watch<FocusState>();
    final routine = context.watch<RoutineState>();
    final app = context.watch<AppState>();

    final today = FocusState.todayStr();
    final now = DateTime.now();

    // Monday-based week for Screen Time style chart
    final monday = now.subtract(Duration(days: (now.weekday - 1 + 7) % 7));
    final weekStartStr = focusYmd(monday);

    final weekDates = List<String>.generate(7, (i) {
      final d = DateTime(monday.year, monday.month, monday.day).add(Duration(days: i));
      return focusYmd(d);
    });

    final Map<String, int> dailySeconds = {};
    for (final dateStr in weekDates) {
      dailySeconds[dateStr] = st.totalFocusedSec(date: dateStr);
    }

    // Determine query scope based on range or selected date
    String? queryDate;
    String? queryWeekStart;

    if (_range == _Range.today) {
      queryDate = _selectedDate ?? today;
    } else if (_range == _Range.week) {
      if (_selectedDate != null) {
        queryDate = _selectedDate;
      } else {
        queryWeekStart = weekStartStr;
      }
    } else {
      // all time
      queryDate = null;
      queryWeekStart = null;
    }

    final totalSec = st.totalFocusedSec(date: queryDate, weekStart: queryWeekStart);
    final count = st.sessionCount(date: queryDate, weekStart: queryWeekStart);
    final sessions = st.history(date: queryDate, weekStart: queryWeekStart);

    // Group newest-first history by display link name
    final groups = <String, List<FocusSession>>{};
    for (final s in sessions) {
      final name = _linkName(routine, app, s);
      groups.putIfAbsent(name, () => []).add(s);
    }

    // Header label for the Screen Time card
    String headlineDuration;
    String subLabel;

    if (_range == _Range.all && _selectedDate == null) {
      headlineDuration = formatScreenTime(totalSec);
      subLabel = 'All time';
    } else if (_selectedDate != null) {
      headlineDuration = formatScreenTime(dailySeconds[_selectedDate] ?? totalSec);
      if (_selectedDate == today) {
        subLabel = 'Today';
      } else {
        try {
          final parsed = DateTime.parse(_selectedDate!);
          subLabel = DateFormat('EEE, MMM d').format(parsed);
        } catch (_) {
          subLabel = _selectedDate!;
        }
      }
    } else {
      headlineDuration = formatScreenTime(totalSec);
      subLabel = 'This week';
    }

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        elevation: 0,
        title: Text(
          'Study summary',
          style: TextStyle(
            color: c.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Filter pills
          _filters(c, today),
          const SizedBox(height: 14),

          // Android Screen Time / Battery style Bar Chart Card
          _ScreenTimeChartCard(
            headlineDuration: headlineDuration,
            subLabel: subLabel,
            weekDates: weekDates,
            dailySeconds: dailySeconds,
            selectedDate: _selectedDate,
            todayDate: today,
            onSelectDate: (d) {
              PremiumHaptics.select();
              setState(() {
                if (_selectedDate == d && _range == _Range.week) {
                  _selectedDate = null; // deselect to view whole week
                } else {
                  _selectedDate = d;
                }
              });
            },
          ),
          const SizedBox(height: 16),

          // Mini stats row
          _totals(c, totalSec, count),
          const SizedBox(height: 16),

          // Sessions Breakdown
          if (sessions.isEmpty)
            _empty(c)
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'SESSIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: c.textSecondary,
                ),
              ),
            ),
            for (final entry in groups.entries) ...[
              _groupHeader(c, entry.key, entry.value.first.linkKind, entry.value),
              const SizedBox(height: 8),
              for (final s in entry.value) _sessionRow(c, s),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filters(AppColors c, String today) {
    Widget chip(String label, _Range r) {
      final on = _range == r;
      return GestureDetector(
        onTap: () {
          PremiumHaptics.tap();
          setState(() {
            _range = r;
            if (r == _Range.today) {
              _selectedDate = today;
            } else if (r == _Range.all) {
              _selectedDate = null;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: on ? c.accent.withValues(alpha: 0.16) : c.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on ? c.accent : c.border,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: on ? c.accent : c.textSecondary,
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _stat(c, formatDuration(totalSec), 'Total Focused'),
          ),
          Container(width: 1, height: 32, color: c.border),
          Expanded(
            child: _stat(c, '$count', 'Session${count == 1 ? '' : 's'}'),
          ),
        ],
      ),
    );
  }

  Widget _stat(AppColors c, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: c.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
      ],
    );
  }

  Widget _empty(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_outlined, size: 40, color: c.textSecondary),
          const SizedBox(height: 10),
          Text(
            'No sessions here yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Finish a focus session and it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
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
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
        ),
        Text(
          '${formatDuration(total)} · ${list.length}',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        ),
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
                Text(
                  formatDuration(s.focusedSec),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.isEmpty
                      ? 'Planned ${formatDuration(s.plannedSec)}'
                      : '${label.toString()} · planned ${formatDuration(s.plannedSec)}',
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (s.completed ? c.upcoming : c.dueToday).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              s.completed ? 'Done' : 'Ended early',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: s.completed ? c.upcoming : c.dueToday,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Android Digital Wellbeing / Battery style Screen Time Chart Card
class _ScreenTimeChartCard extends StatelessWidget {
  const _ScreenTimeChartCard({
    required this.headlineDuration,
    required this.subLabel,
    required this.weekDates,
    required this.dailySeconds,
    required this.selectedDate,
    required this.todayDate,
    required this.onSelectDate,
  });

  final String headlineDuration;
  final String subLabel;
  final List<String> weekDates;
  final Map<String, int> dailySeconds;
  final String? selectedDate;
  final String todayDate;
  final ValueChanged<String> onSelectDate;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    // Max hours calculation: minimum 3h baseline matching Android Screen Time
    final maxSec = dailySeconds.values.fold(0, math.max);
    final calculatedHours = (maxSec / 3600).ceil();
    final maxHours = math.max(3, calculatedHours);

    // 4 guide levels: e.g. 3h, 2h, 1h, 0h
    final stepH = maxHours / 3.0;
    final yLabels = [
      '${maxHours}h',
      '${(stepH * 2).round()}h',
      '${(stepH).round()}h',
      '0h',
    ];

    const chartHeight = 150.0;
    const barAreaHeight = 120.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Large Screen Time Headline
          Text(
            headlineDuration,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Chart with horizontal grid lines and vertical bars
          SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                // 4 Horizontal Guide Lines with Labels on the Right
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: c.border.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 26,
                          child: Text(
                            yLabels[index],
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: c.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                // 7 Day Bars
                Padding(
                  padding: const EdgeInsets.only(right: 34, bottom: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final dateStr = weekDates[i];
                      final sec = dailySeconds[dateStr] ?? 0;
                      final isSelected = selectedDate == dateStr;

                      // Height based on maxHours
                      final ratio = (sec / (maxHours * 3600)).clamp(0.0, 1.0);
                      final barHeight = ratio > 0 ? math.max(6.0, ratio * barAreaHeight) : 0.0;

                      // Android Screen Time Blue / Accent color
                      final barColor = isSelected
                          ? const Color(0xFF3872E0)
                          : const Color(0xFF4C84F3).withValues(alpha: sec > 0 ? 0.85 : 0.0);

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelectDate(dateStr),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // The Bar
                              Container(
                                width: 28,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                  border: isSelected
                                      ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // Day Labels Below Baseline
                Positioned(
                  left: 0,
                  right: 34,
                  bottom: 0,
                  child: Row(
                    children: List.generate(7, (i) {
                      final dateStr = weekDates[i];
                      final isSelected = selectedDate == dateStr;
                      final isToday = todayDate == dateStr;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelectDate(dateStr),
                          child: Text(
                            _dayLabels[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF3872E0)
                                  : (isToday ? c.textPrimary : c.textSecondary),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
