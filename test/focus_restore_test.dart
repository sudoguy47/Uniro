import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/state/focus_state.dart';

/// Kill-mid-run restore: quitting the app while a focus run ticks must
/// never relaunch into a nav-less state. The run auto-pauses so the
/// bottom nav (hidden while `running && !paused`) comes back and the
/// Focus tab offers Resume with the remaining time intact.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  Map<String, dynamic> engine({
    required int phase,
    required bool running,
    required bool paused,
    required int endTimeMs,
    int pausedRemainingSec = 0,
    String? runId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'focusMin': 25,
      'breakMin': 5,
      'linkKind': 'none',
      'linkId': null,
      'courseId': null,
      'phase': phase,
      'running': running,
      'paused': paused,
      'endTimeMs': endTimeMs,
      'pausedRemainingSec': pausedRemainingSec,
      'runStartMs': now - 5 * 60000,
      'runId': runId,
      'pendingBreak': false,
      'linkName': '',
    };
  }

  test('kill mid-run restores paused so the nav returns', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    LocalStore.instance.save(
      'focus_engine_v2',
      engine(
        phase: 1, // FocusPhase.focus
        running: true,
        paused: false,
        endTimeMs: now + 20 * 60000,
        runId: 'run-abc',
      ),
    );

    final state = FocusState();
    addTearDown(state.dispose);
    await state.load();

    expect(state.running, isTrue);
    expect(state.paused, isTrue,
        reason: 'cold restore auto-pauses a live run');
    expect(state.pausedRemainingSec, greaterThan(0));
    // AppShell hides the nav exactly when running && !paused.
    expect(state.running && !state.paused, isFalse);
    // No phantom session recorded for an unfinished run.
    expect(state.sessions, isEmpty);
  });

  test('run that ended while away still settles once', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    LocalStore.instance.save(
      'focus_engine_v2',
      engine(
        phase: 1, // FocusPhase.focus
        running: true,
        paused: false,
        endTimeMs: now - 1000,
        runId: 'run-done',
      ),
    );

    final state = FocusState();
    addTearDown(state.dispose);
    await state.load();

    expect(state.running, isFalse);
    expect(state.pendingBreak, isTrue);
    expect(state.sessions.length, 1);
    expect(state.sessions.first.runId, 'run-done');
    expect(state.sessions.first.completed, isTrue);
  });
}
