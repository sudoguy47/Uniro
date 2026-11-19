import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import '../theme/app_colors.dart';

class WeeklyBarChart extends StatefulWidget {
  const WeeklyBarChart({
    super.key,
    required this.weekStart,
    required this.load,
    this.classLoad,
    this.selectedDay,
    this.onDayPress,
  });

  final String weekStart;
  final Map<String, int> load;
  final Map<String, int>? classLoad;
  final String? selectedDay;
  final ValueChanged<String>? onDayPress;

  @override
  State<WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<WeeklyBarChart> {
  String? _tappedDay;

  static const _weekdayLabels = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final activeSelectedDay = widget.selectedDay ?? _tappedDay;

    // Parse weekStart ONCE per build and derive date keys, day numbers, and labels
    final base = DateTime.parse(widget.weekStart);
    final dateStrs = List<String>.generate(7, (i) {
      final d = base.add(Duration(days: i));
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    });
    final dayNums = List<int>.generate(7, (i) => base.add(Duration(days: i)).day);
    final dayLabels = List<String>.generate(7, (i) {
      final d = base.add(Duration(days: i));
      return _weekdayLabels[d.weekday];
    });

    int calcMax = 1;
    for (final dateStr in dateStrs) {
      final t = widget.load[dateStr] ?? 0;
      final cl = widget.classLoad?[dateStr] ?? 0;
      final sum = t + cl;
      if (sum > calcMax) calcMax = sum;
    }
    final maxCount = calcMax;

    final String? selectedCountText;
    if (activeSelectedDay != null) {
      final tCount = widget.load[activeSelectedDay] ?? 0;
      final clCount = widget.classLoad?[activeSelectedDay] ?? 0;
      if (clCount > 0 && tCount > 0) {
        selectedCountText =
            '$clCount class${clCount == 1 ? '' : 'es'}, $tCount task${tCount == 1 ? '' : 's'}';
      } else if (clCount > 0) {
        selectedCountText = '$clCount class${clCount == 1 ? '' : 'es'}';
      } else if (tCount > 0) {
        selectedCountText = '$tCount task${tCount == 1 ? '' : 's'}';
      } else {
        selectedCountText = '0 items';
      }
    } else {
      selectedCountText = null;
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
          // Tooltip banner above chart row: clamped and centered above bars so it never overlaps or clips
          SizedBox(
            height: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: selectedCountText != null ? 1.0 : 0.0,
              child: selectedCountText != null
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: c.navActiveBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          selectedCountText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: c.navActiveText,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 6),
          // minHeight instead of a fixed height: grows instead of overflowing
          // at large accessibility text scales
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final dateStr = dateStrs[i];
                final taskCount = widget.load[dateStr] ?? 0;
                final classCount = widget.classLoad?[dateStr] ?? 0;
                final totalCount = taskCount + classCount;
                final isSelected = activeSelectedDay == dateStr;

                final barHeight = totalCount > 0
                    ? math.max(12.0, (totalCount / maxCount) * 58)
                    : 8.0;

                Widget barWidget;
                if (totalCount == 0) {
                  barWidget = Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: c.chartBarEmpty,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      border: isSelected
                          ? Border.all(color: c.accent, width: 2)
                          : null,
                    ),
                  );
                } else if (classCount > 0 && taskCount > 0) {
                  barWidget = Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: barHeight,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      border: isSelected
                          ? Border.all(color: c.accent, width: 2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          flex: taskCount,
                          child: Container(
                            width: double.infinity,
                            color: c.chartBarRed,
                          ),
                        ),
                        Expanded(
                          flex: classCount,
                          child: Container(
                            width: double.infinity,
                            color: c.chartBarGold,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  final Color barColor =
                      classCount > 0 ? c.chartBarGold : c.chartBarRed;

                  barWidget = Container(
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
                  );
                }

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      PremiumHaptics.select();
                      setState(() {
                        _tappedDay = (_tappedDay == dateStr) ? null : dateStr;
                      });
                      widget.onDayPress?.call(dateStr);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Bar
                        barWidget,
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? c.accent : c.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${dayNums[i]}',
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
