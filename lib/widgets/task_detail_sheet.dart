import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../domain/haptics.dart';
import '../domain/task_utils.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';

/// Compact task detail sheet: due date/time, priority, course, description,
/// reminders, and a Mark done / Reopen action. Used from the dashboard
/// weekly agenda (there is no dedicated task detail screen).
Future<void> showTaskDetailSheet(BuildContext context, Task task) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskDetailSheet(taskId: task.id),
  );
}

class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.taskId});
  final String taskId;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final app = context.watch<AppState>();
    Task? task;
    for (final t in app.tasks) {
      if (t.id == taskId) {
        task = t;
        break;
      }
    }
    if (task == null) {
      return const SizedBox.shrink();
    }
    final t = task;
    final u = getUrgency(t);
    final course = t.courseId != null
        ? context.read<RoutineState>().courseById(t.courseId!)
        : null;
    final completed = t.status == TaskStatus.completed;
    final dueDate = DateTime.tryParse(t.dueDate);
    final dateLabel = dueDate != null
        ? DateFormat('EEE, MMM d, yyyy').format(dueDate)
        : t.dueDate;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.cardBgRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconForTaskType(t.type),
                      size: 20, color: c.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          decoration: completed
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${taskCategoryLabel(t)} · ${urgencyLabel(u)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: c.textSecondary),
                            ),
                          ),
                          if (t.type == TaskType.custom) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _editCustomCategory(context, t),
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: Icon(Icons.edit_outlined,
                                    size: 14, color: c.accent),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.event_outlined,
              label: dateLabel +
                  (t.hasTime && t.dueTime != null ? ' at ${t.dueTime}' : ''),
              colors: c,
            ),
            _InfoRow(
              icon: Icons.flag_outlined,
              label:
                  'Priority: ${t.priority.name[0].toUpperCase()}${t.priority.name.substring(1)}',
              colors: c,
            ),
            if (course != null)
              _InfoRow(
                icon: Icons.menu_book_outlined,
                label: course.code != null && course.code!.trim().isNotEmpty
                    ? '${course.code} · ${course.name}'
                    : course.name,
                colors: c,
              ),
            if (t.description != null && t.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                t.description!.trim(),
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
            ],
            if (t.reminders.isNotEmpty)
              _InfoRow(
                icon: Icons.notifications_none_outlined,
                label:
                    '${t.reminders.length} reminder${t.reminders.length == 1 ? '' : 's'} set',
                colors: c,
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      PremiumHaptics.tap();
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.inputBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      PremiumHaptics.confirm();
                      final notifier = context.read<AppState>();
                      if (completed) {
                        notifier.uncompleteTask(t.id);
                      } else {
                        notifier.completeTask(t.id);
                      }
                      Navigator.pop(context);
                    },
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        completed ? 'Reopen' : 'Mark done',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _editCustomCategory(BuildContext context, Task task) async {
    final c = Theme.of(context).extension<AppColors>()!;
    final ctrl = TextEditingController(text: task.customCategory ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Category Name',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: c.textPrimary),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(fontSize: 14, color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Weekly CT, Personal Work...',
            hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
            filled: true,
            fillColor: c.inputBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Save',
                style: TextStyle(
                    color: c.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (newName != null && context.mounted) {
      PremiumHaptics.confirm();
      final updated = task.copyWith(
        customCategory: newName.isEmpty ? 'Custom' : newName,
      );
      context.read<AppState>().updateTask(task.id, updated);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
