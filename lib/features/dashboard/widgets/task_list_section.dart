import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/task_card.dart';

/// Task List Section - Uses SliverList for tasks
class TaskListSection extends StatelessWidget {
  const TaskListSection({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingTasks = context.select((AppState s) => s.pendingTasks);

    if (pendingTasks.isEmpty) {
      final c = Theme.of(context).extension<AppColors>()!;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'No pending tasks',
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: pendingTasks.length,
        itemBuilder: (context, index) {
          final t = pendingTasks[index];
          return TaskCard(
            key: ValueKey(t.id),
            task: t,
            onComplete: () =>
                context.read<AppState>().completeTask(t.id),
          );
        },
      ),
    );
  }
}
