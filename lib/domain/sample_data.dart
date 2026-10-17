import '../models/class_slot.dart';
import '../models/course.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';

/// Built-in example content for first-run exploration ("Use examples").
///
/// Everything is generated relative to [now] so the dashboard looks alive
/// on any date. Every item carries `isSample: true` so "Hide examples"
/// removes exactly these and never touches user data. Pure builders are
/// unit-tested; seeding goes through the public state APIs so
/// persistence and notification scheduling behave like real input.
class SampleBundle {
  const SampleBundle({
    required this.tasks,
    required this.courses,
    required this.slots,
    required this.notes,
  });
  final List<Task> tasks;
  final List<Course> courses;
  final List<ClassSlot> slots;
  final List<Note> notes;
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Builds the full example bundle. Pure; safe to call anywhere.
SampleBundle buildSampleBundle(DateTime now) {
  final math = Course(
    name: 'Mathematics',
    code: 'MATH-201',
    colorTag: Course.palette[2],
    teacher: 'Prof. Rahman',
    room: 'R-301',
    isSample: true,
  );
  final physics = Course(
    name: 'Physics',
    code: 'PHY-102',
    colorTag: Course.palette[0],
    teacher: 'Dr. Karim',
    room: 'Lab-2',
    isSample: true,
  );
  final english = Course(
    name: 'English',
    code: 'ENG-101',
    colorTag: Course.palette[1],
    isSample: true,
  );
  final chemistry = Course(
    name: 'Chemistry',
    code: 'CHEM-110',
    colorTag: Course.palette[4],
    room: 'Lab-1',
    isSample: true,
  );
  final courses = [math, physics, english, chemistry];

  final t0 = DateTime(now.year, now.month, now.day);
  final tasks = [
    Task(
      title: 'Math Assignment 5',
      description: 'Chapter 7: integrals, problems 1–15.',
      type: TaskType.assignment,
      dueDate: _ymd(t0.add(const Duration(days: 1))),
      dueTime: '17:00',
      hasTime: true,
      priority: TaskPriority.high,
      reminders: [
        Reminder(type: ReminderType.oneDay),
        Reminder(type: ReminderType.oneHour),
      ],
      courseId: math.id,
      isSample: true,
    ),
    Task(
      title: 'Physics Midterm',
      description: 'Waves, optics, and thermodynamics.',
      type: TaskType.exam,
      dueDate: _ymd(t0.add(const Duration(days: 6))),
      dueTime: '09:00',
      hasTime: true,
      priority: TaskPriority.high,
      reminders: [
        Reminder(type: ReminderType.sevenDays),
        Reminder(type: ReminderType.oneDay),
      ],
      courseId: physics.id,
      isSample: true,
    ),
    Task(
      title: 'Chemistry CT',
      type: TaskType.ct,
      dueDate: _ymd(t0),
      dueTime: _hm(now.add(const Duration(hours: 2))),
      hasTime: true,
      priority: TaskPriority.medium,
      reminders: [Reminder(type: ReminderType.atTime)],
      courseId: chemistry.id,
      isSample: true,
    ),
    Task(
      title: 'English Presentation',
      description: '5-minute talk on climate fiction.',
      type: TaskType.presentation,
      dueDate: _ymd(t0.add(const Duration(days: 3))),
      priority: TaskPriority.low,
      reminders: [Reminder(type: ReminderType.twoDays)],
      courseId: english.id,
      isSample: true,
    ),
    Task(
      title: 'CS Lab Report',
      type: TaskType.lab,
      dueDate: _ymd(t0.add(const Duration(days: 2))),
      dueTime: '23:59',
      hasTime: true,
      priority: TaskPriority.medium,
      reminders: [Reminder(type: ReminderType.oneDay)],
      isSample: true,
    ),
    Task(
      title: 'Biology Viva',
      description: 'Cell structure and genetics.',
      type: TaskType.viva,
      dueDate: _ymd(t0.add(const Duration(days: 4))),
      dueTime: '10:30',
      hasTime: true,
      priority: TaskPriority.high,
      reminders: [
        Reminder(type: ReminderType.threeDays),
        Reminder(type: ReminderType.oneHour),
      ],
      isSample: true,
    ),
    Task(
      title: 'History Project',
      description: 'Timeline of the liberation war.',
      type: TaskType.project,
      dueDate: _ymd(t0.add(const Duration(days: 9))),
      priority: TaskPriority.medium,
      reminders: [
        Reminder(type: ReminderType.sevenDays),
        Reminder(type: ReminderType.threeDays),
      ],
      isSample: true,
    ),
    Task(
      title: 'Math Quiz Prep',
      type: TaskType.assignment,
      dueDate: _ymd(t0.add(const Duration(days: 5))),
      dueTime: '08:00',
      hasTime: true,
      priority: TaskPriority.low,
      reminders: [Reminder(type: ReminderType.oneDay)],
      courseId: math.id,
      isSample: true,
    ),
    Task(
      title: 'Physics Lab File',
      type: TaskType.lab,
      dueDate: _ymd(t0.add(const Duration(days: 1))),
      dueTime: '15:00',
      hasTime: true,
      priority: TaskPriority.medium,
      reminders: [Reminder(type: ReminderType.oneHour)],
      courseId: physics.id,
      isSample: true,
    ),
    Task(
      title: 'English Essay Draft',
      description: 'First draft, at least 800 words.',
      type: TaskType.other,
      dueDate: _ymd(t0.add(const Duration(days: 7))),
      priority: TaskPriority.low,
      reminders: [Reminder(type: ReminderType.custom, customDays: 2)],
      courseId: english.id,
      isSample: true,
    ),
  ];

  final slots = [
    ClassSlot(
      courseId: math.id,
      weekday: DateTime.monday,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60,
      room: 'R-301',
      reminderMinutesBefore: 15,
      isSample: true,
    ),
    ClassSlot(
      courseId: chemistry.id,
      weekday: DateTime.tuesday,
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
      room: 'Lab-1',
      reminderMinutesBefore: 15,
      isSample: true,
    ),
    ClassSlot(
      courseId: physics.id,
      weekday: DateTime.wednesday,
      startMinutes: 11 * 60,
      endMinutes: 12 * 60,
      room: 'Lab-2',
      reminderMinutesBefore: 10,
      isSample: true,
    ),
    ClassSlot(
      courseId: english.id,
      weekday: DateTime.thursday,
      startMinutes: 14 * 60,
      endMinutes: 15 * 60 + 30,
      reminderMinutesBefore: 15,
      isSample: true,
    ),
    ClassSlot(
      courseId: math.id,
      weekday: DateTime.friday,
      startMinutes: 9 * 60,
      endMinutes: 10 * 60 + 30,
      room: 'R-301',
      reminderMinutesBefore: 15,
      isSample: true,
    ),
  ];

  final notes = [
    Note(
      id: generateNoteId(),
      title: 'Welcome to Notes',
      blocks: [
        NoteBlock(
          id: generateNoteId(),
          type: BlockType.paragraph,
          text: 'This is an example note. Tap to edit, or delete it anytime.',
        ),
        NoteBlock(
          id: generateNoteId(),
          type: BlockType.quote,
          text: 'Small steps lead to big changes.',
        ),
      ],
      folder: 'Personal',
      createdAt: now,
      updatedAt: now,
      isSample: true,
    ),
    Note(
      id: generateNoteId(),
      title: 'Exam checklist',
      blocks: [
        NoteBlock(
          id: generateNoteId(),
          type: BlockType.checklist,
          text: 'Revise formulas',
        ),
        NoteBlock(
          id: generateNoteId(),
          type: BlockType.checklist,
          text: 'Solve past papers',
        ),
        NoteBlock(
          id: generateNoteId(),
          type: BlockType.checklist,
          text: 'Pack admit card',
        ),
      ],
      folder: 'Study',
      createdAt: now,
      updatedAt: now,
      isSample: true,
    ),
  ];

  return SampleBundle(
      tasks: tasks, courses: courses, slots: slots, notes: notes);
}

/// True when any example content is present.
bool hasExampleData(AppState app, RoutineState routine, NotesState notes) {
  return app.tasks.any((t) => t.isSample) ||
      routine.courses.any((c) => c.isSample) ||
      routine.slots.any((s) => s.isSample) ||
      notes.allNotes.any((n) => n.isSample);
}

/// Inserts the example bundle through the public state APIs (persistence
/// + notification scheduling included), then rebuilds class reminders.
/// Never throws.
Future<void> seedExampleData({
  required AppState app,
  required RoutineState routine,
  required NotesState notes,
}) async {
  try {
    if (hasExampleData(app, routine, notes)) return;
    final bundle = buildSampleBundle(DateTime.now());
    for (final c in bundle.courses) {
      routine.addCourse(c);
    }
    if (bundle.slots.isNotEmpty) routine.addSlots(bundle.slots);
    for (final t in bundle.tasks) {
      app.addTask(t);
    }
    for (final n in bundle.notes) {
      notes.updateNote(n);
    }
    try {
      await NotificationService.instance.rearmAll(
        tasks: app.tasks,
        courses: routine.courses,
        slots: routine.slots,
        name: app.settings.name,
        enabled: app.settings.notificationsEnabled,
      );
    } catch (_) {}
  } catch (_) {}
}

/// Removes exactly the example items, using the same delete paths as the
/// UI (cancellations + persistence included). Never throws.
Future<void> hideExampleData({
  required AppState app,
  required RoutineState routine,
  required NotesState notes,
}) async {
  try {
    for (final t in app.tasks.where((t) => t.isSample).toList()) {
      app.deleteTask(t.id);
    }
    for (final c in routine.courses.where((c) => c.isSample).toList()) {
      final removed = routine.deleteCourse(c.id);
      for (final s in removed) {
        await NotificationService.instance
            .cancelClassRemindersForSlot(s.id);
      }
      app.unlinkCourse(c.id);
      notes.unlinkCourse(c.id);
    }
    for (final s in routine.slots.where((s) => s.isSample).toList()) {
      routine.deleteSlot(s.id);
      await NotificationService.instance.cancelClassRemindersForSlot(s.id);
    }
    for (final n in notes.allNotes.where((n) => n.isSample).toList()) {
      notes.deleteNote(n.id);
    }
    try {
      await NotificationService.instance.rearmAll(
        tasks: app.tasks,
        courses: routine.courses,
        slots: routine.slots,
        name: app.settings.name,
        enabled: app.settings.notificationsEnabled,
      );
    } catch (_) {}
  } catch (_) {}
}
