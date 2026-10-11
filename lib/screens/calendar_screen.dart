import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';
import '../widgets/monthly_calendar.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/task_card.dart';
import '../widgets/new_task_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _viewMode = 'monthly';
  DateTime _currentDate = DateTime.now();
  late String _selectedDate;
  bool _showNewTask = false;

  // Cached formatters — constructing DateFormat per build parses ICU
  // skeletons each time (~µs that add up at 120Hz scroll + tab switches).
  static final _ymdFmt = DateFormat('yyyy-MM-dd');
  static final _ymFmt = DateFormat('yyyy-MM');
  static final _monthYearFmt = DateFormat('MMMM yyyy');
  static final _mmmDFmt = DateFormat('MMM d');
  static final _mmmDYFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = _ymdFmt.format(today);
  }

  String get _monthStr => _ymFmt.format(_currentDate);

  String get _getMondayOfWeek {
    final monday = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
    return _ymdFmt.format(monday);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final tasks = context.select((AppState s) => s.tasks);
    final monday = _getMondayOfWeek;
    final weeklyLoad = context.select((AppState s) => s.weeklyLoad(monday));

    final selectedTasks =
        tasks.where((t) => t.dueDate == _selectedDate).toList();

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _viewMode = 'monthly');
                            },
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              decoration: BoxDecoration(
                                color: _viewMode == 'monthly'
                                    ? c.navActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Monthly',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _viewMode == 'monthly'
                                      ? c.navActiveText
                                      : c.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _viewMode = 'weekly');
                            },
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              decoration: BoxDecoration(
                                color: _viewMode == 'weekly'
                                    ? c.navActiveBg
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Weekly',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _viewMode == 'weekly'
                                      ? c.navActiveText
                                      : c.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(Icons.chevron_left, color: c.textPrimary),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_viewMode == 'monthly') {
                              _currentDate = DateTime(_currentDate.year,
                                  _currentDate.month - 1, 1);
                            } else {
                              _currentDate = _currentDate
                                  .subtract(const Duration(days: 7));
                            }
                          });
                        },
                      ),
                      Text(
                        _viewMode == 'monthly'
                            ? _monthYearFmt.format(_currentDate)
                            : 'Week of ${_mmmDFmt.format(DateTime.parse(monday))}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.chevron_right, color: c.textPrimary),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_viewMode == 'monthly') {
                              _currentDate = DateTime(_currentDate.year,
                                  _currentDate.month + 1, 1);
                            } else {
                              _currentDate =
                                  _currentDate.add(const Duration(days: 7));
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_viewMode == 'monthly')
                    MonthlyCalendar(
                      month: _monthStr,
                      selectedDate: _selectedDate,
                      tasks: tasks,
                      onDatePress: (d) => setState(() => _selectedDate = d),
                    )
                  else
                    WeeklyBarChart(
                      weekStart: monday,
                      load: weeklyLoad,
                      selectedDay: _selectedDate,
                      onDayPress: (d) => setState(() => _selectedDate = d),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tasks for ${_mmmDYFmt.format(DateTime.parse(_selectedDate))}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                        ),
                      ),
                      Text(
                        '${selectedTasks.length} task${selectedTasks.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (selectedTasks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            Icon(Icons.event_available_outlined,
                                size: 40, color: c.textTertiary),
                            const SizedBox(height: 8),
                            Text(
                              'No tasks scheduled for this day',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 14),
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
                      itemCount: selectedTasks.length,
                      itemBuilder: (context, index) {
                        final t = selectedTasks[index];
                        final isCompleted = t.status == TaskStatus.completed;
                        return TaskCard(
                          key: ValueKey(t.id),
                          task: t,
                          showCompleted: isCompleted,
                          onComplete: () {
                            if (isCompleted) {
                              context.read<AppState>().uncompleteTask(t.id);
                            } else {
                              context.read<AppState>().completeTask(t.id);
                            }
                          },
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

          Positioned(
            bottom: 96 + MediaQuery.of(context).padding.bottom,
            right: 16,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AppState>().setNewTaskOpen(true);
                setState(() => _showNewTask = true);
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.fabBg,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(Icons.add, color: c.fabIcon, size: 24),
              ),
            ),
          ),

          if (_showNewTask)
            NewTaskSheet(
              initialDate: DateTime.tryParse(_selectedDate),
              onClose: () {
                context.read<AppState>().setNewTaskOpen(false);
                setState(() => _showNewTask = false);
              },
            ),
        ],
      ),
    );
  }
}
