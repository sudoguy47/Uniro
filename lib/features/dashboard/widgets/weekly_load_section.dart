import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/task_utils.dart';
import '../../../state/app_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/weekly_bar_chart.dart';

/// Weekly Load Section — chart showing daily classes and tasks for the week.
/// Weeks begin on the week-start setting.
class WeeklyLoadSection extends StatelessWidget {
  const WeeklyLoadSection({super.key, this.onNavigateToRoutine});

  final VoidCallback? onNavigateToRoutine;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final weekStart =
        context.select((AppState s) => s.settings.weekStartDay);
    final monday = weekStartString(DateTime.now(), weekStart);
    final weeklyLoad = context.select((AppState s) => s.weeklyLoad(monday));
    final routineSlots = context.select((RoutineState r) => r.slots);

    final base = DateTime.tryParse(monday) ?? DateTime.now();
    final classLoad = <String, int>{};
    int totalClassesThisWeek = 0;
    for (int i = 0; i < 7; i++) {
      final d = base.add(Duration(days: i));
      final count = routineSlots.where((s) => s.weekday == d.weekday).length;
      classLoad[ymd(d)] = count;
      totalClassesThisWeek += count;
    }

    final int totalTasksThisWeek = weeklyLoad.values.fold(0, (a, b) => a + b);

    final String subtitle;
    if (totalClassesThisWeek > 0 && totalTasksThisWeek > 0) {
      subtitle = '$totalClassesThisWeek classes · $totalTasksThisWeek due';
    } else if (totalClassesThisWeek > 0) {
      subtitle =
          '$totalClassesThisWeek class${totalClassesThisWeek == 1 ? '' : 'es'} this week';
    } else if (totalTasksThisWeek > 0) {
      subtitle =
          '$totalTasksThisWeek task${totalTasksThisWeek == 1 ? '' : 's'} due';
    } else {
      subtitle = '0 due this week';
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Weekly load',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WeeklyBarChart(
              weekStart: monday,
              load: weeklyLoad,
              classLoad: classLoad,
            ),
          ),
        ],
      ),
    );
  }
}
