import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';

enum TaskUrgency { overdue, dueToday, upcoming, completed }

int _lastTodayCheckMillis = 0;
String _cachedTodayStr = '';

String _getTodayString() {
  final nowMillis = DateTime.now().millisecondsSinceEpoch;
  // Cache for 60 seconds to eliminate repeated DateTime allocations per frame
  if (nowMillis - _lastTodayCheckMillis > 60000 || _cachedTodayStr.isEmpty) {
    _lastTodayCheckMillis = nowMillis;
    final today = DateTime.fromMillisecondsSinceEpoch(nowMillis);
    _cachedTodayStr = ymd(today);
  }
  return _cachedTodayStr;
}

/// yyyy-MM-dd for any date (shared by tasks, routine, attendance).
String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Start-of-week date string for the week containing [today], weeks beginning
/// on [weekStartDay] (1–7, DateTime convention). Pure + unit-tested.
String weekStartString(DateTime today, int weekStartDay) {
  final base = today.subtract(
      Duration(days: (today.weekday - weekStartDay + 7) % 7));
  return ymd(base);
}

TaskUrgency getUrgency(Task task) {
  if (task.status == TaskStatus.completed) return TaskUrgency.completed;
  final todayStr = _getTodayString();
  if (task.dueDate.compareTo(todayStr) < 0) return TaskUrgency.overdue;
  if (task.dueDate == todayStr) return TaskUrgency.dueToday;
  return TaskUrgency.upcoming;
}

Color urgencyBorderColor(TaskUrgency u, AppColors c) => switch (u) {
      TaskUrgency.overdue => c.overdue,
      TaskUrgency.dueToday => c.dueToday,
      TaskUrgency.upcoming => c.accent,
      TaskUrgency.completed => c.textTertiary,
    };

Color cardBgColor(TaskUrgency u, AppColors c) => switch (u) {
      TaskUrgency.overdue => c.overdue,
      TaskUrgency.dueToday => c.accent,
      TaskUrgency.upcoming => c.upcoming,
      TaskUrgency.completed => c.cardBg,
    };

String urgencyLabel(TaskUrgency u) => switch (u) {
      TaskUrgency.overdue => 'Overdue',
      TaskUrgency.dueToday => 'Due today',
      TaskUrgency.upcoming => 'Upcoming',
      TaskUrgency.completed => 'Completed',
    };

String subtitleText(Task task, [TaskUrgency? precomputedUrgency]) {
  final typeName =
      task.type.name[0].toUpperCase() + task.type.name.substring(1);
  final u = precomputedUrgency ?? getUrgency(task);
  return '$typeName \u00b7 ${urgencyLabel(u)}';
}

IconData iconForTaskType(TaskType t) => switch (t) {
      TaskType.assignment => Icons.assignment_outlined,
      TaskType.exam => Icons.quiz_outlined,
      TaskType.ct => Icons.school_outlined,
      TaskType.viva => Icons.record_voice_over_outlined,
      TaskType.presentation => Icons.co_present_outlined,
      TaskType.lab => Icons.science_outlined,
      TaskType.project => Icons.architecture_outlined,
      TaskType.other => Icons.event_note_outlined,
      TaskType.custom => Icons.tune_rounded,
    };
