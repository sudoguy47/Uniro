import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/attendance_record.dart';
import '../../../state/attendance_state.dart';
import '../../../theme/app_colors.dart';
import 'status_chip.dart';

class RecordOptionsSheet {
  RecordOptionsSheet._();

  static Future<void> show({
    required BuildContext context,
    required AttendanceRecord record,
  }) async {
    final c = Theme.of(context).extension<AppColors>()!;
    final attendance = context.read<AttendanceState>();
    final date = DateTime.tryParse(record.date);
    final dateLabel = date != null
        ? DateFormat('EEE, MMM d, yyyy').format(date)
        : record.date;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.courseName.isNotEmpty
                              ? record.courseName
                              : 'Unknown subject',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(
                              fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  AttendanceStatusChip(status: record.status),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: c.upcoming),
              title: const Text('Mark attended'),
              onTap: () {
                attendance.mark(
                  slotId: record.slotId,
                  date: record.date,
                  status: AttendanceStatus.attended,
                  startMinutes: record.startMinutes,
                  endMinutes: record.endMinutes,
                  courseId: record.courseId,
                  courseName: record.courseName,
                  courseCode: record.courseCode,
                );
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: c.overdue),
              title: const Text('Mark missed'),
              onTap: () {
                attendance.mark(
                  slotId: record.slotId,
                  date: record.date,
                  status: AttendanceStatus.absent,
                  startMinutes: record.startMinutes,
                  endMinutes: record.endMinutes,
                  courseId: record.courseId,
                  courseName: record.courseName,
                  courseCode: record.courseCode,
                );
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.textSecondary),
              title: Text('Remove record',
                  style: TextStyle(color: c.textSecondary)),
              onTap: () {
                attendance.clearById(record.id);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
