import '../domain/ids.dart';

enum TaskType { assignment, exam, ct, viva, presentation, lab, project, other, custom }
enum TaskPriority { high, medium, low }
enum TaskStatus { pending, completed }
enum ReminderType { atTime, oneHour, oneDay, twoDays, threeDays, sevenDays, oneWeek, custom }

extension SafeEnumByName<T extends Enum> on Iterable<T> {
  T byNameOr(dynamic name, T fallback) {
    if (name == null) return fallback;
    for (final v in this) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}

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
    id: j['id'] as String?,
    type: ReminderType.values.byNameOr(j['type'], ReminderType.atTime),
    customDays: j['customDays'] as int?,
    notificationId: j['notificationId'] as String?,
  );
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskType type;
  final String? customCategory;
  final String dueDate;      // 'YYYY-MM-DD'
  final String? dueTime;     // 'HH:mm'
  final bool hasTime;
  final TaskPriority priority;
  final TaskStatus status;
  final List<Reminder> reminders;
  final String createdAt;
  final String? completedAt;
  final String? courseId;
  /// True for built-in example content (seeded from the dashboard
  /// "Use examples" prompt). Lets "Hide examples" remove exactly these.
  final bool isSample;

  Task({
    String? id,
    required this.title,
    this.description,
    required this.type,
    this.customCategory,
    required this.dueDate,
    this.dueTime,
    this.hasTime = false,
    required this.priority,
    this.status = TaskStatus.pending,
    this.reminders = const [],
    String? createdAt,
    this.completedAt,
    this.courseId,
    this.isSample = false,
  })  : id = id ?? newLocalId(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Task copyWith({
    String? title,
    String? description,
    TaskType? type,
    String? customCategory,
    bool clearCustomCategory = false,
    String? dueDate,
    String? dueTime,
    bool? hasTime,
    TaskPriority? priority,
    TaskStatus? status,
    List<Reminder>? reminders,
    String? completedAt,
    bool clearCompletedAt = false,
    String? courseId,
    bool clearCourseId = false,
    bool? isSample,
  }) => Task(
    id: id,
    createdAt: createdAt,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    customCategory: clearCustomCategory ? null : (customCategory ?? this.customCategory),
    dueDate: dueDate ?? this.dueDate,
    dueTime: dueTime ?? this.dueTime,
    hasTime: hasTime ?? this.hasTime,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    reminders: reminders ?? this.reminders,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    courseId: clearCourseId ? null : (courseId ?? this.courseId),
    isSample: isSample ?? this.isSample,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    if (customCategory != null) 'customCategory': customCategory,
    'dueDate': dueDate,
    'dueTime': dueTime,
    'hasTime': hasTime,
    'priority': priority.name,
    'status': status.name,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'createdAt': createdAt,
    'completedAt': completedAt,
    'courseId': courseId,
    if (isSample) 'isSample': true,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'] as String?,
    title: j['title'] as String? ?? '',
    description: j['description'] as String?,
    type: TaskType.values.byNameOr(j['type'], TaskType.other),
    customCategory: j['customCategory'] as String?,
    dueDate: j['dueDate'] as String? ?? '',
    dueTime: j['dueTime'] as String?,
    hasTime: j['hasTime'] as bool? ?? false,
    priority: TaskPriority.values.byNameOr(j['priority'], TaskPriority.medium),
    status: TaskStatus.values.byNameOr(j['status'], TaskStatus.pending),
    reminders: (j['reminders'] as List? ?? []).map((r) {
      try {
        if (r is Map) {
          return Reminder.fromJson(Map<String, dynamic>.from(r));
        }
      } catch (_) {}
      return null;
    }).whereType<Reminder>().toList(),
    createdAt: j['createdAt'] as String?,
    completedAt: j['completedAt'] as String?,
    courseId: j['courseId'] as String?,
    isSample: j['isSample'] as bool? ?? false,
  );
}
