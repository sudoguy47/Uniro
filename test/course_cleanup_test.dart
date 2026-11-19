import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/models/attendance_record.dart';
import 'package:uniro1/models/class_slot.dart';
import 'package:uniro1/models/course.dart';
import 'package:uniro1/models/focus_session.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/services/notes_store.dart';
import 'package:uniro1/state/app_state.dart';
import 'package:uniro1/state/attendance_state.dart';
import 'package:uniro1/state/focus_state.dart';
import 'package:uniro1/state/notes_state.dart';
import 'package:uniro1/state/routine_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  group('Course Deletion Cleanup', () {
    test(
        'course delete cleans up slots, attendance, and detaches tasks, notes, focus sessions',
        () async {
      // 1. Initialize states
      final routine = RoutineState();
      final attendance = AttendanceState();
      await attendance.load();
      final app = AppState();
      final notesStore = NotesStore();
      await notesStore.load();
      final notes = NotesState(store: notesStore);
      final focus = FocusState();

      final targetCourse = Course(
        id: 'course_cse_101',
        name: 'Introduction to CS',
        code: 'CSE 101',
      );
      final otherCourse = Course(
        id: 'course_mat_201',
        name: 'Linear Algebra',
        code: 'MAT 201',
      );

      routine.addCourse(targetCourse);
      routine.addCourse(otherCourse);

      // Add slots
      final targetSlot = ClassSlot(
        id: 'slot_cs_1',
        courseId: 'course_cse_101',
        weekday: 1,
        startMinutes: 540,
        endMinutes: 630,
      );
      final otherSlot = ClassSlot(
        id: 'slot_mat_1',
        courseId: 'course_mat_201',
        weekday: 2,
        startMinutes: 600,
        endMinutes: 690,
      );
      routine.addSlot(targetSlot);
      routine.addSlot(otherSlot);

      // Add attendance records
      await attendance.logManual(
        courseId: 'course_cse_101',
        courseName: 'Introduction to CS',
        date: '2026-11-10',
        status: AttendanceStatus.attended,
        slotId: 'slot_cs_1',
      );
      await attendance.logManual(
        courseId: 'course_mat_201',
        courseName: 'Linear Algebra',
        date: '2026-11-10',
        status: AttendanceStatus.attended,
        slotId: 'slot_mat_1',
      );

      // Add tasks
      final targetTask = Task(
        id: 'task_cs_hw',
        title: 'Complete CS Assignment 1',
        type: TaskType.assignment,
        dueDate: '2026-11-15',
        priority: TaskPriority.high,
        courseId: 'course_cse_101',
      );
      final otherTask = Task(
        id: 'task_mat_hw',
        title: 'Linear Algebra Quiz Prep',
        type: TaskType.exam,
        dueDate: '2026-11-16',
        priority: TaskPriority.medium,
        courseId: 'course_mat_201',
      );
      app.addTask(targetTask);
      app.addTask(otherTask);

      // Add notes
      final targetNote = notes.createNote(courseId: 'course_cse_101');
      final otherNote = notes.createNote(courseId: 'course_mat_201');

      // Add focus sessions and active link
      focus.linkKind = 'course';
      focus.linkId = 'course_cse_101';
      focus.record(FocusSession(
        id: 'session_1',
        runId: 'run_1',
        date: '2026-11-10',
        startedAt: '2026-11-10T10:00:00.000',
        plannedSec: 1500,
        focusedSec: 1500,
        linkKind: 'course',
        linkId: 'course_cse_101',
        linkName: 'Introduction to CS',
        completed: true,
      ));
      focus.record(FocusSession(
        id: 'session_2',
        runId: 'run_2',
        date: '2026-11-10',
        startedAt: '2026-11-10T11:00:00.000',
        plannedSec: 1500,
        focusedSec: 1500,
        linkKind: 'course',
        linkId: 'course_mat_201',
        linkName: 'Linear Algebra',
        completed: true,
      ));

      // Verify baseline before deletion
      expect(routine.courses.length, equals(2));
      expect(routine.slots.length, equals(2));
      expect(attendance.records.length, equals(2));
      expect(app.tasks.length, equals(2));
      expect(notes.allNotes.length, equals(2));
      expect(focus.sessions.length, equals(2));
      expect(focus.linkId, equals('course_cse_101'));

      // 2. Perform coordinated course deletion (as CoursesScreen does)
      final removedSlots = routine.deleteCourse('course_cse_101');
      await attendance.clearForCourse('course_cse_101');
      app.unlinkCourse('course_cse_101');
      notes.unlinkCourse('course_cse_101');
      focus.unlinkCourse('course_cse_101');

      // 3. Assert routine cleanup
      expect(routine.courseById('course_cse_101'), isNull);
      expect(routine.courses.any((c) => c.id == 'course_cse_101'), isFalse);
      expect(routine.courses.any((c) => c.id == 'course_mat_201'), isTrue);
      expect(removedSlots.length, equals(1));
      expect(removedSlots.first.id, equals('slot_cs_1'));
      expect(routine.slots.any((s) => s.courseId == 'course_cse_101'), isFalse);
      expect(routine.slots.any((s) => s.courseId == 'course_mat_201'), isTrue);

      // 4. Assert attendance records permanently deleted for target course
      expect(attendance.records.any((r) => r.courseId == 'course_cse_101'),
          isFalse);
      expect(
          attendance.records.any((r) => r.courseId == 'course_mat_201'), isTrue);

      // 5. Assert tasks detached (courseId cleared, task preserved)
      final keptCsTask = app.tasks.firstWhere((t) => t.id == 'task_cs_hw');
      expect(keptCsTask.courseId, isNull);
      expect(keptCsTask.title, equals('Complete CS Assignment 1'));
      final keptMatTask = app.tasks.firstWhere((t) => t.id == 'task_mat_hw');
      expect(keptMatTask.courseId, equals('course_mat_201'));

      // 6. Assert notes detached (courseId cleared, content preserved)
      final keptCsNote = notes.allNotes.firstWhere((n) => n.id == targetNote.id);
      expect(keptCsNote.courseId, isNull);
      final keptMatNote = notes.allNotes.firstWhere((n) => n.id == otherNote.id);
      expect(keptMatNote.courseId, equals('course_mat_201'));

      // 7. Assert focus active timer and history detached
      expect(focus.linkKind, equals('none'));
      expect(focus.linkId, isNull);
      final keptCsSession =
          focus.sessions.firstWhere((s) => s.id == 'session_1');
      expect(keptCsSession.linkKind, equals('none'));
      expect(keptCsSession.linkId, isNull);
      expect(keptCsSession.focusedSec, equals(1500)); // History preserved
      final keptMatSession =
          focus.sessions.firstWhere((s) => s.id == 'session_2');
      expect(keptMatSession.linkKind, equals('course'));
      expect(keptMatSession.linkId, equals('course_mat_201'));
    });
  });
}
