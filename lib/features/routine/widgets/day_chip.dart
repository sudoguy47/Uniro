import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// Day chip: short name + date; selected = 200ms animated pill.
class DayChip extends StatelessWidget {
  const DayChip({
    super.key,
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
