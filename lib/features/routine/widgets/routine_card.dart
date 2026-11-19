import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../models/class_slot.dart';
import '../../../models/course.dart';
import '../../../theme/app_colors.dart';

/// Day class card with Now badge / dimmed-finished + shrink-fade delete-out.
class RoutineCard extends StatefulWidget {
  const RoutineCard({
    super.key,
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
  State<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends State<RoutineCard>
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
  void didUpdateWidget(covariant RoutineCard old) {
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
