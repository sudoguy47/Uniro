import '../domain/ids.dart';

enum TaskType { assignment, exam, ct, viva, presentation, lab, project, other, custom }
enum TaskPriority { high, medium, low }
enum TaskStatus { pending, completed }
enum ReminderType { atTime, oneHour, oneDay, threeDays, oneWeek, custom }

class Reminder {
  final String id;
  final ReminderType type;
  final int? customDays;
  String? notificationId;

  Reminder({
    String? id,
    required this.type,
    this.customDays,
    this.notificationId,
  }) : id = id ?? newLocalId();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'customDays': customDays,
    'notificationId': notificationId,
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: j['id'],
    type: ReminderType.values.byName(j['type']),
    customDays: j['customDays'],
    notificationId: j['notificationId'],
  );
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final String dueDate;      // 'YYYY-MM-DD'
  final String? dueTime;     // 'HH:mm'
  final bool hasTime;
  final TaskPriority priority;
  final TaskStatus status;
  final List<Reminder> reminders;
  final String createdAt;
  final String? completedAt;

  Task({
    String? id,
    required this.title,
    this.description,
    required this.type,
    required this.dueDate,
    this.dueTime,
    this.hasTime = false,
    required this.priority,
    this.status = TaskStatus.pending,
    this.reminders = const [],
    String? createdAt,
    this.completedAt,
  })  : id = id ?? newLocalId(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Task copyWith({
    String? title,
    String? description,
    TaskType? type,
    String? dueDate,
    String? dueTime,
    bool? hasTime,
    TaskPriority? priority,
    TaskStatus? status,
    List<Reminder>? reminders,
    String? completedAt,
    bool clearCompletedAt = false,
  }) => Task(
    id: id,
    createdAt: createdAt,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    dueDate: dueDate ?? this.dueDate,
    dueTime: dueTime ?? this.dueTime,
    hasTime: hasTime ?? this.hasTime,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    reminders: reminders ?? this.reminders,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'dueDate': dueDate,
    'dueTime': dueTime,
    'hasTime': hasTime,
    'priority': priority.name,
    'status': status.name,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'createdAt': createdAt,
    'completedAt': completedAt,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'],
    title: j['title'],
    description: j['description'],
    type: TaskType.values.byName(j['type']),
    dueDate: j['dueDate'],
    dueTime: j['dueTime'],
    hasTime: j['hasTime'] ?? false,
    priority: TaskPriority.values.byName(j['priority']),
    status: TaskStatus.values.byName(j['status']),
    reminders: (j['reminders'] as List? ?? [])
        .map((r) => Reminder.fromJson(Map<String, dynamic>.from(r)))
        .toList(),
    createdAt: j['createdAt'],
    completedAt: j['completedAt'],
  );
}
