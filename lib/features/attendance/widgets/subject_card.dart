import 'package:flutter/material.dart';
import '../../../domain/attendance_logic.dart';
import '../../../models/attendance_record.dart';
import '../../../theme/app_colors.dart';
import '../logic/attendance_helpers.dart';

class SubjectAttendanceCard extends StatelessWidget {
  const SubjectAttendanceCard({
    super.key,
    required this.summary,
    required this.minPercent,
    required this.onIncrement,
    required this.onDecrement,
    required this.onQuickMark,
    required this.onLogForCourse,
  });

  final SubjectAttendanceSummary summary;
  final int minPercent;
  final void Function(SubjectAttendanceSummary summary) onIncrement;
  final void Function(SubjectAttendanceSummary summary) onDecrement;
  final void Function(SubjectAttendanceSummary summary, AttendanceStatus status) onQuickMark;
  final void Function(SubjectAttendanceSummary summary) onLogForCourse;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final pct = summary.percentage;
    final ok = summary.total == 0 || pct >= minPercent;

    final badgeColor = summary.total == 0
        ? c.textTertiary
        : (ok ? const Color(0xFF4E9A68) : const Color(0xFFD97757));
    final badgeBg = summary.total == 0
        ? c.inputBg
        : (ok
            ? const Color(0xFF4E9A68).withValues(alpha: 0.14)
            : const Color(0xFFD97757).withValues(alpha: 0.14));

    final icon = AttendanceHelpers.iconForSubject(summary.courseName, summary.courseCode);
    final subjectColor = summary.colorTag != null
        ? Color(summary.colorTag!)
        : (ok ? c.accent : const Color(0xFFD97757));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: c.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Subject Icon, Name & Code, Percentage Badge ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: subjectColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: subjectColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    if (summary.courseCode.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        summary.courseCode.trim(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.textTertiary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  summary.total == 0 ? '0%' : '${pct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Attended Stats & Status ──
          Row(
            children: [
              Text(
                summary.total == 0
                    ? '0 classes recorded yet'
                    : '${summary.attended}/${summary.total} attended · ${summary.missed} missed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                summary.statusMessage(minPercent),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Smooth Gradient Progress Bar ──
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 6,
              width: double.infinity,
              color: c.inputBg,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor:
                    summary.total == 0 ? 0.0 : (pct / 100).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: ok
                          ? [c.accent, const Color(0xFF4E9A68)]
                          : [const Color(0xFFD97757), c.accent],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Manual Attendance Controls Row ──
          Row(
            children: [
              // Stepper: [-] count [+]
              Container(
                height: 38,
                decoration: BoxDecoration(
                  color: c.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border.withValues(alpha: 0.7)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => onDecrement(summary),
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10)),
                      child: Container(
                        width: 36,
                        height: 38,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.remove_rounded,
                          size: 18,
                          color: summary.attended > 0
                              ? c.textPrimary
                              : c.textTertiary,
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      child: Text(
                        '${summary.attended}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => onIncrement(summary),
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(10)),
                      child: Container(
                        width: 36,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Missed button
              Expanded(
                child: InkWell(
                  onTap: () => onQuickMark(summary, AttendanceStatus.absent),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: c.inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: c.border.withValues(alpha: 0.6)),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded,
                            size: 14, color: c.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          'Missed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Calendar button for date-specific entry
              InkWell(
                onTap: () => onLogForCourse(summary),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c.border.withValues(alpha: 0.6)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.calendar_month_outlined,
                      size: 16, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
