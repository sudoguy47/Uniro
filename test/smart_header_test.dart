import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/smart_header.dart';

final _emoji = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}\u{2B00}-\u{2BFF}]',
  unicode: true,
);

const _cleanSnapshot = SmartHeaderSnapshot(
  hasAnyTasks: true,
  allTasksCompleted: false,
  pendingTaskCount: 2,
  pendingDueTodayCount: 3,
  pendingExamWithin3Days: false,
  upcomingClassesToday: 2,
  minutesUntilNextClass: 180,
  pomodoroCompletedToday: false,
  noteCount: 4,
  isNewSemester: false,
  routineAvailable: true,
);

void main() {
  group('buildCategorizedHeaderMessages', () {
    test('has exactly the 9 spec categories in spec order', () {
      expect(
        buildCategorizedHeaderMessages('Shreyas').keys.toList(),
        [
          'WELCOME',
          'DAILY LIFE',
          'STUDY & LEARNING',
          'PRODUCTIVITY',
          'SCHEDULE',
          'DEADLINES',
          'DEEP FOCUS',
          'NOTES & IDEAS',
          'DAILY FUEL',
        ],
      );
    });

    test('injects the user name everywhere the copy references it', () {
      final messages =
          buildCategorizedHeaderMessages('Shreyas').values.expand((m) => m);
      for (final m in messages) {
        expect(m.contains(r'$userName'), isFalse,
            reason: 'uninterpolated placeholder in "$m"');
      }
      expect(
        buildCategorizedHeaderMessages('Shreyas')['WELCOME']!
            .any((m) => m.contains('Shreyas')),
        isTrue,
      );
      expect(
        buildCategorizedHeaderMessages('Shreyas')['DAILY FUEL']!
            .any((m) => m.contains('Shreyas')),
        isTrue,
      );
    });

    test('no message uses the word "Hey" or contains an emoji', () {
      final messages = [
        ...buildCategorizedHeaderMessages('Shreyas').values.expand((m) => m),
        ...activeLiveMessages(const SmartHeaderSnapshot(
          hasAnyTasks: true,
          allTasksCompleted: true,
          pendingTaskCount: 6,
          pendingDueTodayCount: 0,
          pendingExamWithin3Days: true,
          upcomingClassesToday: 0,
          minutesUntilNextClass: 45,
          pomodoroCompletedToday: true,
          noteCount: 0,
          isNewSemester: true,
          routineAvailable: true,
        )).expand((m) => [m.label, m.text]),
      ];
      for (final m in messages) {
        expect(m.contains('Hey'), isFalse, reason: '"Hey" found in "$m"');
        expect(_emoji.hasMatch(m), isFalse, reason: 'emoji found in "$m"');
      }
    });
  });

  group('flattenedBagMessages', () {
    test('flattens all categories into 84 unique texts', () {
      final flat = flattenedBagMessages('Shreyas');
      expect(flat.length, 84);
      expect(flat.map((m) => m.text).toSet().length, flat.length);
    });
  });

  group('timeGreetingOptions', () {
    test('morning bucket (5–10:59)', () {
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 5)),
          ['Good morning', 'Ready to start your day?']);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 10, 59)),
          ['Good morning', 'Ready to start your day?']);
    });

    test('midday bucket (11–13:59)', () {
      final expected = ['Good afternoon', "How's your day going?"];
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 11)), expected);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 13, 59)), expected);
    });

    test('afternoon bucket (14–16:59)', () {
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 14)),
          ["How's the day treating you?"]);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 16, 59)),
          ["How's the day treating you?"]);
    });

    test('evening bucket (17–20:59)', () {
      final expected = ['Good evening', 'How did today go?'];
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 17)), expected);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 20, 59)), expected);
    });

    test('late night bucket (21–23:59)', () {
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 21)),
          ['Still working on something?']);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 23, 59)),
          ['Still working on something?']);
    });

    test('overnight bucket (00–04:59)', () {
      expect(timeGreetingOptions(DateTime(2026, 11, 17)),
          ['Burning the midnight oil?']);
      expect(timeGreetingOptions(DateTime(2026, 11, 17, 4, 59)),
          ['Burning the midnight oil?']);
    });

    test('no time bucket produces the word "Hey"', () {
      for (var h = 0; h < 24; h++) {
        for (final o in timeGreetingOptions(DateTime(2026, 11, 17, h))) {
          expect(o.contains('Hey'), isFalse);
        }
      }
    });
  });

  group('activeLiveMessages (Category 11)', () {
    test('returns nothing when every condition is false', () {
      const snap = SmartHeaderSnapshot(
        hasAnyTasks: true,
        allTasksCompleted: false,
        pendingTaskCount: 2,
        pendingDueTodayCount: 3,
        pendingExamWithin3Days: false,
        upcomingClassesToday: 2,
        minutesUntilNextClass: 180,
        pomodoroCompletedToday: false,
        noteCount: 4,
        isNewSemester: false,
        routineAvailable: false,
      );
      expect(activeLiveMessages(snap), isEmpty);
    });

    test('CLEAR SCHEDULE fires only when nothing is due today', () {
      const clear = SmartHeaderSnapshot(
        hasAnyTasks: true,
        allTasksCompleted: false,
        pendingTaskCount: 2,
        pendingDueTodayCount: 0,
        pendingExamWithin3Days: false,
        upcomingClassesToday: 2,
        minutesUntilNextClass: 180,
        pomodoroCompletedToday: false,
        noteCount: 4,
        isNewSemester: false,
        routineAvailable: false,
      );
      expect(
        activeLiveMessages(clear)
            .map((m) => m.label)
            .contains('CLEAR SCHEDULE'),
        isTrue,
      );
      expect(
        activeLiveMessages(_cleanSnapshot).map((m) => m.label),
        isNot(contains('CLEAR SCHEDULE')),
      );
    });

    test('ALL COMPLETE requires at least one task and all completed', () {
      const empty = SmartHeaderSnapshot(
        hasAnyTasks: false,
        allTasksCompleted: false,
        pendingTaskCount: 0,
        pendingDueTodayCount: 5,
        pendingExamWithin3Days: false,
        upcomingClassesToday: 2,
        minutesUntilNextClass: 180,
        pomodoroCompletedToday: false,
        noteCount: 4,
        isNewSemester: false,
        routineAvailable: false,
      );
      expect(activeLiveMessages(empty).map((m) => m.label),
          isNot(contains('ALL COMPLETE')));

      const done = SmartHeaderSnapshot(
        hasAnyTasks: true,
        allTasksCompleted: true,
        pendingTaskCount: 0,
        pendingDueTodayCount: 5,
        pendingExamWithin3Days: false,
        upcomingClassesToday: 2,
        minutesUntilNextClass: 180,
        pomodoroCompletedToday: false,
        noteCount: 4,
        isNewSemester: false,
        routineAvailable: false,
      );
      expect(activeLiveMessages(done).map((m) => m.label),
          contains('ALL COMPLETE'));
    });

    test('HIGH WORKLOAD fires at 5 or more pending tasks', () {
      SmartHeaderSnapshot at(int n) => SmartHeaderSnapshot(
            hasAnyTasks: true,
            allTasksCompleted: false,
            pendingTaskCount: n,
            pendingDueTodayCount: 5,
            pendingExamWithin3Days: false,
            upcomingClassesToday: 2,
            minutesUntilNextClass: 180,
            pomodoroCompletedToday: false,
            noteCount: 4,
            isNewSemester: false,
            routineAvailable: false,
          );
      expect(activeLiveMessages(at(4)).map((m) => m.label),
          isNot(contains('HIGH WORKLOAD')));
      expect(activeLiveMessages(at(5)).map((m) => m.label),
          contains('HIGH WORKLOAD'));
    });

    test('UP NEXT fires only within 60 minutes of class', () {
      SmartHeaderSnapshot at(int? mins) => SmartHeaderSnapshot(
            hasAnyTasks: true,
            allTasksCompleted: false,
            pendingTaskCount: 2,
            pendingDueTodayCount: 5,
            pendingExamWithin3Days: false,
            upcomingClassesToday: 1,
            minutesUntilNextClass: mins,
            pomodoroCompletedToday: false,
            noteCount: 4,
            isNewSemester: false,
            routineAvailable: false,
          );
      expect(activeLiveMessages(at(60)).map((m) => m.label),
          contains('UP NEXT'));
      expect(activeLiveMessages(at(61)).map((m) => m.label),
          isNot(contains('UP NEXT')));
      expect(activeLiveMessages(at(null)).map((m) => m.label),
          isNot(contains('UP NEXT')));
    });

    test('returns every applicable condition in spec order', () {
      const all = SmartHeaderSnapshot(
        hasAnyTasks: true,
        allTasksCompleted: true,
        pendingTaskCount: 6,
        pendingDueTodayCount: 0,
        pendingExamWithin3Days: true,
        upcomingClassesToday: 0,
        minutesUntilNextClass: 30,
        pomodoroCompletedToday: true,
        noteCount: 0,
        isNewSemester: true,
        routineAvailable: true,
      );
      expect(
        activeLiveMessages(all).map((m) => m.label).toList(),
        [
          'CLEAR SCHEDULE',
          'ALL COMPLETE',
          'HIGH WORKLOAD',
          'EXAM ALERT',
          'FREE DAY',
          'UP NEXT',
          'FOCUS COMPLETE',
          'QUICK NOTE',
          'NEW SEMESTER',
          'SCHEDULE READY',
        ],
      );
    });
  });

  group('ShuffleBag', () {
    test('fisherYatesShuffle permutes without losing items', () {
      final input = List.generate(100, (i) => i);
      final shuffled = List.of(input);
      fisherYatesShuffle(shuffled, Random(7));
      expect(shuffled.length, input.length);
      expect(shuffled.toSet(), input.toSet());
    });

    test('every cycle of 84 draws covers the corpus exactly once', () {
      final bag =
          ShuffleBag(items: flattenedBagMessages('Shreyas'), random: Random(42));
      for (var cycle = 0; cycle < 3; cycle++) {
        final drawn = <String>{};
        for (var i = 0; i < 84; i++) {
          drawn.add(bag.next().text);
        }
        expect(drawn.length, 84);
      }
    });

    test('never repeats the same message back-to-back, even across refills',
        () {
      final bag =
          ShuffleBag(items: flattenedBagMessages('Shreyas'), random: Random(13));
      String? last;
      for (var i = 0; i < 500; i++) {
        final next = bag.next().text;
        expect(next == last, isFalse,
            reason: 'repeat at draw $i: "$next"');
        last = next;
      }
    });

    test('honors an externally supplied lastText', () {
      final flat = flattenedBagMessages('Shreyas');
      final bag = ShuffleBag(items: flat, random: Random(99));
      bag.lastText = flat.first.text;
      expect(bag.next().text == flat.first.text, isFalse);
    });
  });
}
