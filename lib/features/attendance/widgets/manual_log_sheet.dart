import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../domain/haptics.dart';
import '../../../models/attendance_record.dart';
import '../../../models/course.dart';
import '../../../state/attendance_state.dart';
import '../../../theme/app_colors.dart';
import '../logic/attendance_helpers.dart';
import 'quick_date_button.dart';

class ManualLogSheet {
  ManualLogSheet._();

  static Future<void> show({
    required BuildContext context,
    required List<Course> courses,
    String? preselectedCourseId,
  }) async {
    PremiumHaptics.select();
    final c = Theme.of(context).extension<AppColors>()!;
    final attendance = context.read<AttendanceState>();

    String selectedCourseId = preselectedCourseId ??
        (courses.isNotEmpty ? courses.first.id : '');
    final customSubjectCtrl = TextEditingController();
    var selectedStatus = AttendanceStatus.attended;
    var selectedDate = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Log Class Attendance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manually record a class as attended or missed.',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // ── Course Selection ──
                    Text(
                      'Select Course / Subject',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (courses.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: courses.map((course) {
                          final active = selectedCourseId == course.id;
                          final label = course.code?.trim().isNotEmpty == true
                              ? '${course.code} · ${course.name}'
                              : course.name;
                          return ChoiceChip(
                            label: Text(label),
                            selected: active,
                            selectedColor: c.accent,
                            backgroundColor: c.inputBg,
                            labelStyle: TextStyle(
                              color: active ? Colors.white : c.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setSheetState(() => selectedCourseId = course.id);
                            },
                          );
                        }).toList(),
                      )
                    else
                      TextField(
                        controller: customSubjectCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Computer Science, Math',
                          filled: true,
                          fillColor: c.inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c.border),
                          ),
                        ),
                      ),

                    const SizedBox(height: 18),

                    // ── Date Selection ──
                    Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        QuickDateButton(
                          label: 'Today',
                          active: AttendanceHelpers.isSameDay(selectedDate, DateTime.now()),
                          onTap: () => setSheetState(() => selectedDate = DateTime.now()),
                          colors: c,
                        ),
                        const SizedBox(width: 8),
                        QuickDateButton(
                          label: 'Yesterday',
                          active: AttendanceHelpers.isSameDay(
                              selectedDate, DateTime.now().subtract(const Duration(days: 1))),
                          onTap: () => setSheetState(() => selectedDate =
                              DateTime.now().subtract(const Duration(days: 1))),
                          colors: c,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setSheetState(() => selectedDate = picked);
                              }
                            },
                            icon: Icon(Icons.calendar_today_rounded, size: 14, color: c.accent),
                            label: Text(
                              DateFormat('MMM d').format(selectedDate),
                              style: TextStyle(fontSize: 12, color: c.textPrimary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: c.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Status Selection ──
                    Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(
                                () => selectedStatus = AttendanceStatus.attended),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedStatus == AttendanceStatus.attended
                                    ? c.upcoming.withValues(alpha: 0.16)
                                    : c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedStatus == AttendanceStatus.attended
                                      ? c.upcoming
                                      : c.border,
                                  width: selectedStatus == AttendanceStatus.attended ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 18, color: c.upcoming),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Attended',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(
                                () => selectedStatus = AttendanceStatus.absent),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedStatus == AttendanceStatus.absent
                                    ? c.overdue.withValues(alpha: 0.16)
                                    : c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selectedStatus == AttendanceStatus.absent
                                      ? c.overdue
                                      : c.border,
                                  width: selectedStatus == AttendanceStatus.absent ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.cancel_rounded,
                                      size: 18, color: c.overdue),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Missed',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Save Button ──
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Course? course;
                          if (courses.isNotEmpty) {
                            course = courses.firstWhere(
                              (item) => item.id == selectedCourseId,
                              orElse: () => courses.first,
                            );
                          }

                          final courseName = course?.name ??
                              (customSubjectCtrl.text.trim().isNotEmpty
                                  ? customSubjectCtrl.text.trim()
                                  : 'General Class');
                          final courseCode = course?.code ?? '';
                          final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

                          PremiumHaptics.tap();
                          await attendance.logManual(
                            courseId: course?.id ?? 'manual_${courseName.hashCode}',
                            courseName: courseName,
                            courseCode: courseCode,
                            date: dateStr,
                            status: selectedStatus,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Save Record',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
