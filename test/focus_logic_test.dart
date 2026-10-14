import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/focus_logic.dart';

void main() {
  group('twoDigit', () {
    test('pads 0..99 to two characters', () {
      expect(twoDigit(0), '00');
      expect(twoDigit(5), '05');
      expect(twoDigit(24), '24');
      expect(twoDigit(99), '99');
    });

    test('clamps out of range', () {
      expect(twoDigit(-3), '00');
      expect(twoDigit(120), '99');
    });
  });

  group('clockPairs', () {
    test('zero and single seconds', () {
      expect(clockPairs(0), ('00', '00'));
      expect(clockPairs(9), ('00', '09'));
    });

    test('59 -> 00 seconds rollover keeps minutes pair', () {
      expect(clockPairs(59), ('00', '59'));
      expect(clockPairs(60), ('01', '00'));
      expect(clockPairs(1500), ('25', '00'));
      expect(clockPairs(2700), ('45', '00'));
      expect(clockPairs(3600), ('60', '00'));
    });

    test('negative clamps to 00:00', () {
      expect(clockPairs(-5), ('00', '00'));
    });
  });

  group('formatDuration', () {
    test('seconds, minutes, hours', () {
      expect(formatDuration(0), '0s');
      expect(formatDuration(5), '5s');
      expect(formatDuration(45), '45s');
      expect(formatDuration(60), '1m');
      expect(formatDuration(90), '1m 30s');
      expect(formatDuration(1500), '25m');
      expect(formatDuration(2700), '45m');
      expect(formatDuration(3720), '1h 2m');
      expect(formatDuration(3600), '1h');
    });
  });

  group('weekStartMonday', () {
    test('Monday maps to itself, Sunday rolls back 6 days', () {
      expect(weekStartMonday(DateTime(2026, 10, 12)), '2026-10-12');
      expect(weekStartMonday(DateTime(2026, 10, 18)), '2026-10-12');
      expect(weekStartMonday(DateTime(2026, 10, 14)), '2026-10-12');
    });
  });

  group('clampDuration', () {
    test('clamps into range', () {
      expect(clampDuration(0, 5, 120), 5);
      expect(clampDuration(200, 5, 120), 120);
      expect(clampDuration(45, 5, 120), 45);
    });
  });

  group('weekdayShort + slotClock', () {
    test('labels days and times', () {
      expect(weekdayShort(1), 'Mon');
      expect(weekdayShort(5), 'Fri');
      expect(weekdayShort(7), 'Sun');
      expect(weekdayShort(0), '');
      expect(slotClock(540), '09:00');
      expect(slotClock(630), '10:30');
    });
  });
}
