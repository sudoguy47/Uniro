/// App-wide motivational quotes (user-supplied list).
///
/// - Dashboard header rotates to a new quote every 10 minutes
///   ([quoteForSlot]).
/// - The 6 AM notification sends exactly ONE quote ([quoteOfTheDay]) plus
///   a reminder of today's classes/tasks.
/// Pure + unit-tested. No Flutter imports.
library;

/// All 50 quotes, in the user's order.
const kQuotes = [
  'Grow through what you go through.',
  'Be better, not perfect.',
  'Small steps lead to big changes.',
  'Choose kindness whenever you can.',
  'Trust God and do your best.',
  'Progress takes patience.',
  'Learn, grow, and keep moving forward.',
  'Your pace is your own.',
  'Let gratitude shape your perspective.',
  'Be the reason someone smiles.',
  'Chase progress, not perfection.',
  'Stay humble, dream big.',
  'Every mistake teaches something valuable.',
  'Kindness is never wasted.',
  'Believe in the power of small steps.',
  'Make time for what matters.',
  'Be curious, stay humble.',
  'Let your actions reflect your values.',
  'Growth begins outside your comfort zone.',
  'A peaceful mind is a powerful mind.',
  'Choose progress over excuses.',
  'Be patient with your journey.',
  'Success means little without kindness.',
  'Keep learning, keep becoming.',
  'Let faith be stronger than fear.',
  'Your effort matters, even when unseen.',
  'Be gentle with yourself and others.',
  'Difficult days build resilience.',
  'Gratitude makes ordinary moments meaningful.',
  'Do good without expecting anything back.',
  'Stay focused on what you can control.',
  'Your character matters more than applause.',
  'Every day is a chance to improve.',
  'Listen more, judge less.',
  'Be proud of how far you\u2019ve come.',
  'Make your life useful to others.',
  'Discipline carries you when motivation fades.',
  'Choose purpose over comparison.',
  'Let your failures teach, not define you.',
  'Be someone your younger self admires.',
  'Faith gives hope; effort creates progress.',
  'You can restart without starting over.',
  'Great things take time and consistency.',
  'Protect your peace, nurture your growth.',
  'Stay kind in a world that rushes.',
  'Success is better when shared.',
  'Learn to rest without feeling guilty.',
  'Become wiser, kinder, and more courageous.',
  'You don\u2019t have to prove your worth.',
  'Live simply, love deeply, grow endlessly.',
];

/// 10-minute slot index since epoch (144 slots/day). A new quote every
/// 10 minutes, deterministic — same instant always maps to the same quote.
int quoteSlotIndex(DateTime now) {
  final slot = now.millisecondsSinceEpoch ~/ (10 * 60 * 1000);
  return slot % kQuotes.length;
}

/// Dashboard header quote: rotates every 10 minutes.
String quoteForSlot(DateTime now) => kQuotes[quoteSlotIndex(now)];

/// Morning-notification quote: exactly one per calendar day, stable all day.
String quoteOfTheDay(DateTime now) {
  final startOfYear = DateTime(now.year, 1, 1);
  final dayOfYear = now.difference(startOfYear).inDays;
  return kQuotes[dayOfYear % kQuotes.length];
}

/// Strips wrapping quotation marks (straight or curly, single or double)
/// so dashboard quotes never render with "..." around them, no matter
/// how the source string is punctuated.
String stripQuoteMarks(String s) {
  const marks = {'"', '“', '”', "'", '‘', '’'};
  var out = s.trim();
  while (out.length >= 2 &&
      marks.contains(out[0]) &&
      marks.contains(out[out.length - 1])) {
    out = out.substring(1, out.length - 1).trim();
  }
  return out;
}

/// "Remember today" line: counts today's pending tasks (dueDate == today)
/// and today's classes (weekday match). Pure; callers pass plain data.
String todayAgendaLine({
  required int classCount,
  required int taskCount,
}) {
  if (classCount <= 0 && taskCount <= 0) {
    return 'Nothing scheduled today — enjoy your day!';
  }
  final parts = <String>[];
  if (classCount > 0) {
    parts.add('$classCount class${classCount == 1 ? '' : 'es'}');
  }
  if (taskCount > 0) {
    parts.add('$taskCount task${taskCount == 1 ? '' : 's'} due');
  }
  return 'Today: ${parts.join(' and ')}.';
}
