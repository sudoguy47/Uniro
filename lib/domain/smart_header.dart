/// Smart Contextual Header Engine — pure, unit-testable logic for the
/// dashboard header's alternating Time Greeting (State A) /
/// Context-Aware message (State B) loop.
///
/// No Flutter imports on purpose: everything here is deterministic and
/// injectable so it can be covered by plain Dart unit tests.
///
/// Spec notes:
/// - State A alternates on every pass through that state (where the
///   time bucket offers two options).
/// - State B prefers Category 11 (live) messages when any condition is
///   true; the widget interleaves them with the shuffle bag so the
///   header never feels static.
/// - The shuffle bag never repeats the same message back-to-back,
///   including across refills (`nextMessage != lastMessage`).
/// - Strictly no emojis; the banned four-letter greeting is never used.
library;

import 'dart:math';

// ── Categories 1–9 — the shuffle-bag corpus ────────────────────────────────
// Verbatim product-approved copy. [userName] is injected wherever the copy
// references it.
Map<String, List<String>> buildCategorizedHeaderMessages(String userName) => {
      'WELCOME': [
        'Good to see you, $userName.',
        'Welcome back, $userName!',
        'Nice to have you here, $userName.',
        'Great to see you again.',
        "Glad you're here.",
        "It's good to have you back.",
        'Good to have you back, $userName.',
        'Lovely to see you again.',
        'Nice to have you around.',
        'Always good to see you.',
      ],
      'DAILY LIFE': [
        'Ready for a new day, $userName?',
        "What's the plan for today?",
        "Let's make today count.",
        'A new day, a fresh start.',
        'One day at a time.',
        'Your day starts here.',
        "Let's see what today brings.",
        'Make room for something great.',
        'Another day, another opportunity.',
        "Let's get today started.",
      ],
      'STUDY & LEARNING': [
        'Ready to learn something new?',
        'What are we studying today?',
        "Let's make some progress.",
        'Time to hit the books?',
        'One step closer to your goals.',
        'Small steps, big progress.',
        "Let's get those studies going.",
        "What's on your study list?",
        'Learning starts with curiosity.',
        'Ready for a productive session?',
      ],
      'PRODUCTIVITY': [
        "What's on your to-do list?",
        "Let's get things done.",
        "What's your next move?",
        'One task at a time.',
        "Let's tackle today's priorities.",
        'Ready to be productive?',
        'A little progress goes a long way.',
        "Let's organize your day.",
        'Make today productive.',
        "Let's turn plans into progress.",
      ],
      'SCHEDULE': [
        'Got classes today?',
        "What's your next class?",
        'Ready for your next lecture?',
        "Let's check your schedule.",
        'Your day, organized.',
        "What's coming up next?",
        "Don't miss what's important.",
        "Let's get your day in order.",
      ],
      'DEADLINES': [
        'Got something due soon?',
        "Let's stay ahead of deadlines.",
        "Time to prepare for what's next.",
        'One deadline at a time.',
        "Let's get that assignment done.",
        'Stay focused, stay prepared.',
        "Exams coming up? You've got this.",
        "Let's make time for what matters.",
      ],
      'DEEP FOCUS': [
        'Ready to focus?',
        "Let's get in the zone.",
        'Time for a little deep work.',
        'Focus mode: on.',
        'One session at a time.',
        "Let's make this session count.",
        'Distractions can wait.',
        'Your next focus session starts here.',
        'Take a breath, then begin.',
        'Time to lock in.',
      ],
      'NOTES & IDEAS': [
        'Got an idea to save?',
        "What's worth remembering today?",
        'Your thoughts, your space.',
        'Every idea deserves a place.',
        "Let's capture that thought.",
        'Something on your mind?',
        'Write it down before you forget.',
        'A little note goes a long way.',
      ],
      'DAILY FUEL': [
        'Progress over perfection.',
        "You're doing better than you think.",
        'Keep showing up.',
        'Little by little, it adds up.',
        'Your pace, your progress.',
        'Every step matters.',
        'Stay consistent, $userName.',
        'Keep moving forward.',
        "You've got this.",
        'Today is another chance.',
      ],
    };

/// One message coming out of the shuffle bag: category (used as the
/// uppercase overline label) + ready-to-render text.
class HeaderMessage {
  const HeaderMessage(this.category, this.text);
  final String category;
  final String text;
}

/// Category 11 — a live, data-driven "special" message.
class LiveHeaderMessage {
  const LiveHeaderMessage(this.label, this.text);
  final String label;
  final String text;
}

/// Flattened Categories 1–9 corpus with [userName] injected, one entry
/// per message. Exposed for the widget (bag construction) and for tests.
List<HeaderMessage> flattenedBagMessages(String userName) => [
      for (final entry in buildCategorizedHeaderMessages(userName).entries)
        for (final message in entry.value) HeaderMessage(entry.key, message),
    ];

/// In-place Fisher-Yates shuffle. [random] is injectable for tests.
void fisherYatesShuffle<T>(List<T> list, [Random? random]) {
  final rng = random ?? Random();
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
}

/// Non-repeating shuffle bag over Categories 1–9.
///
/// Each refill is a fresh Fisher-Yates shuffle. The bag never hands out
/// the same text twice in a row — even across a refill — satisfying the
/// `nextMessage != lastMessage` guarantee.
class ShuffleBag {
  ShuffleBag({required List<HeaderMessage> items, Random? random})
      : assert(items.isNotEmpty, 'shuffle bag needs at least one message'),
        _items = List.of(items),
        _random = random ?? Random();

  final List<HeaderMessage> _items;
  final Random _random;
  List<HeaderMessage> _bag = const [];

  /// Text of the previously drawn message. Shared across draws so live
  /// (Category 11) messages can also suppress immediate repeats.
  String? lastText;

  HeaderMessage next() {
    if (_bag.isEmpty) _refill();
    var idx = _bag.length - 1;
    if (lastText != null && _bag.length > 1) {
      for (var i = _bag.length - 1; i >= 0; i--) {
        if (_bag[i].text != lastText) {
          idx = i;
          break;
        }
      }
    }
    final msg = _bag.removeAt(idx);
    lastText = msg.text;
    return msg;
  }

  void _refill() {
    _bag = List.of(_items);
    fisherYatesShuffle(_bag, _random);
    // The next draw comes from the end of the list; if it equals the last
    // shown message, swap it backwards so consecutive draws never repeat.
    if (_bag.length > 1 && lastText != null && _bag.last.text == lastText) {
      final last = _bag.last;
      _bag[_bag.length - 1] = _bag[_bag.length - 2];
      _bag[_bag.length - 2] = last;
    }
  }
}

// ── State A — time-based greeting buckets ───────────────────────────────────

/// Options for the time bucket containing [now]. Time ranges (local):
///   05:00–10:59  -> "Good morning" / "Ready to start your day?"
///   11:00–13:59  -> "Good afternoon" / "How's your day going?"
///   14:00–16:59  -> "How's the day treating you?"
///   17:00–20:59  -> "Good evening" / "How did today go?"
///   21:00–23:59  -> "Still working on something?"
///   00:00–04:59  -> "Burning the midnight oil?"
/// Buckets with two options alternate on consecutive State A passes.
List<String> timeGreetingOptions(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) {
    return const ['Good morning', 'Ready to start your day?'];
  }
  if (h >= 11 && h < 14) {
    return const ['Good afternoon', "How's your day going?"];
  }
  if (h >= 14 && h < 17) return const ["How's the day treating you?"];
  if (h >= 17 && h < 21) return const ['Good evening', 'How did today go?'];
  if (h >= 21) return const ['Still working on something?'];
  return const ['Burning the midnight oil?'];
}

// ── Category 11 — live conditions ───────────────────────────────────────────

/// Plain-data snapshot of everything Category 11 needs. Built by the
/// widget from AppState / RoutineState / NotesState / FocusState so this
/// library stays Flutter-free.
class SmartHeaderSnapshot {
  const SmartHeaderSnapshot({
    required this.hasAnyTasks,
    required this.allTasksCompleted,
    required this.pendingTaskCount,
    required this.pendingDueTodayCount,
    required this.pendingExamWithin3Days,
    required this.upcomingClassesToday,
    required this.minutesUntilNextClass,
    required this.pomodoroCompletedToday,
    required this.noteCount,
    required this.isNewSemester,
    required this.routineAvailable,
  });

  /// Whether any tasks exist at all (used by ALL COMPLETE).
  final bool hasAnyTasks;

  /// True when every existing task is completed (and at least one exists).
  final bool allTasksCompleted;

  /// Pending (active) tasks across all dates.
  final int pendingTaskCount;

  /// Pending tasks whose dueDate is today.
  final int pendingDueTodayCount;

  /// A pending exam-type task is due within the next 3 days (incl. today).
  final bool pendingExamWithin3Days;

  /// Classes still to come today (an in-progress class counts as upcoming).
  final int upcomingClassesToday;

  /// Minutes until the next class today starts (>= 0), or null when none
  /// is scheduled later today.
  final int? minutesUntilNextClass;

  /// At least one completed Pomodoro focus session was recorded today.
  final bool pomodoroCompletedToday;

  final int noteCount;

  /// Fresh-start proxy: the app has no semester model yet, so this is true
  /// during the first weeks after first launch. Documented limitation.
  final bool isNewSemester;

  /// Routine is configured (at least one class slot exists).
  final bool routineAvailable;
}

/// Category 11 — evaluates live conditions in spec order. Returns every
/// condition that is currently true; the widget round-robins through the
/// result on alternating State B cycles, interleaved with the shuffle bag.
List<LiveHeaderMessage> activeLiveMessages(SmartHeaderSnapshot s) {
  final out = <LiveHeaderMessage>[];
  if (s.pendingDueTodayCount == 0) {
    out.add(const LiveHeaderMessage(
      'CLEAR SCHEDULE',
      "A clear day. What would you like to do?",
    ));
  }
  if (s.hasAnyTasks && s.allTasksCompleted) {
    out.add(const LiveHeaderMessage(
      'ALL COMPLETE',
      "Everything done. Nice work!",
    ));
  }
  if (s.pendingTaskCount >= 5) {
    out.add(const LiveHeaderMessage(
      'HIGH WORKLOAD',
      "Let's take things one at a time.",
    ));
  }
  if (s.pendingExamWithin3Days) {
    out.add(const LiveHeaderMessage(
      'EXAM ALERT',
      "Your exam is getting closer. Stay prepared.",
    ));
  }
  if (s.upcomingClassesToday == 0) {
    out.add(const LiveHeaderMessage(
      'FREE DAY',
      "No classes coming up. Enjoy the time!",
    ));
  }
  if (s.minutesUntilNextClass != null && s.minutesUntilNextClass! <= 60) {
    out.add(const LiveHeaderMessage(
      'UP NEXT',
      "Your next class is coming up.",
    ));
  }
  if (s.pomodoroCompletedToday) {
    out.add(const LiveHeaderMessage(
      'FOCUS COMPLETE',
      "Great focus session!",
    ));
  }
  if (s.noteCount == 0) {
    out.add(const LiveHeaderMessage(
      'QUICK NOTE',
      "Got something worth writing down?",
    ));
  }
  if (s.isNewSemester) {
    out.add(const LiveHeaderMessage(
      'NEW SEMESTER',
      "A new semester, a fresh start.",
    ));
  }
  if (s.routineAvailable) {
    out.add(const LiveHeaderMessage(
      'SCHEDULE READY',
      "Your schedule is ready. Let's plan ahead.",
    ));
  }
  return out;
}
