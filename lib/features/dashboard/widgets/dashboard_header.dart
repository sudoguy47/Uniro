import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/focus_logic.dart';
import '../../../domain/haptics.dart';
import '../../../domain/smart_header.dart';
import '../../../models/task.dart';
import '../../../services/local_store.dart';
import '../../../state/app_state.dart';
import '../../../state/focus_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';

/// Smart Contextual Header — alternates continuously between
///   State A (Time Greeting, 4s): time-bucket subtitle + user name.
///   State B (Context-Aware, 6s): Category 11 live message when a
///     dashboard condition is true (interleaved with the shuffle bag),
///     otherwise a non-repeating Fisher-Yates draw from Categories 1–9.
///
/// No repeating messages back-to-back, no layout shift between 1-line and
/// 2-line content (fixed 68px slot, Align.centerLeft), tap to cycle early.
/// Listens ONLY to specific settings (name, avatarUri).
class DashboardHeader extends StatefulWidget {
  const DashboardHeader({
    super.key,
    this.onNavigateToProfile,
    this.onPlus,
    this.plusKey,
    this.plusOpen = false,
  });

  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onPlus;
  final GlobalKey? plusKey;
  final bool plusOpen;

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

/// What the header shows while in State B.
class _ContextMessage {
  const _ContextMessage(this.label, this.text);
  final String label;
  final String text;
}

class _DashboardHeaderState extends State<DashboardHeader> {
  Timer? _cycleTimer;

  /// true while State A (Greeting) is on screen, false for State B.
  bool _isStateA = true;

  /// Toggled on every State A pass; flips between the two options in
  /// two-option time buckets.
  bool _greetingVariant = false;

  /// Counts State B entries; drives the live/bag interleaving.
  int _stateBCount = 0;

  /// Round-robin cursor across the currently active live messages.
  int _liveCursor = 0;

  /// Shared memory so neither bag draws nor live picks repeat back-to-back.
  String? _lastMessageText;

  /// The message currently on screen in State B.
  _ContextMessage? _contextMessage;

  ShuffleBag? _bag;
  String? _bagUserName;

  /// Milliseconds of first app launch; powers the NEW SEMESTER proxy.
  int? _firstSeenMs;

  @override
  void initState() {
    super.initState();
    try {
      final existing = LocalStore.instance.load('first_seen_ms');
      if (existing is num) {
        _firstSeenMs = existing.toInt();
      } else {
        _firstSeenMs = DateTime.now().millisecondsSinceEpoch;
        LocalStore.instance.save('first_seen_ms', _firstSeenMs);
      }
    } catch (_) {
      _firstSeenMs = null;
    }
    _scheduleCycle();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  /// State A stays for 4 seconds, State B for 6 seconds.
  void _scheduleCycle() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer(Duration(seconds: _isStateA ? 4 : 6), _onCycleTimer);
  }

  void _onCycleTimer() {
    if (!mounted) return;
    setState(_advanceState);
    _scheduleCycle();
  }

  void _manualCycle() {
    PremiumHaptics.select();
    setState(_advanceState);
    _scheduleCycle();
  }

  /// Enters the other state. Picks the next contextual message when
  /// entering State B; flips the greeting variant when entering State A.
  void _advanceState() {
    if (_isStateA) {
      _isStateA = false;
      _stateBCount += 1;
      _contextMessage = _pickContextMessage();
    } else {
      _isStateA = true;
      _greetingVariant = !_greetingVariant;
    }
  }

  ShuffleBag _ensureBag(String userName) {
    if (_bag != null && _bagUserName == userName) return _bag!;
    _bagUserName = userName;
    _bag = ShuffleBag(items: flattenedBagMessages(userName));
    return _bag!;
  }

  /// Picks what State B shows next.
  ///
  /// Category 11 (live) conditions are surfaced on alternating passes —
  /// when any are true, every odd State B pass shows the next matching
  /// live message (round-robin) and every even pass draws from the
  /// shuffle bag. When nothing is true, every pass uses the bag. The bag
  /// never repeats the previous message back-to-back, even across refills.
  _ContextMessage _pickContextMessage() {
    final app = context.read<AppState>();
    final routine = context.read<RoutineState>();
    final notes = context.read<NotesState>();
    final focus = context.read<FocusState>();

    final userName = _cleanName(app.settings.name);
    final snapshot = _buildSnapshot(app, routine, notes, focus);
    final live = activeLiveMessages(snapshot);

    if (live.isNotEmpty && _stateBCount.isOdd) {
      final msg = live[_liveCursor % live.length];
      _liveCursor += 1;
      _lastMessageText = msg.text;
      return _ContextMessage(msg.label, msg.text);
    }

    final bag = _ensureBag(userName);
    bag.lastText = _lastMessageText;
    final msg = bag.next();
    _lastMessageText = msg.text;
    return _ContextMessage(msg.category, msg.text);
  }

  SmartHeaderSnapshot _buildSnapshot(
    AppState app,
    RoutineState routine,
    NotesState notes,
    FocusState focus,
  ) {
    final now = DateTime.now();
    final today = focusYmd(now);
    final nowMin = now.hour * 60 + now.minute;

    final tasks = app.tasks;
    final pending = <Task>[];
    for (final t in tasks) {
      if (t.status == TaskStatus.pending) pending.add(t);
    }

    var pendingDueToday = 0;
    for (final t in pending) {
      if (t.dueDate == today) pendingDueToday += 1;
    }

    var pendingExamWithin3Days = false;
    final todayDate = DateTime(now.year, now.month, now.day);
    for (final t in pending) {
      if (t.type != TaskType.exam) continue;
      try {
        final d = DateTime.parse(t.dueDate);
        final days = DateTime(d.year, d.month, d.day)
            .difference(todayDate)
            .inDays;
        if (days >= 0 && days <= 3) {
          pendingExamWithin3Days = true;
          break;
        }
      } catch (_) {
        // Unparseable legacy dueDate: skip instead of crashing the header.
      }
    }

    final slotsToday = routine.slotsForWeekday(now.weekday);
    var upcomingClassesToday = 0;
    int? minutesUntilNextClass;
    for (final s in slotsToday) {
      if (s.endMinutes > nowMin) upcomingClassesToday += 1;
      final diff = s.startMinutes - nowMin;
      if (diff >= 0 && (minutesUntilNextClass == null || diff < minutesUntilNextClass)) {
        minutesUntilNextClass = diff;
      }
    }

    var pomodoroCompletedToday = false;
    for (final s in focus.sessions) {
      if (s.date == today && s.completed) {
        pomodoroCompletedToday = true;
        break;
      }
    }

    // The app has no semester model; treat the first 21 days after first
    // launch as the fresh-start window for NEW SEMESTER.
    final fs = _firstSeenMs;
    final isNewSemester = fs != null &&
        (now.millisecondsSinceEpoch - fs) < const Duration(days: 21).inMilliseconds;

    return SmartHeaderSnapshot(
      hasAnyTasks: tasks.isNotEmpty,
      allTasksCompleted: tasks.isNotEmpty && pending.isEmpty,
      pendingTaskCount: pending.length,
      pendingDueTodayCount: pendingDueToday,
      pendingExamWithin3Days: pendingExamWithin3Days,
      upcomingClassesToday: upcomingClassesToday,
      minutesUntilNextClass: minutesUntilNextClass,
      pomodoroCompletedToday: pomodoroCompletedToday,
      noteCount: notes.allNotes.length,
      isNewSemester: isNewSemester,
      routineAvailable: routine.slots.isNotEmpty,
    );
  }

  String _cleanName(String name) {
    final first = name.split(' ').firstWhere(
          (w) => w.trim().isNotEmpty,
          orElse: () => name,
        );
    return first
        .replaceAll('!', '')
        .replaceAll(
            RegExp(
                r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
                unicode: true),
            '')
        .trim();
  }

  Widget _buildAvatarInitial(String name) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
    return Text(
      initial,
      style: const TextStyle(
        color: Color(0xFFE59435),
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildGreetingState(String greeting, String cleanFirstName,
      AppColors c) {
    return SizedBox(
      key: const ValueKey('state-a'),
      height: 68,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          cleanFirstName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
            height: 1.18,
          ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _buildContextState(AppColors c) {
    final msg = _contextMessage ??
        const _ContextMessage('DAILY FUEL', 'Progress over perfection.');
    return SizedBox(
      key: ValueKey('state-b-${msg.text}'),
      height: 68,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE59435),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                msg.label, // already uppercase (category keys / live labels)
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.15,
                  color: Color(0xFFE59435),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          msg.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: c.textPrimary.withValues(alpha: 0.92),
            height: 1.25,
          ),
        ),
      ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    // Fine-grained selectors isolate rebuilds from unrelated settings changes
    final name = context.select((AppState s) => s.settings.name);
    final avatarUri = context.select((AppState s) => s.settings.avatarUri);
    final now = DateTime.now();

    final cleanFirstName = _cleanName(name);
    // Keep the bag in sync with the current name (cheap after first call).
    _ensureBag(cleanFirstName);

    final options = timeGreetingOptions(now);
    final greeting = options.length == 1
        ? options.first
        : (_greetingVariant ? options[1] : options[0]);

    return RepaintBoundary(
      child: Container(
        color: c.pageBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _manualCycle,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 68,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: MediaQuery(
                          // The app clamps text scale to 1.3 in production
                          // (see kMaxTextScale in app.dart). The fixed 68px
                          // slot applies the same cap locally so raw 2.0
                          // text scale can never overflow the slot.
                          data: MediaQuery.of(context).copyWith(
                            textScaler: MediaQuery.textScalerOf(context)
                                .clamp(
                              minScaleFactor: 1.0,
                              maxScaleFactor: 1.3,
                            ),
                          ),
                          child: AnimatedSwitcher(
                            // Pin children to the left inside the switcher's
                            // internal Stack (it defaults to center) so the
                            // narrow greeting and the wide context line never
                            // re-center and jitter horizontally.
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.centerLeft,
                                fit: StackFit.loose,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              );
                            },
                            duration: const Duration(milliseconds: 420),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeOutCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.12),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _isStateA
                                ? _buildGreetingState(
                                    greeting, cleanFirstName, c)
                                : _buildContextState(c),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile Avatar ("S"): 42x42 circular container with dark background
                    GestureDetector(
                      onTap: () {
                        PremiumHaptics.tap();
                        widget.onNavigateToProfile?.call();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF262320),
                          border: Border.all(
                            color: const Color(0xFFE59435).withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        child: avatarUri != null && avatarUri.isNotEmpty
                            ? (kIsWeb
                                ? Image.network(
                                    avatarUri,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildAvatarInitial(cleanFirstName),
                                  )
                                : Image.file(
                                    File(avatarUri),
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildAvatarInitial(cleanFirstName),
                                  ))
                            : _buildAvatarInitial(cleanFirstName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Primary Action Button ("+"): 42x42 squircle with dark icon
                    GestureDetector(
                      key: widget.plusKey,
                      onTap: widget.onPlus,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE59435),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: AnimatedRotation(
                          turns: widget.plusOpen ? 0.125 : 0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF262320),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
