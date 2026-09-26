import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/task_card.dart';

class DoneScreen extends StatefulWidget {
  const DoneScreen({super.key});

  @override
  State<DoneScreen> createState() => _DoneScreenState();
}

class _DoneScreenState extends State<DoneScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final completed = context.select((AppState s) => s.completedTasks);

    return Scaffold(
      backgroundColor: c.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${completed.length} task${completed.length == 1 ? '' : 's'} completed',
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 20),

              if (completed.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48, color: c.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'No completed tasks yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemExtent: TaskCard.totalItemExtent,
                  itemCount: completed.length,
                  itemBuilder: (context, index) {
                    final t = completed[index];
                    return TaskCard(
                      key: ValueKey(t.id),
                      task: t,
                      showCompleted: true,
                      onComplete: () =>
                          context.read<AppState>().uncompleteTask(t.id),
                      onDelete: () =>
                          context.read<AppState>().deleteTask(t.id),
                    );
                  },
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
