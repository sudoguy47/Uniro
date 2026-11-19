import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../models/attendance_record.dart';
import '../../../theme/app_colors.dart';
import '../logic/attendance_helpers.dart';
import 'date_badge.dart';
import 'status_chip.dart';

class AttendanceHistoryList extends StatelessWidget {
  const AttendanceHistoryList({
    super.key,
    required this.records,
    required this.filter,
    required this.onTapRecord,
  });

  final List<AttendanceRecord> records;
  final String? filter;
  final ValueChanged<AttendanceRecord> onTapRecord;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final filtered = (filter == null
            ? records
            : records.where((r) => r.courseId == filter).toList())
        .toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        return b.startMinutes.compareTo(a.startMinutes);
      });
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No records for this subject',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final r in filtered)
          GestureDetector(
            onTap: () {
              PremiumHaptics.tap();
              onTapRecord(r);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Row(
                children: [
                  AttendanceDateBadge(date: r.date),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.courseName.isNotEmpty ? r.courseName : 'Unknown subject',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AttendanceHelpers.timeRange(r),
                          style: TextStyle(
                              fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceStatusChip(status: r.status),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
