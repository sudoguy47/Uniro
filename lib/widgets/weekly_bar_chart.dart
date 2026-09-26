import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({
    super.key,
    required this.weekStart,
    required this.load,
    this.selectedDay,
    this.onDayPress,
  });

  final String weekStart;
  final Map<String, int> load;
  final String? selectedDay;
  final ValueChanged<String>? onDayPress;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  String? _tappedDay;

  static const _labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final maxCount = math.max(1, widget.load.values.fold(0, math.max));
    final activeSelectedDay = widget.selectedDay ?? _tappedDay;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 136,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final d = DateTime.parse(widget.weekStart).add(Duration(days: i));
                final dateStr =
                    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                final count = widget.load[dateStr] ?? 0;
                final barHeight = count > 0
                    ? math.max(12.0, (count / maxCount) * 58)
                    : 8.0;
                final isSelected = activeSelectedDay == dateStr;

                final Color barColor = switch (count) {
                  0 => c.chartBarEmpty,
                  _ when isSelected => c.accent,
                  _ => c.chartBarRed,
                };

                final countText = '$count task${count == 1 ? '' : 's'}';

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _tappedDay = (_tappedDay == dateStr) ? null : dateStr;
                      });
                      widget.onDayPress?.call(dateStr);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Floating label chip above bar
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 140),
                          opacity: isSelected ? 1.0 : 0.0,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.navActiveBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              countText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: c.navActiveText,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        // Bar
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: barHeight,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                            border: isSelected
                                ? Border.all(color: c.accent, width: 2)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? c.accent : c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? c.accent : c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a bar to filter that day',
            style: TextStyle(fontSize: 11, color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
