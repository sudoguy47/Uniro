import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../domain/task_utils.dart';

class MonthlyCalendar extends StatelessWidget {
  const MonthlyCalendar({
    super.key,
    required this.month, // YYYY-MM
    this.selectedDate,   // YYYY-MM-DD
    required this.tasks,
    required this.onDatePress,
  });

  final String month;
  final String? selectedDate;
  final List<Task> tasks;
  final ValueChanged<String> onDatePress;

  static const _daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final parsedMonth = DateTime.parse('$month-01');
    final firstWeekday = parsedMonth.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(parsedMonth.year, parsedMonth.month + 1, 0).day;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final tasksByDate = <String, List<Task>>{};
    for (final t in tasks) {
      tasksByDate.putIfAbsent(t.dueDate, () => []).add(t);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: _daysOfWeek
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks * 7 days
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 44,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - firstWeekday + 1;
              if (dayOffset < 1 || dayOffset > daysInMonth) {
                return const SizedBox();
              }

              final dateStr =
                  '${parsedMonth.year}-${parsedMonth.month.toString().padLeft(2, '0')}-${dayOffset.toString().padLeft(2, '0')}';
              final isToday = dateStr == todayStr;
              final isSelected = dateStr == selectedDate;

              final dayTasks = tasksByDate[dateStr] ?? const [];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDatePress(dateStr);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isSelected ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday && !isSelected
                            ? Border.all(color: c.accent, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayOffset',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? c.accent
                                  : c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: dayTasks.take(3).map((t) {
                        final u = getUrgency(t);
                        final dotColor = switch (u) {
                          TaskUrgency.overdue => c.overdue,
                          TaskUrgency.dueToday => c.dueToday,
                          _ when t.type == TaskType.exam => c.chartBarGold,
                          _ => c.upcoming,
                        };
                        return Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
