import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/class_slot.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';

/// Compact "next class today" card. Hidden when no class is left today.
///
/// The live countdown ("in 45 min" / "Now · ends in 20 min") refreshes once
/// per minute from a single Timer owned by this card (cancelled on dispose).
class NextClassCard extends StatefulWidget {
  const NextClassCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static String _dur(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.watch<RoutineState>();
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    ClassSlot? next;
    for (final s in routine.slotsForWeekday(now.weekday)) {
      if (s.endMinutes > nowMin) {
        next = s;
        break;
      }
    }
    if (next == null) return const SizedBox.shrink();
    final slot = next;

    final course = routine.courseById(slot.courseId);
    final running = slot.startMinutes <= nowMin;
    final label = running
        ? 'Now · ends in ${_dur(slot.endMinutes - nowMin)}'
        : 'in ${_dur(slot.startMinutes - nowMin)}';
    final title = course == null
        ? 'Class'
        : ((course.code ?? '').isNotEmpty
            ? '${course.code} · ${course.name}'
            : course.name);
    final room =
        (slot.room ?? course?.room ?? '').trim();

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.navActiveBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT CLASS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: c.navActiveText.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: c.navActiveText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmt(slot.startMinutes, context)} – ${_fmt(slot.endMinutes, context)}'
                        '${room.isNotEmpty ? ' · $room' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: c.navActiveText.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(int mins, BuildContext context) {
    final t = TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    return t.format(context);
  }
}
