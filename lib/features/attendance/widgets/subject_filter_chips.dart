import 'package:flutter/material.dart';
import '../../../domain/attendance_logic.dart';
import '../../../theme/app_colors.dart';

class SubjectFilterChips extends StatelessWidget {
  const SubjectFilterChips({
    super.key,
    required this.summaries,
    required this.selected,
    required this.onChanged,
  });

  final List<SubjectAttendanceSummary> summaries;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            active: selected == null,
            onTap: () => onChanged(null),
            colors: c,
          ),
          for (final s in summaries)
            _FilterChip(
              label: s.courseCode.trim().isNotEmpty
                  ? s.courseCode
                  : s.courseName,
              active: selected == s.courseId,
              onTap: () => onChanged(
                  selected == s.courseId ? null : s.courseId),
              colors: c,
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? c.navActiveBg : c.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? c.navActiveBg : c.border),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? c.navActiveText : c.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
