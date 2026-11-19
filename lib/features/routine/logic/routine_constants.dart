const courseWeekdayNames = <int, String>{
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Weekdays ordered from [weekStart] (1–7, DateTime convention).
List<int> orderedWeekdays(int weekStart) {
  return List.generate(7, (i) => ((weekStart - 1 + i) % 7) + 1);
}

/// Calendar date of [weekday] in the current week (per [weekStart]).
DateTime dateForWeekday(DateTime today, int weekStart, int weekday) {
  final base = today
      .subtract(Duration(days: (today.weekday - weekStart + 7) % 7));
  return DateTime(base.year, base.month, base.day)
      .add(Duration(days: (weekday - weekStart + 7) % 7));
}

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
