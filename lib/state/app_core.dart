import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/class_routine.dart';
import '../models/task.dart';
import '../models/settings.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../domain/preloaded_tasks.dart';

mixin AppCore on ChangeNotifier {
  static const _widgetChannel = MethodChannel('com.example.uniro1/widget');
  // Shared formatters — DateFormat construction parses locale skeletons and
  // is surprisingly expensive; one static instance serves all calls.
  static final DateFormat _ymdFmt = DateFormat('yyyy-MM-dd');
  // ── State (RAM) ──────────────────────────────────────────────────────────
  List<Task> _tasks = [];
  List<ClassRoutineEntry> _routine = [];
  UserSettings _settings = UserSettings.defaults();
  TaskType? _activeFilter; // null = All
  bool _isLoaded = false;
  bool _isNewTaskOpen = false;

  // ── Memoized Caches (Zero GC Pauses on Frame Cycles) ─────────────────────
  List<Task>? _cachedUnmodifiableTasks;
  List<Task>? _cachedPendingTasks;
  List<Task>? _cachedHeroTasks;
  List<Task>? _cachedCompletedTasks;
  List<ClassRoutineEntry>? _cachedRoutine;
  final Map<String, Map<String, int>> _cachedWeeklyLoad = {};

  void _clearComputedCaches() {
    _cachedUnmodifiableTasks = null;
    _cachedPendingTasks = null;
    _cachedHeroTasks = null;
    _cachedCompletedTasks = null;
    _cachedRoutine = null;
    _cachedWeeklyLoad.clear();
  }

  List<Task> get tasks => _cachedUnmodifiableTasks ??= List.unmodifiable(_tasks);
  UserSettings get settings => _settings;
  TaskType? get activeFilter => _activeFilter;
  bool get isLoaded => _isLoaded;
  bool get isNewTaskOpen => _isNewTaskOpen;

  void setNewTaskOpen(bool isOpen) {
    if (_isNewTaskOpen == isOpen) return;
    _isNewTaskOpen = isOpen;
    notifyListeners();
  }

  // ── Debounce Timer (GymMane pattern) ──────────────────────────────────────
  Timer? _saveDebounce;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _saveDebounce?.cancel();
    super.dispose();
  }

  void _persist() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!_disposed) persistNow();
    });
  }

  void persistNow() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    LocalStore.instance.save('tasks', _tasks.map((t) => t.toJson()).toList());
    LocalStore.instance.save('settings', _settings.toJson());
    LocalStore.instance.save(
        'routine', _routine.map((e) => e.toJson()).toList());
    _widgetChannel.invokeMethod('updateWidget').catchError((_) {});
  }

  // ── Boot (GymMane loadFromStore pattern with Preloaded Seed Data) ─────────
  void loadFromStore() {
    final rawTasks = LocalStore.instance.load('tasks');
    if (rawTasks is List && rawTasks.isNotEmpty) {
      _tasks = rawTasks
          .map((j) => Task.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } else {
      // First launch or empty state: seed with realistic preloaded tasks
      _tasks = getPreloadedTasks();
      persistNow();
    }
    final rawSettings = LocalStore.instance.load('settings');
    if (rawSettings != null) {
      _settings = UserSettings.fromJson(Map<String, dynamic>.from(rawSettings as Map));
    }
    final rawRoutine = LocalStore.instance.load('routine');
    if (rawRoutine is List) {
      _routine = rawRoutine
          .map((j) => ClassRoutineEntry.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    _clearComputedCaches();
    _isLoaded = true;
    notifyListeners();
  }

  // ── Task Actions ──────────────────────────────────────────────────────────
  void addTask(Task task) {
    _tasks.add(task);
    _activeFilter = null;
    _clearComputedCaches();
    notifyListeners();
    _persist();
    NotificationService.instance.scheduleForTask(task);
  }

  void updateTask(String id, Task updated) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final old = _tasks[i];
    _tasks[i] = updated;
    _clearComputedCaches();
    notifyListeners();
    _persist();
    NotificationService.instance.cancelForTask(old);
    NotificationService.instance.scheduleForTask(updated);
  }

  void completeTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now().toIso8601String(),
    );
    _clearComputedCaches();
    notifyListeners();
    _persist();
    NotificationService.instance.cancelForTask(_tasks[i]);
  }

  void uncompleteTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    _tasks[i] = _tasks[i].copyWith(
      status: TaskStatus.pending,
      clearCompletedAt: true,
    );
    _clearComputedCaches();
    notifyListeners();
    _persist();
    NotificationService.instance.scheduleForTask(_tasks[i]);
  }

  void deleteTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i >= 0) {
      final old = _tasks[i];
      NotificationService.instance.cancelForTask(old);
    }
    _tasks.removeWhere((t) => t.id == id);
    _clearComputedCaches();
    notifyListeners();
    _persist();
  }

  // ── Class Routine (dashboard pager page 2) ─────────────────────────────
  /// Sorted Mon→Sun, then by start time. Unmodifiable snapshot.
  List<ClassRoutineEntry> get classRoutine {
    if (_cachedRoutine != null) return _cachedRoutine!;
    final list = List.of(_routine)
      ..sort((a, b) {
        final d = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (d != 0) return d;
        return ClassRoutineEntry.minutesOf(a.startTime)
            .compareTo(ClassRoutineEntry.minutesOf(b.startTime));
      });
    return _cachedRoutine = List.unmodifiable(list);
  }

  void addRoutineEntry(ClassRoutineEntry entry) {
    _routine.add(entry);
    _cachedRoutine = null;
    notifyListeners();
    _persist();
  }

  void updateRoutineEntry(String id, ClassRoutineEntry updated) {
    final i = _routine.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _routine[i] = updated;
    _cachedRoutine = null;
    notifyListeners();
    _persist();
  }

  void deleteRoutineEntry(String id) {
    _routine.removeWhere((e) => e.id == id);
    _cachedRoutine = null;
    notifyListeners();
    _persist();
  }

  void setFilter(TaskType? filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    _cachedPendingTasks = null;
    _cachedHeroTasks = null;
    notifyListeners();
  }

  void updateSettings(UserSettings s) {
    _settings = s;
    notifyListeners();
    LocalStore.instance.save('settings', s.toJson());
    // Keep the daily 6 AM greeting in sync with name + toggle.
    unawaited(NotificationService.instance.scheduleDailyGreeting(
      name: s.name,
      enabled: s.notificationsEnabled,
    ));
  }

  // ── Computed (Cached to eliminate Scavenge GC) ───────────────────────────
  List<Task> get pendingTasks {
    if (_cachedPendingTasks != null) return _cachedPendingTasks!;
    var list = _tasks.where((t) => t.status == TaskStatus.pending).toList();
    if (_activeFilter != null) {
      list = list.where((t) => t.type == _activeFilter).toList();
    }
    list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return _cachedPendingTasks = List.unmodifiable(list);
  }

  List<Task> get completedTasks {
    if (_cachedCompletedTasks != null) return _cachedCompletedTasks!;
    return _cachedCompletedTasks = List.unmodifiable(
      _tasks.where((t) => t.status == TaskStatus.completed).toList(),
    );
  }

  List<Task> get heroTasks {
    if (_cachedHeroTasks != null) return _cachedHeroTasks!;
    return _cachedHeroTasks = List.unmodifiable(pendingTasks.take(6).toList());
  }

  List<Task> tasksForDate(String date) =>
      _tasks.where((t) => t.dueDate == date).toList();

  Map<String, int> weeklyLoad(String weekStart) {
    final cached = _cachedWeeklyLoad[weekStart];
    if (cached != null) return cached;

    final start = DateTime.parse(weekStart);
    final map = <String, int>{};
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final key = _ymdFmt.format(d);
      map[key] = _tasks
          .where((t) => t.dueDate == key && t.status == TaskStatus.pending)
          .length;
    }
    return _cachedWeeklyLoad[weekStart] = Map.unmodifiable(map);
  }
}
