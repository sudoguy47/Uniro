/// Pure Pomodoro helpers: digit pairs, durations, dates.
/// Unit-tested in test/focus_logic_test.dart. No Flutter imports.
library;

/// Phases of a focus run.
enum FocusPhase { idle, focus, breakTime }

/// Two-character zero-padded pair for one flip card: 0 -> "00",
/// 5 -> "05", 24 -> "24". Clamped to 00..99 so both halves always match.
String twoDigit(int v) {
  final n = v < 0 ? 0 : (v > 99 ? 99 : v);
  return n.toString().padLeft(2, '0');
}

/// Minutes + seconds pairs for an MM:SS countdown value, e.g. 65 ->
/// ("01", "05"), 1500 -> ("25", "00"). Seconds roll 59 -> 00 naturally.
(String minutes, String seconds) clockPairs(int totalSeconds) {
  final t = totalSeconds < 0 ? 0 : totalSeconds;
  final mm = t ~/ 60;
  final ss = t % 60;
  return (twoDigit(mm), twoDigit(ss));
}

/// Compact human duration: 45 -> "45s", 90 -> "1m 30s", 1500 -> "25m",
/// 3720 -> "1h 2m".
String formatDuration(int totalSeconds) {
  final t = totalSeconds < 0 ? 0 : totalSeconds;
  if (t < 60) return '${t}s';
  final m = t ~/ 60;
  final s = t % 60;
  if (m < 60) return s == 0 ? '${m}m' : '${m}m ${s}s';
  final h = m ~/ 60;
  final rm = m % 60;
  return rm == 0 ? '${h}h' : '${h}h ${rm}m';
}

/// yyyy-MM-dd for [d] (local). Lexicographically comparable.
String focusYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// yyyy-MM-dd of the Monday of the week containing [day].
String weekStartMonday(DateTime day) {
  final base = day.subtract(Duration(days: (day.weekday - 1 + 7) % 7));
  return focusYmd(base);
}

/// "HH:mm" start-time label for an ISO-8601 timestamp.
String focusStartLabel(String startedAtIso) {
  try {
    final d = DateTime.parse(startedAtIso);
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '';
  }
}

/// Clamp an editable duration into [min]..[max].
int clampDuration(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/// Short weekday label: 1 -> "Mon" … 7 -> "Sun".
String weekdayShort(int weekday) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (weekday < 1 || weekday > 7) return '';
  return days[weekday - 1];
}

/// "HH:MM" for minutes since midnight.
String slotClock(int minutes) {
  final h = (minutes ~/ 60).clamp(0, 23);
  final m = (minutes % 60).clamp(0, 59);
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
