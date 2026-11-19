import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';

class AttendanceDateBadge extends StatelessWidget {
  const AttendanceDateBadge({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final d = DateTime.tryParse(date);
    final day = d != null ? d.day.toString().padLeft(2, '0') : '--';
    final mon = d != null ? DateFormat('MMM').format(d).toUpperCase() : '';
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              height: 1.1,
            ),
          ),
          Text(
            mon,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
