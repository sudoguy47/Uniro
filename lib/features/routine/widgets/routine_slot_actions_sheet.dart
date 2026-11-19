import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/attendance_record.dart';
import '../../../models/class_slot.dart';
import '../../../models/course.dart';
import '../../../screens/attendance_screen.dart';
import '../../../state/attendance_state.dart';
import '../../../theme/app_colors.dart';
import 'attendance_mark_button.dart';

class RoutineSlotActionsSheet {
  RoutineSlotActionsSheet._();

  static void show({
    required BuildContext context,
    required ClassSlot slot,
    required Course? course,
    required String dateStr,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    final c = Theme.of(context).extension<AppColors>()!;
    final attendance = context.read<AttendanceState>();
    final att = attendance.statusFor(slot.id, dateStr);
    showModalBottomSheet<void>(
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
            ListTile(
              leading: Icon(Icons.edit_outlined, color: c.textSecondary),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: c.overdue),
              title: Text('Delete', style: TextStyle(color: c.overdue)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete();
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Did you attend this class?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AttendanceScreen(),
                            ),
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 2, horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View logs',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.accent,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 10, color: c.accent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: AttendanceMarkButton(
                          label: 'Attended',
                          icon: Icons.check_circle_rounded,
                          active: att == 'attended',
                          onTap: () {
                            attendance.mark(
                              slotId: slot.id,
                              date: dateStr,
                              status: AttendanceStatus.attended,
                              startMinutes: slot.startMinutes,
                              endMinutes: slot.endMinutes,
                              courseId: course?.id ?? slot.courseId,
                              courseName: course?.name ?? 'Class',
                              courseCode: course?.code ?? '',
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AttendanceMarkButton(
                          label: 'Missed',
                          icon: Icons.cancel_rounded,
                          active: att == 'absent',
                          onTap: () {
                            attendance.mark(
                              slotId: slot.id,
                              date: dateStr,
                              status: AttendanceStatus.absent,
                              startMinutes: slot.startMinutes,
                              endMinutes: slot.endMinutes,
                              courseId: course?.id ?? slot.courseId,
                              courseName: course?.name ?? 'Class',
                              courseCode: course?.code ?? '',
                            );
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ],
                  ),
                  if (att != null) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          attendance.clear(slotId: slot.id, date: dateStr);
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'Clear mark',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
