import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'percent_ring.dart';

class OverallStatsCard extends StatelessWidget {
  const OverallStatsCard({
    super.key,
    required this.percentage,
    required this.attended,
    required this.total,
    required this.missed,
    required this.minPercent,
    required this.targetColor,
    required this.canBunkCount,
    required this.needCount,
    required this.onOpenTargetSheet,
  });

  final double percentage;
  final int attended;
  final int total;
  final int missed;
  final int minPercent;
  final Color targetColor;
  final int canBunkCount;
  final int needCount;
  final VoidCallback onOpenTargetSheet;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: double.infinity,
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
            children: [
              PercentRing(
                percent: percentage,
                color: targetColor,
                size: 88,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overall Attendance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$attended/$total classes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '$missed missed',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Target Setter Button
                        InkWell(
                          onTap: onOpenTargetSheet,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: c.accent.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.track_changes_rounded,
                                    size: 13, color: c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Target $minPercent%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: c.accent,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.edit_rounded,
                                    size: 11, color: c.accent),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Actionable status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  total == 0
                      ? Icons.info_outline_rounded
                      : (percentage >= minPercent
                          ? Icons.verified_rounded
                          : Icons.warning_amber_rounded),
                  size: 16,
                  color: targetColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    total == 0
                        ? 'Tap "+" or "Log Class" to start tracking attendance.'
                        : (percentage >= minPercent
                            ? (canBunkCount > 0
                                ? 'Safe to skip $canBunkCount class${canBunkCount == 1 ? '' : 'es'} while maintaining $minPercent%.'
                                : 'On track! Attend next class to stay at $minPercent%.')
                            : 'Attend $needCount more consecutive class${needCount == 1 ? '' : 'es'} to reach $minPercent%.'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
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
