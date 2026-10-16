import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/task_utils.dart';
import 'package:uniro1/models/class_slot.dart';
import 'package:uniro1/models/course.dart';

void main() {
  group('ClassSlot JSON', () {
    test('round-trips incl. nullable fields', () {
      final slot = ClassSlot(
        courseId: 'c1',
        weekday: 3,
        startMinutes: 540,
        endMinutes: 630,
        room: 'SEU 536',
        reminderMinutesBefore: 10,
      );
      final back = ClassSlot.fromJson(slot.toJson());
      expect(back.id, slot.id);
      expect(back.weekday, 3);
      expect(back.startMinutes, 540);
      expect(back.endMinutes, 630);
      expect(back.room, 'SEU 536');
      expect(back.reminderMinutesBefore, 10);
    });

    test('old data without new keys stays valid', () {
      final back = ClassSlot.fromJson({
        'id': 'x',
        'courseId': 'c1',
        'weekday': 9, // clamped
        'startMinutes': 600,
        'endMinutes': 660,
      });
      expect(back.weekday, 7);
      expect(back.room, isNull);
      expect(back.reminderMinutesBefore, isNull);
    });
  });

  group('Course JSON', () {
    test('round-trips with all optionals', () {
      final course = Course(
        name: 'Data Structures',
        code: 'CSE 2101',
        colorTag: 0xFFE8963C,
        teacher: 'Dr. A',
        room: 'R402',
        credits: 3.0,
      );
      final back = Course.fromJson(course.toJson());
      expect(back.name, 'Data Structures');
      expect(back.code, 'CSE 2101');
      expect(back.credits, 3.0);
    });
  });

  group('slotsOverlapMinutes', () {
    test('overlap, touch, containment', () {
      expect(slotsOverlapMinutes(540, 630, 600, 660), isTrue);
      // Touching edges do NOT overlap.
      expect(slotsOverlapMinutes(540, 600, 600, 660), isFalse);
      expect(slotsOverlapMinutes(540, 660, 560, 600), isTrue);
      expect(slotsOverlapMinutes(0, 60, 120, 180), isFalse);
    });
  });

  group('slotOverlapsAny', () {
    final others = [
      ClassSlot(courseId: 'c', weekday: 1, startMinutes: 540, endMinutes: 600),
      ClassSlot(courseId: 'c', weekday: 2, startMinutes: 540, endMinutes: 600),
    ];

    test('same day overlap detected', () {
      expect(
        slotOverlapsAny(
            weekday: 1, startMinutes: 570, endMinutes: 630, others: others),
        isTrue,
      );
    });

    test('different day ignored', () {
      expect(
        slotOverlapsAny(
            weekday: 3, startMinutes: 570, endMinutes: 630, others: others),
        isFalse,
      );
    });

    test('ignoreId skips the edited slot', () {
      expect(
        slotOverlapsAny(
          weekday: 1,
          startMinutes: 570,
          endMinutes: 630,
          others: others,
          ignoreId: others.first.id,
        ),
        isFalse,
      );
    });
  });

  group('weekStartString', () {
    // Monday 2026-10-12.
    final monday = DateTime(2026, 10, 12);

    test('Monday start keeps Monday', () {
      expect(weekStartString(monday, DateTime.monday), '2026-10-12');
    });

    test('Saturday start rolls back to Saturday', () {
      // Monday 12th belongs to the week starting Sat 10th.
      expect(
          weekStartString(monday, DateTime.saturday), '2026-10-10');
    });

    test('Saturday itself is its own start', () {
      expect(weekStartString(DateTime(2026, 10, 10), DateTime.saturday),
          '2026-10-10');
    });

    test('Sunday start', () {
      expect(weekStartString(monday, DateTime.sunday), '2026-10-11');
    });
  });
}
