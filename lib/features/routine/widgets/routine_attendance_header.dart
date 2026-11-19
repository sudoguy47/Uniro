import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../screens/attendance_screen.dart';
import '../../../theme/app_colors.dart';

class RoutineAttendanceHeader extends StatelessWidget {
  const RoutineAttendanceHeader({
    super.key,
    required this.attTotal,
    required this.attAttended,
    required this.attMissed,
    required this.attPercentage,
    required this.targetColor,
  });

  final int attTotal;
  final int attAttended;
  final int attMissed;
  final double attPercentage;
  final Color targetColor;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            PremiumHaptics.tap();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AttendanceScreen(),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.fact_check_rounded,
                                color: c.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: c.textPrimary,
                                  ),
                                ),
                                Text(
                                  attTotal == 0
                                      ? 'No attendance recorded yet'
                                      : '$attAttended attended • $attMissed missed',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${attPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: targetColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: c.textTertiary),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: attTotal == 0
                        ? 0.0
                        : (attPercentage / 100.0)
                            .clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: c.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(targetColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
