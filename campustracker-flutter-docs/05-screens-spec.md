# 05. Screen Specifications (Flutter Widgets)

---

## domain/task_utils.dart

```dart
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';

enum TaskUrgency { overdue, dueToday, upcoming, completed }

TaskUrgency getUrgency(Task task) {
  if (task.status == TaskStatus.completed) return TaskUrgency.completed;
  final today = DateTime.now();
  final due   = DateTime.parse(task.dueDate);
  final todayStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
  if (task.dueDate.compareTo(todayStr) < 0) return TaskUrgency.overdue;
  if (task.dueDate == todayStr) return TaskUrgency.dueToday;
  return TaskUrgency.upcoming;
}

Color urgencyBorderColor(TaskUrgency u, AppColors c) => switch (u) {
  TaskUrgency.overdue   => c.overdue,
  TaskUrgency.dueToday  => c.dueToday,
  TaskUrgency.upcoming  => c.accent,
  TaskUrgency.completed => c.textTertiary,
};

Color cardBgColor(TaskUrgency u, AppColors c) => switch (u) {
  TaskUrgency.overdue   => c.overdue,
  TaskUrgency.dueToday  => c.accent,
  TaskUrgency.upcoming  => c.upcoming,
  TaskUrgency.completed => c.cardBg,
};

String urgencyLabel(TaskUrgency u) => switch (u) {
  TaskUrgency.overdue   => 'Overdue',
  TaskUrgency.dueToday  => 'Due today',
  TaskUrgency.upcoming  => 'Upcoming',
  TaskUrgency.completed => 'Completed',
};

String subtitleText(Task task) {
  final typeName = task.type.name[0].toUpperCase() + task.type.name.substring(1);
  final u = getUrgency(task);
  return '$typeName \u00b7 ${urgencyLabel(u)}';
}
```

---

## widgets/task_card.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../domain/task_utils.dart';

class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onComplete,
    this.onDelete,
    this.showCompleted = false,
  });
  final Task task;
  final VoidCallback onComplete;
  final VoidCallback? onDelete;
  final bool showCompleted;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkCtrl;

  @override
  void initState() {
    super.initState();
    _checkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() { _checkCtrl.dispose(); super.dispose(); }

  void _onComplete() async {
    HapticFeedback.mediumImpact(); // GymMane mediumImpact
    await _checkCtrl.reverse();
    await _checkCtrl.forward();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final c   = Theme.of(context).extension<AppColors>()!;
    final u   = getUrgency(widget.task);
    final borderColor = urgencyBorderColor(u, c);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left color border
            Container(width: 3, color: borderColor),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Icon box
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: c.cardBgRaised,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.description_outlined,
                          size: 18, color: c.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.task.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: widget.showCompleted
                                  ? c.textTertiary : c.textPrimary,
                              decoration: widget.showCompleted
                                  ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitleText(widget.task),
                            style: TextStyle(
                              fontSize: 13, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showCompleted && widget.onDelete != null)
                          GestureDetector(
                            onTap: widget.onDelete,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: c.textSecondary),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Checkbox / Checkmark
                        ScaleTransition(
                          scale: _checkCtrl,
                          child: GestureDetector(
                            onTap: _onComplete,
                            child: AnimatedContainer(
                              duration: AppTheme.micro, // 140ms
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.showCompleted
                                    ? c.accent : Colors.transparent,
                                border: Border.all(
                                  color: widget.showCompleted
                                      ? c.accent : c.border,
                                  width: 2,
                                ),
                              ),
                              child: widget.showCompleted
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 18)
                                : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## screens/dashboard_screen.dart (structure)

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/ui_kit.dart';
import '../widgets/new_task_sheet.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showNewTask = false;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c   = Theme.of(context).extension<AppColors>()!;
    final app = context.watch<AppState>();
    final pending = app.pendingTasks;
    final hero = app.heroTasks;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_greeting, style: TextStyle(
                                    fontSize: 13, color: c.textSecondary)),
                                const SizedBox(height: 2),
                                Text('Hi, ${app.settings.name}',
                                  style: TextStyle(fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: c.textPrimary)),
                              ],
                            )),
                            // Avatar
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.accent,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                app.settings.name.isNotEmpty
                                    ? app.settings.name[0].toUpperCase() : 'U',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // HERO CAROUSEL
                      if (hero.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        HeroCarousel(tasks: hero),
                      ],

                      // WEEKLY LOAD
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Weekly load', style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: c.textPrimary)),
                            Text('${pending.length} due this week',
                              style: TextStyle(
                                  fontSize: 13, color: c.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: WeeklyBarChart(
                          weekStart: _getMondayOfWeek(),
                          load: app.weeklyLoad(_getMondayOfWeek()),
                          onDayPress: (_) {},
                        ),
                      ),

                      // FILTER CHIPS
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _chip('All', null, app, c),
                            ...TaskType.values.map((t) =>
                              _chip(t.name[0].toUpperCase() + t.name.substring(1), t, app, c)),
                          ],
                        ),
                      ),

                      // TASK LIST
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: pending.map((t) => TaskCard(
                            task: t,
                            onComplete: () => app.completeTask(t.id),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // FAB
          Positioned(
            bottom: 90, right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _showNewTask = true),
              child: Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: c.fabBg, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26,
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Icon(Icons.add, color: c.fabIcon, size: 24),
              ),
            ),
          ),

          // NEW TASK SHEET
          if (_showNewTask)
            NewTaskSheet(onClose: () => setState(() => _showNewTask = false)),
        ],
      ),
    );
  }

  Widget _chip(String label, TaskType? type, AppState app, AppColors c) {
    final active = app.activeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AppFilterChip(
        label: label, active: active,
        onTap: () => app.setFilter(type),
      ),
    );
  }

  String _getMondayOfWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2,'0')}-${monday.day.toString().padLeft(2,'0')}';
  }
}
```
