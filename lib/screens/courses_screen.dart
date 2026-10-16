import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';

/// Profile > Courses: list, add, edit, delete.
///
/// Deleting a course deletes its classes and unlinks its tasks/notes
/// (after an explicit confirm dialog).
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  Future<void> _refresh(BuildContext context) {
    final routine = context.read<RoutineState>();
    final enabled =
        context.read<AppState>().settings.notificationsEnabled;
    return NotificationService.instance.refreshClassReminders(
      courses: routine.courses,
      slots: routine.slots,
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
    final classCount =
        routine.slots.where((s) => s.courseId == course.id).length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('Delete "${course.name}"?'),
        content: Text(
          'Its $classCount class${classCount == 1 ? '' : 'es'} and reminders will be deleted. Linked tasks and notes stay, but will be unlinked.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              routine.deleteCourse(course.id);
              context.read<AppState>().unlinkCourse(course.id);
              context.read<NotesState>().unlinkCourse(course.id);
              _refresh(context);
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                    const SnackBar(content: Text('Course deleted')));
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
              color: c.textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.accent),
            onPressed: () {
              PremiumHaptics.tap();
              _openEditor(context);
            },
          ),
        ],
      ),
      body: routine.courses.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 44, color: c.textTertiary),
                  const SizedBox(height: 10),
                  Text(
                    'No courses yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add one to start building your routine.',
                    style:
                        TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: routine.courses.length,
              itemBuilder: (context, i) {
                final course = routine.courses[i];
                final n = routine.slots
                    .where((s) => s.courseId == course.id)
                    .length;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: c.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: course.colorTag != null
                            ? Color(course.colorTag!)
                            : c.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      (course.code ?? '').isNotEmpty
                          ? '${course.code} · ${course.name}'
                          : course.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary),
                    ),
                    subtitle: Text(
                      '$n class${n == 1 ? '' : 'es'} per week',
                      style: TextStyle(color: c.textSecondary),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined,
                              size: 20, color: c.textSecondary),
                          onPressed: () {
                            PremiumHaptics.select();
                            _openEditor(context, existing: course);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: c.overdue),
                          onPressed: () {
                            PremiumHaptics.tap();
                            _confirmDelete(context, course);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course name is required.')));
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text('Save Course',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
