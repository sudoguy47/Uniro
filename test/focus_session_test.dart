import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/models/focus_session.dart';

void main() {
  group('FocusSession JSON', () {
    test('round-trips all fields', () {
      final s = FocusSession(
        runId: 'run-1',
        date: '2026-10-13',
        startedAt: '2026-10-13T09:00:00.000',
        plannedSec: 1500,
        focusedSec: 900,
        linkKind: 'task',
        linkId: 't1',
        linkName: 'Problem set 3',
        completed: false,
      );
      final back = FocusSession.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.runId, 'run-1');
      expect(back.date, '2026-10-13');
      expect(back.plannedSec, 1500);
      expect(back.focusedSec, 900);
      expect(back.linkKind, 'task');
      expect(back.linkId, 't1');
      expect(back.linkName, 'Problem set 3');
      expect(back.completed, isFalse);
    });

    test('minimal JSON stays valid (deleted-link safe)', () {
      final back = FocusSession.fromJson({
        'id': 'x',
        'runId': 'r',
        'date': '2026-10-13',
        'startedAt': '2026-10-13T09:00:00.000',
        'plannedSec': 1500,
        'focusedSec': 1500,
      });
      expect(back.linkKind, 'none');
      expect(back.linkId, isNull);
      expect(back.linkName, '');
      expect(back.completed, isTrue);
    });

    test('migrates legacy course keys', () {
      final back = FocusSession.fromJson({
        'id': 'y',
        'runId': 'r2',
        'date': '2026-10-13',
        'startedAt': '2026-10-13T09:00:00.000',
        'plannedSec': 1500,
        'focusedSec': 1500,
        'courseId': 'c9',
        'courseName': 'Physics',
      });
      expect(back.linkKind, 'course');
      expect(back.linkId, 'c9');
      expect(back.linkName, 'Physics');
    });
  });
}
