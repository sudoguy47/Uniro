import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/quotes.dart';

void main() {
  group('quotes list', () {
    test('has 50 entries', () {
      expect(kQuotes.length, 50);
    });
  });

  group('quoteForSlot', () {
    test('rotates every 10 minutes', () {
      final a = quoteSlotIndex(DateTime(2026, 10, 14, 9, 0));
      final b = quoteSlotIndex(DateTime(2026, 10, 14, 9, 9));
      final c = quoteSlotIndex(DateTime(2026, 10, 14, 9, 10));
      expect(a, b);
      expect(c, (a + 1) % kQuotes.length);
    });

    test('same instant always maps to the same quote', () {
      final t = DateTime(2026, 10, 14, 9, 5);
      expect(quoteForSlot(t), quoteForSlot(t));
    });
  });

  group('quoteOfTheDay', () {
    test('stable within a day, changes across days', () {
      expect(quoteOfTheDay(DateTime(2026, 10, 14, 6, 0)),
          quoteOfTheDay(DateTime(2026, 10, 14, 23, 59)));
      expect(quoteOfTheDay(DateTime(2026, 10, 14)),
          isNot(quoteOfTheDay(DateTime(2026, 10, 15))));
    });
  });

  group('todayAgendaLine', () {
    test('empty schedule', () {
      expect(todayAgendaLine(classCount: 0, taskCount: 0),
          'Nothing scheduled today — enjoy your day!');
    });

    test('counts classes and tasks', () {
      expect(todayAgendaLine(classCount: 2, taskCount: 3),
          'Today: 2 classes and 3 tasks due.');
      expect(todayAgendaLine(classCount: 1, taskCount: 0),
          'Today: 1 class.');
      expect(todayAgendaLine(classCount: 0, taskCount: 1),
          'Today: 1 task due.');
    });
  });
}
