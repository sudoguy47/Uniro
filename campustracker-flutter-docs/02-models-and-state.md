# 02. Models & State Management (GymMane FitState Pattern)

> GymMane-এ `fit_core.dart` + `fit_state.dart` ছিল।
> CampusTracker-এ `app_core.dart` + `app_state.dart`।
> **Exact same pattern।**

---

## models/task.dart

```dart
import 'package:uuid/uuid.dart';

enum TaskType { assignment, exam, ct, viva, presentation, lab, project, other }
enum TaskPriority { high, medium, low }
enum TaskStatus { pending, completed }
enum ReminderType { atTime, oneHour, oneDay, threeDays, oneWeek, custom }

class Reminder {
  final String id;
  final ReminderType type;
  final int? customDays;
  String? notificationId;

  Reminder({required this.type, this.customDays})
      : id = const Uuid().v4();

  Map<String, dynamic> toJson() => {
    'id': id, 'type': type.name,
    'customDays': customDays, 'notificationId': notificationId,
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    type: ReminderType.values.byName(j['type']),
    customDays: j['customDays'],
  )..notificationId = j['notificationId'];
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
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Task copyWith({
    String? title, String? description, TaskType? type,
    String? dueDate, String? dueTime, bool? hasTime,
    TaskPriority? priority, TaskStatus? status,
    List<Reminder>? reminders, String? completedAt,
  }) => Task(
    id: id, createdAt: createdAt,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    dueDate: dueDate ?? this.dueDate,
    dueTime: dueTime ?? this.dueTime,
    hasTime: hasTime ?? this.hasTime,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    reminders: reminders ?? this.reminders,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'description': description,
    'type': type.name, 'dueDate': dueDate, 'dueTime': dueTime,
    'hasTime': hasTime, 'priority': priority.name, 'status': status.name,
    'reminders': reminders.map((r) => r.toJson()).toList(),
    'createdAt': createdAt, 'completedAt': completedAt,
  };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
    id: j['id'], title: j['title'], description: j['description'],
    type: TaskType.values.byName(j['type']),
    dueDate: j['dueDate'], dueTime: j['dueTime'], hasTime: j['hasTime'] ?? false,
    priority: TaskPriority.values.byName(j['priority']),
    status: TaskStatus.values.byName(j['status']),
    reminders: (j['reminders'] as List? ?? [])
        .map((r) => Reminder.fromJson(r)).toList(),
    createdAt: j['createdAt'], completedAt: j['completedAt'],
  );
}
```

---

## services/local_store.dart (GymMane LocalStore)

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static LocalStore? _instance;
  static LocalStore get instance => _instance ??= LocalStore._();
  LocalStore._();

  SharedPreferences? _prefs;

  // GymMane: Store.instance.init() — boot-এ await করতে হবে
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void save(String key, dynamic data) {
    _prefs?.setString('ct_$key', jsonEncode(data));
  }

  dynamic load(String key) {
    final raw = _prefs?.getString('ct_$key');
    if (raw == null) return null;
    return jsonDecode(raw);
  }
}
```

---

## state/app_core.dart (GymMane fit_core.dart)

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/task.dart';
import '../models/settings.dart';
import '../services/local_store.dart';

mixin AppCore on ChangeNotifier {
  // ════ State (RAM) ════════════════════════════════════════════
  List<Task> _tasks = [];
  UserSettings _settings = UserSettings.defaults();
  TaskType? _activeFilter;  // null = All
  bool _isLoaded = false;

  List<Task> get tasks => List.unmodifiable(_tasks);
  UserSettings get settings => _settings;
  TaskType? get activeFilter => _activeFilter;
  bool get isLoaded => _isLoaded;

  // ════ Debounce Timer (GymMane pattern) ══════════════════════
  Timer? _saveDebounce;

  // GymMane _persist() — 400ms debounce
  void _persist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), persistNow);
  }

  // GymMane persistNow() — immediate flush (app pause)
  void persistNow() {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    LocalStore.instance.save('tasks', _tasks.map((t) => t.toJson()).toList());
    LocalStore.instance.save('settings', _settings.toJson());
  }

  // ════ Boot (GymMane fit.loadFromStore()) ════════════════════
  void loadFromStore() {
    final rawTasks = LocalStore.instance.load('tasks');
    if (rawTasks != null) {
      _tasks = (rawTasks as List)
          .map((j) => Task.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    final rawSettings = LocalStore.instance.load('settings');
    if (rawSettings != null) {
      _settings = UserSettings.fromJson(rawSettings);
    }
    _isLoaded = true;
  }

  // ════ Task Actions ══════════════════════════════════════════
  void addTask(Task task) {
    _tasks.add(task);
    notifyListeners();
    _persist();  // RAM update instant, disk debounced
  }

  void updateTask(String id, Task updated) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = updated;
    notifyListeners();
    _persist();
  }

  void completeTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now().toIso8601String(),
    );
    notifyListeners();
    _persist();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _persist();
  }

  void setFilter(TaskType? filter) {
    _activeFilter = filter;
    notifyListeners();
    // Filter change: no disk write needed
  }

  void updateSettings(UserSettings s) {
    _settings = s;
    notifyListeners();
    LocalStore.instance.save('settings', s.toJson()); // immediate save
  }

  // ════ Computed ══════════════════════════════════════════════
  List<Task> get pendingTasks {
    var list = _tasks.where((t) => t.status == TaskStatus.pending).toList();
    if (_activeFilter != null) {
      list = list.where((t) => t.type == _activeFilter).toList();
    }
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return list;
  }

  List<Task> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();

  List<Task> heroTasks =>
      pendingTasks.take(6).toList();

  List<Task> tasksForDate(String date) =>
      _tasks.where((t) => t.dueDate == date).toList();

  Map<String, int> weeklyLoad(String weekStart) {
    final map = <String, int>{};
    for (int i = 0; i < 7; i++) {
      final d = DateTime.parse(weekStart).add(Duration(days: i));
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      map[key] = _tasks.where((t) =>
          t.dueDate == key && t.status == TaskStatus.pending).length;
    }
    return map;
  }
}
```

---

## state/app_state.dart (GymMane fit_state.dart)

```dart
import 'package:flutter/foundation.dart';
import 'app_core.dart';

// GymMane: final fit = FitState();
final app = AppState();

class AppState extends ChangeNotifier with AppCore {
  // Single global instance — same as GymMane
  // Access anywhere: app.tasks, app.addTask(), etc.
}
```
