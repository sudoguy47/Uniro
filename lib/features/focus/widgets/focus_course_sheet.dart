import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/focus_logic.dart';
import '../../../domain/haptics.dart';
import '../../../models/task.dart';
import '../../../screens/courses_screen.dart';
import '../../../state/app_state.dart';
import '../../../state/focus_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';

class FocusCourseSheet extends StatefulWidget {
  const FocusCourseSheet({super.key});

  @override
  State<FocusCourseSheet> createState() => _FocusCourseSheetState();
}

class _FocusCourseSheetState extends State<FocusCourseSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.watch<RoutineState>();
    final courses = routine.courses;
    final tasks = context
        .watch<AppState>()
        .tasks
        .where((t) => t.status == TaskStatus.pending)
        .toList();
    final slots = List.of(routine.slots)
      ..sort((a, b) {
        final w = a.weekday.compareTo(b.weekday);
        return w != 0 ? w : a.startMinutes.compareTo(b.startMinutes);
      });
    final st = context.read<FocusState>();

    final q = _q.trim().toLowerCase();
    bool hit(String s) => q.isEmpty || s.toLowerCase().contains(q);
    final fc = courses
        .where((e) =>
            hit(e.name) || hit(e.code ?? ''))
        .toList();
    final ft = tasks
        .where((e) => hit(e.title))
        .take(30)
        .toList();
    final fs = slots.where((s) {
      final course = routine.courseById(s.courseId);
      return hit(course?.name ?? '') ||
          hit(course?.code ?? '') ||
          hit(weekdayShort(s.weekday));
    }).toList();
    final allEmpty = fc.isEmpty && ft.isEmpty && fs.isEmpty;

    String classLabelOf(dynamic s) {
      final course = routine.courseById(s.courseId as String);
      final code = course?.code ?? '';
      final base = course == null
          ? 'Removed course'
          : (code.isNotEmpty ? '$code · ${course.name}' : course.name);
      return '$base · ${weekdayShort(s.weekday as int)} '
          '${slotClock(s.startMinutes as int)}';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text('Link this session',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Search courses, tasks, classes…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: c.inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block_rounded),
                      title: const Text('None (free focus)'),
                      trailing: st.linkKind == 'none'
                          ? Icon(Icons.check_rounded, color: c.accent)
                          : null,
                      onTap: () {
                        PremiumHaptics.select();
                        st.selectLink(kind: 'none');
                        Navigator.pop(context);
                      },
                    ),
                    if (fc.isNotEmpty)
                      const _SectionLabel('COURSES'),
                    for (final course in fc)
                      ListTile(
                        leading: Icon(Icons.school_outlined,
                            color: c.accent),
                        title: Text(
                            (course.code ?? '').isNotEmpty
                                ? '${course.code} · ${course.name}'
                                : course.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'course' &&
                                st.linkId == course.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'course', id: course.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (ft.isNotEmpty)
                      const _SectionLabel('TASKS'),
                    for (final task in ft)
                      ListTile(
                        leading: Icon(Icons.assignment_outlined,
                            color: c.accent),
                        title: Text(task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'task' &&
                                st.linkId == task.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'task', id: task.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (fs.isNotEmpty)
                      const _SectionLabel('CLASSES'),
                    for (final slot in fs)
                      ListTile(
                        leading: Icon(Icons.class_outlined,
                            color: c.accent),
                        title: Text(classLabelOf(slot),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: st.linkKind == 'class' &&
                                st.linkId == slot.id
                            ? Icon(Icons.check_rounded,
                                color: c.accent)
                            : null,
                        onTap: () {
                          PremiumHaptics.select();
                          st.selectLink(
                              kind: 'class', id: slot.id);
                          Navigator.pop(context);
                        },
                      ),
                    if (allEmpty) _emptyLinks(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyLinks(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined,
                  color: c.textSecondary, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nothing to link yet. Add your courses first so focus time lands in the right place.',
                  style: TextStyle(
                      fontSize: 14, color: c.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                PremiumHaptics.tap();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CoursesScreen()),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Add a course',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2)),
    );
  }
}
