import 'package:intl/intl.dart';
import '../models/task.dart';

List<Task> getPreloadedTasks() {
  final now = DateTime.now();
  final fmt = DateFormat('yyyy-MM-dd');

  String d(int dayOffset) => fmt.format(now.add(Duration(days: dayOffset)));

  return [
    // ── High Priority Urgent & Today ─────────────────────────────────────
    Task(
      title: 'Operating Systems - Assignment 2',
      description: 'Implement Round Robin and Priority CPU Scheduling algorithms in C++.',
      type: TaskType.assignment,
      dueDate: d(1),
      dueTime: '23:59',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.oneDay),
        Reminder(type: ReminderType.oneHour),
      ],
    ),
    Task(
      title: 'Database Management Systems Quiz 3',
      description: 'Covers Normalization (1NF, 2NF, 3NF, BCNF) and B+ Tree indexing.',
      type: TaskType.ct,
      dueDate: d(0),
      dueTime: '11:30',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.oneHour),
      ],
    ),
    Task(
      title: 'Computer Networks Lab 5 Report',
      description: 'Packet tracing using Wireshark: TCP 3-Way Handshake and DNS analysis.',
      type: TaskType.lab,
      dueDate: d(2),
      dueTime: '17:00',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.oneDay),
      ],
    ),

    // ── Upcoming Exams, Projects & Presentations ──────────────────────────
    Task(
      title: 'Software Engineering Term Project Demo',
      description: 'Deliver Phase 2 prototype with completed REST API and Flutter client integration.',
      type: TaskType.project,
      dueDate: d(5),
      dueTime: '14:00',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.threeDays),
        Reminder(type: ReminderType.oneDay),
      ],
    ),
    Task(
      title: 'Compiler Design Midterm Exam',
      description: 'Chapters 1-4: Lexical Analysis, CFGs, LL(1) and LR(1) Parsers.',
      type: TaskType.exam,
      dueDate: d(7),
      dueTime: '10:00',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.oneWeek),
        Reminder(type: ReminderType.oneDay),
      ],
    ),
    Task(
      title: 'AI & Ethics Presentation Slides',
      description: 'Prepare 10-minute slide deck on bias in generative LLM code generation.',
      type: TaskType.presentation,
      dueDate: d(3),
      dueTime: '15:30',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
    ),
    Task(
      title: 'Microprocessor Architecture Viva',
      description: 'Oral examination on 8086 Assembly, pin configurations, and interrupt handling.',
      type: TaskType.viva,
      dueDate: d(4),
      dueTime: '13:00',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.pending,
      reminders: [
        Reminder(type: ReminderType.oneDay),
      ],
    ),
    Task(
      title: 'Discrete Mathematics Problem Set 4',
      description: 'Recurrence relations, graph isomorphism, and tree traversal proofs.',
      type: TaskType.assignment,
      dueDate: d(6),
      dueTime: '23:59',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
    ),
    Task(
      title: 'Web Engineering Frontend Workshop',
      description: 'Hands-on session on Next.js 15 Server Components and state hydration.',
      type: TaskType.other,
      dueDate: d(8),
      dueTime: '16:00',
      hasTime: true,
      priority: TaskPriority.low,
      status: TaskStatus.pending,
    ),
    Task(
      title: 'Mobile Application Architecture Lab',
      description: 'Implement Provider / BLoC state management pattern in Flutter.',
      type: TaskType.lab,
      dueDate: d(9),
      dueTime: '12:00',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
    ),
    Task(
      title: 'Computer Graphics Ray Tracing Mini-Project',
      description: 'Implement Phong shading model and reflection rays in WebGL.',
      type: TaskType.project,
      dueDate: d(12),
      dueTime: '23:59',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.pending,
    ),

    // ── Completed Tasks (For History & Done Screen) ───────────────────────
    Task(
      title: 'Data Structures Lab 4 - Binary Search Trees',
      description: 'Implemented AVL self-balancing tree rotations in C.',
      type: TaskType.lab,
      dueDate: d(-2),
      dueTime: '17:00',
      hasTime: true,
      priority: TaskPriority.medium,
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 2)).toIso8601String(),
    ),
    Task(
      title: 'Numerical Methods Quiz 2',
      description: 'Gauss-Seidel and Newton-Raphson methods.',
      type: TaskType.ct,
      dueDate: d(-3),
      dueTime: '11:00',
      hasTime: true,
      priority: TaskPriority.high,
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 3)).toIso8601String(),
    ),
    Task(
      title: 'Technical English Research Paper Review',
      description: 'Literature review on distributed systems consensus protocols.',
      type: TaskType.assignment,
      dueDate: d(-5),
      dueTime: '23:59',
      hasTime: true,
      priority: TaskPriority.low,
      status: TaskStatus.completed,
      completedAt: now.subtract(const Duration(days: 5)).toIso8601String(),
    ),
  ];
}
