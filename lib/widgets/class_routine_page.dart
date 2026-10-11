import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/class_routine.dart';
import '../theme/app_colors.dart';

/// Page 2 of the dashboard pager: weekly class timetable.
///
/// Mini week-grid — day rows (SUN–SAT) against an hour axis, class blocks
/// positioned by start time with width ∝ duration (44px floor, clipped at
/// the next class so neighbours never overlap). Times in 12-hour format.
/// Tap a block to edit. Same card look as the Weekly Load chart.
class ClassRoutinePage extends StatelessWidget {
  const ClassRoutinePage({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
  });

  final List<ClassRoutineEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<ClassRoutineEntry> onEdit;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Class routine',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onAdd();
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: c.accent),
                      const SizedBox(width: 2),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? _EmptyRoutine(onAdd: onAdd)
                : _RoutineGrid(entries: entries, onEdit: onEdit),
          ),
        ],
      ),
    );
  }
}

class _RoutineGrid extends StatelessWidget {
  const _RoutineGrid({required this.entries, required this.onEdit});
  final List<ClassRoutineEntry> entries;
  final ValueChanged<ClassRoutineEntry> onEdit;

  static const double _gutter = 34;
  static const double _rowH = 34;
  static const double _blockH = 27;
  static const double _minBlockW = 44;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    // Hour window: covers 08:00–22:00 minimum, stretches to fit classes.
    var lo = 8 * 60;
    var hi = 22 * 60;
    for (final e in entries) {
      lo = math.min(lo, (ClassRoutineEntry.minutesOf(e.startTime) ~/ 60) * 60);
      hi = math.max(
          hi,
          ((ClassRoutineEntry.minutesOf(e.endTime) + 59) ~/ 60) * 60);
    }
    if (hi - lo < 6 * 60) hi = lo + 6 * 60;

    final today = DateTime.now().weekday - 1;
    final byDay = <int, List<ClassRoutineEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.dayOfWeek, () => []).add(e);
    }

    return LayoutBuilder(
      builder: (context, cons) {
        final tw = math.max(80.0, cons.maxWidth - _gutter);
        double xPos(int mins) => (mins - lo) / (hi - lo) * tw;

        final hours = <int>[];
        for (var h = lo ~/ 60; h * 60 <= hi; h++) {
          hours.add(h);
        }
        final step = (hi - lo) > 8 * 60 ? 2 : 1;

        return Column(
          children: [
            // Hour axis.
            SizedBox(
              height: 15,
              child: Row(
                children: [
                  const SizedBox(width: _gutter),
                  Expanded(
                    child: Stack(
                      children: [
                        for (var i = 0; i < hours.length; i++)
                          if ((hours[i] - hours.first) % step == 0)
                            Positioned(
                              left: (xPos(hours[i] * 60) - 12)
                                  .clamp(0.0, math.max(0.0, tw - 24)),
                              width: 24,
                              child: Text(
                                _hourLabel(hours[i]),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: c.textTertiary,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Day rows.
            for (var d = 0; d < 7; d++)
              Container(
                height: _rowH,
                decoration: BoxDecoration(
                  color: d == today
                      ? c.accentLight
                      : (d.isOdd
                          ? c.inputBg.withValues(alpha: 0.45)
                          : null),
                  border: Border(
                    bottom: BorderSide(color: c.borderLight, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: _gutter,
                      child: Text(
                        ClassRoutineEntry.dayShort[d]
                            .substring(0, 3)
                            .toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: d == today ? c.accent : c.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          // Hour hairlines.
                          for (final h in hours)
                            Positioned(
                              left: xPos(h * 60),
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 1,
                                color: c.borderLight.withValues(alpha: 0.7),
                              ),
                            ),
                          // Class blocks.
                          ..._blocksForDay(
                              byDay[d] ?? const [], xPos, tw, c),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _blocksForDay(
    List<ClassRoutineEntry> dayEntries,
    double Function(int mins) xPos,
    double tw,
    AppColors c,
  ) {
    if (dayEntries.isEmpty) return const [];
    final sorted = List.of(dayEntries)
      ..sort((a, b) => ClassRoutineEntry.minutesOf(a.startTime)
          .compareTo(ClassRoutineEntry.minutesOf(b.startTime)));

    final out = <Widget>[];
    for (var i = 0; i < sorted.length; i++) {
      final e = sorted[i];
      final s = ClassRoutineEntry.minutesOf(e.startTime);
      final en = ClassRoutineEntry.minutesOf(e.endTime);
      final bx = xPos(s).clamp(0.0, tw);
      final natural = math.max(_minBlockW, xPos(en) - bx);
      final limit = i + 1 < sorted.length
          ? xPos(ClassRoutineEntry.minutesOf(sorted[i + 1].startTime))
          : tw;
      var right = math.min(bx + natural, limit);
      if (right - bx < 26) right = math.min(bx + 26, tw);
      final w = math.max(20.0, right - bx);
      final showRoom = (e.room ?? '').isNotEmpty && w >= 84;

      out.add(
        Positioned(
          left: bx,
          top: (_rowH - _blockH) / 2,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onEdit(e);
            },
            child: Container(
              width: w,
              height: _blockH,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: c.cardBgRaised,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: c.accent, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: c.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _compactRange(s, en),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 8,
                            height: 1.1,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      if (showRoom) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.place_outlined,
                            size: 8, color: c.textTertiary),
                        Flexible(
                          child: Text(
                            e.room!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: c.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return out;
  }

  /// Compact 12h axis label: 8 → "8a", 12 → "12p", 15 → "3p", 22 → "10p".
  String _hourLabel(int h24) {
    final period = h24 >= 12 ? 'p' : 'a';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12$period';
  }

  /// "3:00–4:20 PM" (single period) or "11:00 AM–12:30 PM" (cross-meridiem).
  String _compactRange(int s, int e) {
    String part(int mins, bool withPeriod) {
      final h24 = mins ~/ 60;
      final m = (mins % 60).toString().padLeft(2, '0');
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final p = h24 >= 12 ? 'PM' : 'AM';
      return withPeriod ? '$h12:$m $p' : '$h12:$m';
    }

    final samePeriod = (s ~/ 720) == (e ~/ 720);
    final endPeriod = (e ~/ 60) >= 12 ? 'PM' : 'AM';
    if (samePeriod) {
      final h = (s ~/ 60) % 12 == 0 ? 12 : (s ~/ 60) % 12;
      final m = (s % 60).toString().padLeft(2, '0');
      final eh = (e ~/ 60) % 12 == 0 ? 12 : (e ~/ 60) % 12;
      final em = (e % 60).toString().padLeft(2, '0');
      return '$h:$m–$eh:$em $endPeriod';
    }
    return '${part(s, true)}–${part(e, true)}';
  }
}

class _EmptyRoutine extends StatelessWidget {
  const _EmptyRoutine({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_outlined, size: 36, color: c.textTertiary),
          const SizedBox(height: 8),
          Text(
            'No classes yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your weekly class schedule.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onAdd();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Add Class Routine',
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
