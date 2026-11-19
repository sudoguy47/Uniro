import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../models/class_slot.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/attendance_state.dart';
import '../state/focus_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import '../models/task.dart';
import '../widgets/app_notification.dart';

/// Profile > Courses: list, add, edit, delete.
///
/// Deleting a course deletes its classes and unlinks its tasks/notes
/// (after an explicit confirm dialog).
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  Future<void> _refresh({
    required List<Course> courses,
    required List<ClassSlot> slots,
    required bool enabled,
  }) async {
    await NotificationService.instance.refreshClassReminders(
      courses: courses,
      slots: slots,
      enabled: enabled,
    );
    return NotificationService.instance.refreshAttendancePrompts(
      courses: courses,
      slots: slots,
      enabled: enabled,
    );
  }

  void _openEditor(BuildContext context, {Course? existing}) {
    final c = Theme.of(context).extension<AppColors>()!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _CourseEditor(existing: existing),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Course course) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.read<RoutineState>();
    final attendance = context.read<AttendanceState>();
    final app = context.read<AppState>();
    final notes = context.read<NotesState>();
    final focus = context.read<FocusState>();

    final classCount =
        routine.slots.where((s) => s.courseId == course.id).length;
    final attendanceCount =
        attendance.records.where((r) => r.courseId == course.id).length;
    final taskCount =
        app.tasks.where((t) => t.courseId == course.id).length;
    final noteCount =
        notes.allNotes.where((n) => n.courseId == course.id).length;
    final focusCount = focus.sessions
        .where((s) => s.linkKind == 'course' && s.linkId == course.id)
        .length;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('Delete "${course.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '• $classCount routine class slot${classCount == 1 ? '' : 's'} & scheduled reminders\n'
              '• $attendanceCount attendance log${attendanceCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Will be preserved (detached from course):',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '• $taskCount task${taskCount == 1 ? '' : 's'}\n'
              '• $noteCount note${noteCount == 1 ? '' : 's'}\n'
              '• $focusCount focus study session${focusCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final removedSlots = routine.deleteCourse(course.id);
              for (final slot in removedSlots) {
                unawaited(NotificationService.instance
                    .cancelClassRemindersForSlot(slot.id));
                unawaited(NotificationService.instance
                    .cancelAttendancePromptsForSlot(slot.id));
              }
              await attendance.clearForCourse(course.id);
              app.unlinkCourse(course.id);
              notes.unlinkCourse(course.id);
              focus.unlinkCourse(course.id);
              await _refresh(
                courses: routine.courses,
                slots: routine.slots,
                enabled: app.settings.notificationsEnabled,
              );
              if (context.mounted) {
                AppNotification.info(context, 'Course and schedule deleted');
              }
            },
            child: Text('Delete', style: TextStyle(color: c.overdue)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.watch<RoutineState>();
    final app = context.watch<AppState>();
    final tasks = app.tasks;

    final totalWeeklyClasses = routine.slots.length;

    return Scaffold(
      backgroundColor: c.pageBg,
      appBar: AppBar(
        backgroundColor: c.pageBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Courses',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.accent, size: 26),
            onPressed: () {
              PremiumHaptics.tap();
              _openEditor(context);
            },
          ),
        ],
      ),
      body: routine.courses.isEmpty
          ? _EmptyCourses(onAdd: () => _openEditor(context))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        '${routine.courses.length} course${routine.courses.length == 1 ? '' : 's'} · $totalWeeklyClasses class${totalWeeklyClasses == 1 ? '' : 'es'} per week',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.textTertiary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: routine.courses.length,
                    itemBuilder: (context, i) {
                      final course = routine.courses[i];
                      final n = routine.slots
                          .where((s) => s.courseId == course.id)
                          .length;
                      final courseTasks = tasks
                          .where((t) => t.courseId == course.id)
                          .toList();
                      final completedCount = courseTasks
                          .where((t) => t.status == TaskStatus.completed)
                          .length;

                      return _CourseCard(
                        course: course,
                        classCount: n,
                        taskCount: courseTasks.length,
                        completedTaskCount: completedCount,
                        onEdit: () {
                          PremiumHaptics.select();
                          _openEditor(context, existing: course);
                        },
                        onDelete: () {
                          PremiumHaptics.tap();
                          _confirmDelete(context, course);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _EmptyCourses extends StatelessWidget {
  const _EmptyCourses({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.inputBg,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.school_outlined,
                  size: 28, color: c.textTertiary),
            ),
            const SizedBox(height: 14),
            Text(
              'No courses yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your courses once and Uniro builds your routine, reminders and attendance tracking around them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: c.accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Add your first course',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.classCount,
    required this.taskCount,
    required this.completedTaskCount,
    required this.onEdit,
    required this.onDelete,
  });

  final Course course;
  final int classCount;
  final int taskCount;
  final int completedTaskCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _courseColor {
    if (course.colorTag != null) return Color(course.colorTag!);
    return Color(
        Course.palette[course.id.hashCode.abs() % Course.palette.length]);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final accent = _courseColor;
    final hasTasks = taskCount > 0;
    final progress =
        hasTasks ? (completedTaskCount / taskCount).clamp(0.0, 1.0) : 0.0;
    final progressPct = (progress * 100).round();
    final code = (course.code ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  // Identity spine in the course colour
                  Container(
                    width: 4,
                    height: 54,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Course info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (code.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '$classCount class${classCount == 1 ? '' : 'es'}/wk',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: c.textTertiary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasTasks
                              ? '$completedTaskCount of $taskCount task${taskCount == 1 ? '' : 's'} done'
                              : 'No tasks assigned yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.textSecondary,
                          ),
                        ),
                        if (hasTasks) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    height: 4,
                                    color: c.inputBg,
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress,
                                      child: Container(color: accent),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$progressPct%',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textTertiary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Quick actions
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: onEdit,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(Icons.edit_outlined,
                              size: 17, color: c.textTertiary),
                        ),
                      ),
                      InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(Icons.delete_outline_rounded,
                              size: 17,
                              color: c.overdue.withValues(alpha: 0.75)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseEditor extends StatefulWidget {
  const _CourseEditor({this.existing});
  final Course? existing;

  @override
  State<_CourseEditor> createState() => _CourseEditorState();
}

class _CourseEditorState extends State<_CourseEditor> {
  late final TextEditingController _name;
  int? _color;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _color = e?.colorTag;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppNotification.warning(context, 'Course name is required.');
      return;
    }
    final routine = context.read<RoutineState>();
    if (widget.existing != null) {
      routine.updateCourse(
        widget.existing!.id,
        widget.existing!.copyWith(
          name: name,
          colorTag: _color,
          clearColorTag: _color == null,
        ),
      );
    } else {
      routine.addCourse(Course(
        name: name,
        colorTag: _color,
      ));
    }
    PremiumHaptics.confirm();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing != null ? 'Edit Course' : 'New Course',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _field(_name, 'Course name * (e.g. EEE141.8)', c),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: Course.palette.map((col) {
                final active = _color == col;
                return GestureDetector(
                  onTap: () => setState(() => _color = col),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(col),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active ? c.textPrimary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: active
                        ? const Icon(Icons.check,
                            size: 15, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: c.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Save Course',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, AppColors c) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      keyboardType: hint == 'Credits'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
        filled: true,
        fillColor: c.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
