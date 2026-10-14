import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/focus_logic.dart';
import '../domain/haptics.dart';
import '../domain/ids.dart';
import '../models/focus_session.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';

/// Course-based Pomodoro engine.
///
/// Timing is wall-clock based (absolute [endTimeMs]), so background time,
/// navigation, and killed-app restores stay accurate — the 1s ticker only
/// refreshes the display. Per-second updates flow ONLY through the digit
/// ValueNotifiers; [notifyListeners] fires on structural changes.
///
/// Recorded study time is derived as planned − remaining, so paused time
/// and break time are never counted. Each run carries a [runId] and
/// [record] skips duplicates, so a session is saved exactly once even
/// across restores and retries.
class FocusState extends ChangeNotifier {
  FocusState();

  static const int maxSessions = 500;
  static const String _engineKey = 'focus_engine_v2';
  static const String _sessionsKey = 'focus_sessions_v2';

  // ── Settings (persisted) ──
  int focusMin = 25;
  int breakMin = 5;
  // Link target: 'none' | 'course' | 'task' | 'class'.
  String linkKind = 'none';
  String? linkId;

  // ── Run state (persisted) ──
  FocusPhase phase = FocusPhase.idle;
  bool running = false;
  bool paused = false;
  int endTimeMs = 0;
  int pausedRemainingSec = 0;
  int runStartMs = 0;
  String? runId;
  bool pendingBreak = false;

  // ── Sessions ──
  List<FocusSession> _sessions = [];
  bool _loaded = false;
  bool _disposed = false;

  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoaded => _loaded;

  /// True while a focus or break run exists (running or paused).
  /// Course and duration pickers lock while true.
  bool get active => phase != FocusPhase.idle;

  int get plannedSec => (phase == FocusPhase.breakTime ? breakMin : focusMin) * 60;

  // ── Per-second notifiers (UI listens; nothing else rebuilds) ──
  final ValueNotifier<String> minPair = ValueNotifier<String>('25');
  final ValueNotifier<String> secPair = ValueNotifier<String>('00');
  final ValueNotifier<int> remainingSec = ValueNotifier<int>(1500);
  final ValueNotifier<String> semanticsN =
      ValueNotifier<String>('Focus timer idle');
  // Bumped on structural changes; layout listens to this.
  final ValueNotifier<int> struct = ValueNotifier<int>(0);
  // Bumped when a focus run is recorded; carries the saved session.
  final ValueNotifier<int> doneTick = ValueNotifier<int>(0);
  FocusSession? lastDone;

  Timer? _ticker;
  bool _completing = false;
  Timer? _staggerTimer;
  int _lastAnnouncedBucket = -1;

  static String todayStr() => focusYmd(DateTime.now());

  // ── Load / persist ──

  Future<void> load() async {
    if (_loaded) return;
    final raw = LocalStore.instance.load(_sessionsKey);
    if (raw is List) {
      try {
        _sessions = raw
            .map((j) => FocusSession.fromJson(
                Map<String, dynamic>.from(j as Map)))
            .toList();
      } catch (_) {
        _sessions = [];
      }
    }
    _loadEngine();
    _loaded = true;
    if (!_disposed) notifyListeners();
  }

  void _loadEngine() {
    final raw = LocalStore.instance.load(_engineKey);
    if (raw is Map) {
      try {
        final m = Map<String, dynamic>.from(raw);
        focusMin = clampDuration(
            (m['focusMin'] as num?)?.toInt() ?? 25, 5, 120);
        breakMin = clampDuration(
            (m['breakMin'] as num?)?.toInt() ?? 5, 1, 30);
        linkKind = m['linkKind'] as String? ??
            (m['courseId'] != null ? 'course' : 'none');
        if (linkKind != 'none' &&
            linkKind != 'course' &&
            linkKind != 'task' &&
            linkKind != 'class') {
          linkKind = 'none';
        }
        linkId = m['linkId'] as String? ?? (m['courseId'] as String?);
        final pi = (m['phase'] as num?)?.toInt() ?? 0;
        phase = (pi >= 0 && pi < FocusPhase.values.length)
            ? FocusPhase.values[pi]
            : FocusPhase.idle;
        running = m['running'] as bool? ?? false;
        paused = m['paused'] as bool? ?? false;
        endTimeMs = (m['endTimeMs'] as num?)?.toInt() ?? 0;
        pausedRemainingSec =
            (m['pausedRemainingSec'] as num?)?.toInt() ?? 0;
        runStartMs = (m['runStartMs'] as num?)?.toInt() ?? 0;
        runId = m['runId'] as String?;
        pendingBreak = m['pendingBreak'] as bool? ?? false;
        _pendingLinkName = m['linkName'] as String? ??
            (m['courseName'] as String? ?? '');
      } catch (_) {
        _resetRunState();
      }
    }
    // Settle runs that ended while the app was away.
    if (running && !paused) {
      final left = _secondsLeft();
      if (left <= 0) {
        if (phase == FocusPhase.focus) {
          _recordCompleted(focusMin * 60,
              linkName: _pendingLinkName);
          pendingBreak = true;
        }
        phase = FocusPhase.idle;
        running = false;
        runId = null;
      } else {
        _startTicker();
      }
    }
    _saveEngine();
    _pushDisplay(force: true);
    _touch();
  }

  void _resetRunState() {
    phase = FocusPhase.idle;
    running = false;
    paused = false;
    endTimeMs = 0;
    pausedRemainingSec = 0;
    runStartMs = 0;
    runId = null;
    pendingBreak = false;
  }

  void _saveEngine() {
    if (_disposed) return;
    LocalStore.instance.save(_engineKey, {
      'focusMin': focusMin,
      'breakMin': breakMin,
      'linkKind': linkKind,
      'linkId': linkId,
      'courseId': linkKind == 'course' ? linkId : null,
      'phase': phase.index,
      'running': running,
      'paused': paused,
      'endTimeMs': endTimeMs,
      'pausedRemainingSec': pausedRemainingSec,
      'runStartMs': runStartMs,
      'runId': runId,
      'pendingBreak': pendingBreak,
      'linkName': _pendingLinkName,
    });
  }

  void _persistSessions() {
    if (_disposed) return;
    LocalStore.instance.save(
        _sessionsKey, _sessions.map((s) => s.toJson()).toList());
  }

  void _touch() {
    if (_disposed) return;
    struct.value++;
  }

  // ── Sessions ──

  /// Records [session] unless its [runId] is already stored.
  /// Returns true when a new record was added.
  bool record(FocusSession session) {
    if (_sessions.any((s) => s.runId == session.runId)) return false;
    _sessions = [session, ..._sessions];
    if (_sessions.length > maxSessions) {
      _sessions = _sessions.sublist(0, maxSessions);
    }
    _persistSessions();
    lastDone = session;
    doneTick.value++;
    notifyListeners();
    return true;
  }

  FocusSession _buildSession({
    required int focusedSec,
    required bool completed,
    required String linkName,
  }) {
    final start = DateTime.fromMillisecondsSinceEpoch(
        runStartMs == 0 ? DateTime.now().millisecondsSinceEpoch : runStartMs);
    return FocusSession(
      runId: runId ?? newLocalId(),
      date: focusYmd(start),
      startedAt: start.toIso8601String(),
      plannedSec: focusMin * 60,
      focusedSec: focusedSec < 0 ? 0 : focusedSec,
      linkKind: linkKind,
      linkId: linkId,
      linkName: linkName,
      completed: completed,
    );
  }

  void _recordCompleted(int focusedSec,
      {required String linkName, bool completed = true}) {
    record(_buildSession(
        focusedSec: focusedSec,
        completed: completed,
        linkName: linkName));
  }

  // ── Display ──

  void _setPairs(String min, String sec, {bool stagger = false}) {
    _staggerTimer?.cancel();
    if (!stagger || _disposed) {
      if (minPair.value != min) minPair.value = min;
      if (secPair.value != sec) secPair.value = sec;
      return;
    }
    if (minPair.value != min) minPair.value = min;
    _staggerTimer = Timer(const Duration(milliseconds: 60), () {
      if (_disposed) return;
      if (secPair.value != sec) secPair.value = sec;
    });
  }

  void _pushDisplay({bool force = false, bool stagger = true}) {
    if (phase == FocusPhase.idle) {
      final full = focusMin * 60;
      final p = clockPairs(full);
      _setPairs(p.$1, p.$2, stagger: stagger);
      remainingSec.value = full;
    } else if (!running && paused) {
      final p = clockPairs(pausedRemainingSec);
      _setPairs(p.$1, p.$2, stagger: stagger);
      remainingSec.value = pausedRemainingSec;
    } else {
      final left = _secondsLeft();
      final p = clockPairs(left);
      _setPairs(p.$1, p.$2, stagger: stagger);
      remainingSec.value = left;
    }
    if (force) _announce(true);
  }

  int _secondsLeft() {
    final left =
        ((endTimeMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    return left < 0 ? 0 : left;
  }

  /// Focused seconds so far in the current focus run
  /// (planned − remaining; paused time excluded by construction).
  int focusedSoFar() {
    if (phase != FocusPhase.focus) return 0;
    if (!running && !paused) return 0;
    final left = paused ? pausedRemainingSec : _secondsLeft();
    final done = focusMin * 60 - left;
    return done < 0 ? 0 : done;
  }

  void _announce(bool force) {
    final bucket = remainingSec.value ~/ 10;
    if (!force && bucket == _lastAnnouncedBucket) return;
    _lastAnnouncedBucket = bucket;
    final mm = remainingSec.value ~/ 60;
    final ss = remainingSec.value % 60;
    final what = switch (phase) {
      FocusPhase.focus => 'focus',
      FocusPhase.breakTime => 'break',
      FocusPhase.idle => 'idle',
    };
    semanticsN.value = '$mm minutes $ss seconds remaining, $what';
  }

  // ── Ticker (one per run; cancelled on pause/end) ──

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      if (!running || paused) return;
      final left = _secondsLeft();
      final p = clockPairs(left);
      _setPairs(p.$1, p.$2);
      remainingSec.value = left;
      _announce(false);
      if (left <= 0 && !_completing) {
        _completing = true;
        unawaited(_settle().whenComplete(() {
          _completing = false;
        }));
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  Future<void> _settle() async {
    if (!running || paused) return;
    if (phase == FocusPhase.focus) {
      await _completeFocus();
    } else if (phase == FocusPhase.breakTime) {
      phase = FocusPhase.idle;
      running = false;
      runId = null;
      _stopTicker();
      _saveEngine();
      _pushDisplay(force: true);
      _announce(true);
      _touch();
      notifyListeners();
      PremiumHaptics.confirm();
      unawaited(NotificationService.instance.showInstantNotification(
        title: 'Break over',
        body: 'Ready for the next round?',
        payload: 'focus_done',
      ));
    }
  }

  // ── Actions (called from UI) ──

  void selectLink({required String kind, String? id}) {
    if (active) return;
    linkKind = kind;
    linkId = id;
    _saveEngine();
    _touch();
    notifyListeners();
  }

  void setFocusMinutes(int v) {
    if (active) return;
    focusMin = clampDuration(v, 5, 120);
    _saveEngine();
    _pushDisplay(force: true);
    _touch();
    notifyListeners();
  }

  void setDurations({int? focus, int? breakM}) {
    if (active) return;
    if (focus != null) focusMin = clampDuration(focus, 5, 120);
    if (breakM != null) breakMin = clampDuration(breakM, 1, 30);
    _saveEngine();
    _pushDisplay(force: true);
    _touch();
    notifyListeners();
  }

  /// Starts a focus run. Any link (including none) is allowed.
  bool start() {
    if (phase != FocusPhase.idle || active) return true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    runId = newLocalId();
    runStartMs = nowMs;
    phase = FocusPhase.focus;
    pendingBreak = false;
    running = true;
    paused = false;
    pausedRemainingSec = 0;
    endTimeMs = nowMs + focusMin * 60000;
    _saveEngine();
    _startTicker();
    _pushDisplay(force: true);
    _announce(true);
    _touch();
    notifyListeners();
    return true;
  }

  void pause() {
    if (phase == FocusPhase.idle || !running || paused) return;
    pausedRemainingSec = _secondsLeft();
    paused = true;
    _stopTicker();
    _saveEngine();
    _pushDisplay(force: true);
    _touch();
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    endTimeMs =
        DateTime.now().millisecondsSinceEpoch + pausedRemainingSec * 1000;
    paused = false;
    _startTicker();
    _saveEngine();
    _pushDisplay(force: true);
    _touch();
    notifyListeners();
  }

  /// Saves the focus run once with its full planned time, then sounds
  /// the completion alarm (notification + vibration + haptics).
  Future<void> _completeFocus() async {
    final doneId = runId;
    final name = _pendingLinkName;
    phase = FocusPhase.idle;
    running = false;
    paused = false;
    runId = null;
    pendingBreak = true;
    _stopTicker();
    _saveEngine();
    _pushDisplay(force: true);
    _announce(true);
    _touch();
    notifyListeners();
    if (doneId != null) {
      record(FocusSession(
        runId: doneId,
        date: focusYmd(DateTime.fromMillisecondsSinceEpoch(runStartMs)),
        startedAt:
            DateTime.fromMillisecondsSinceEpoch(runStartMs).toIso8601String(),
        plannedSec: focusMin * 60,
        focusedSec: focusMin * 60,
        linkKind: linkKind,
        linkId: linkId,
        linkName: name,
        completed: true,
      ));
    }
    PremiumHaptics.confirm();
    unawaited(NotificationService.instance.showInstantNotification(
      title: 'Focus complete',
      body: name.isEmpty
          ? 'Nice work. Time for a break.'
          : 'Nice work on $name. Time for a break.',
      payload: 'focus_done',
    ));
  }

  String _pendingLinkName = '';

  /// The UI sets the live link label before actions that may record,
  /// so history keeps a rename-proof snapshot.
  void setLiveLinkName(String name) => _pendingLinkName = name;

  /// Restart the current phase from its full duration, saving the actual
  /// focused time of a focus run as ended-early first.
  /// Returns the focused seconds that were saved (0 when nothing saved).
  int restart() {
    var saved = 0;
    if (phase == FocusPhase.focus && (running || paused)) {
      saved = focusedSoFar();
      if (saved > 0) {
        _recordCompleted(saved,
            linkName: _pendingLinkName, completed: false);
      }
    }
    if (phase == FocusPhase.breakTime) {
      endTimeMs =
          DateTime.now().millisecondsSinceEpoch + breakMin * 60000;
      paused = false;
      pausedRemainingSec = 0;
      running = true;
      _startTicker();
    } else if (phase == FocusPhase.focus) {
      runId = newLocalId();
      runStartMs = DateTime.now().millisecondsSinceEpoch;
      endTimeMs = runStartMs + focusMin * 60000;
      running = true;
      paused = false;
      pausedRemainingSec = 0;
      _startTicker();
    } else {
      running = false;
      paused = false;
      pendingBreak = false;
    }
    _saveEngine();
    _pushDisplay(force: true);
    _announce(true);
    _touch();
    notifyListeners();
    return saved;
  }

  int endSession() {
    var saved = 0;
    if (phase == FocusPhase.focus && (running || paused)) {
      saved = focusedSoFar();
      if (saved > 0) {
        _recordCompleted(saved,
            linkName: _pendingLinkName, completed: false);
      }
    }
    phase = FocusPhase.idle;
    running = false;
    paused = false;
    pendingBreak = false;
    runId = null;
    _stopTicker();
    _saveEngine();
    _pushDisplay(force: true);
    _announce(true);
    _touch();
    notifyListeners();
    return saved;
  }

  /// Starts the offered break. No-op unless a break is pending.
  bool startBreak() {
    if (!pendingBreak || active) return false;
    pendingBreak = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    runId = newLocalId();
    runStartMs = nowMs;
    phase = FocusPhase.breakTime;
    running = true;
    paused = false;
    pausedRemainingSec = 0;
    endTimeMs = nowMs + breakMin * 60000;
    _saveEngine();
    _startTicker();
    _pushDisplay(force: true, stagger: true);
    _announce(true);
    _touch();
    notifyListeners();
    return true;
  }

  void dismissBreakOffer() {
    if (!pendingBreak) return;
    pendingBreak = false;
    _saveEngine();
    _touch();
    notifyListeners();
  }

  // ── Summary queries ──

  int totalFocusedSec(
      {String? forLinkKind, String? forLinkId, String? date, String? weekStart}) {
    var total = 0;
    for (final s in _sessions) {
      if (forLinkKind != null && s.linkKind != forLinkKind) continue;
      if (forLinkId != null && s.linkId != forLinkId) continue;
      if (date != null && s.date != date) continue;
      if (weekStart != null) {
        if (s.date.compareTo(weekStart) < 0) continue;
        if (s.date.compareTo(todayStr()) > 0) continue;
      }
      total += s.focusedSec;
    }
    return total;
  }

  int sessionCount(
      {String? forLinkKind, String? forLinkId, String? date, String? weekStart}) {
    var n = 0;
    for (final s in _sessions) {
      if (forLinkKind != null && s.linkKind != forLinkKind) continue;
      if (forLinkId != null && s.linkId != forLinkId) continue;
      if (date != null && s.date != date) continue;
      if (weekStart != null) {
        if (s.date.compareTo(weekStart) < 0) continue;
        if (s.date.compareTo(todayStr()) > 0) continue;
      }
      n++;
    }
    return n;
  }

  List<FocusSession> history({String? date, String? weekStart}) {
    return _sessions.where((s) {
      if (date != null && s.date != date) return false;
      if (weekStart != null) {
        if (s.date.compareTo(weekStart) < 0) return false;
        if (s.date.compareTo(todayStr()) > 0) return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    _staggerTimer?.cancel();
    minPair.dispose();
    secPair.dispose();
    remainingSec.dispose();
    semanticsN.dispose();
    struct.dispose();
    doneTick.dispose();
    super.dispose();
  }
}
