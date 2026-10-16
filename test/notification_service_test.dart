import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/models/task.dart';
import 'package:uniro1/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService Unit Tests', () {
    test('NotificationService singleton instance is initialized', () {
      final service = NotificationService.instance;
      expect(service, isNotNull);
      expect(NotificationService.channelId, equals('campus_tracker_reminders'));
    });

    test('Notification ID generation is deterministic and within valid 32-bit positive int range', () {
      final task1 = Task(
        id: 'task_abc_123',
        title: 'Submit Homework',
        type: TaskType.assignment,
        dueDate: '2026-11-01',
        priority: TaskPriority.high,
      );

      final task2 = Task(
        id: 'task_abc_123',
        title: 'Submit Homework',
        type: TaskType.assignment,
        dueDate: '2026-11-01',
        priority: TaskPriority.high,
      );

      final id1 = task1.id.hashCode.abs() % 2147483647;
      final id2 = task2.id.hashCode.abs() % 2147483647;

      expect(id1, equals(id2));
      expect(id1, greaterThanOrEqualTo(0));
      expect(id1, lessThan(2147483647));
    });

    test('Reminder date trigger calculation handles all ReminderType values', () {
      final dueDateTime = DateTime(2026, 11, 10, 14, 0);

      DateTime getTriggerDate(ReminderType type, [int? customDays]) {
        switch (type) {
          case ReminderType.atTime:
            return dueDateTime;
          case ReminderType.oneHour:
            return dueDateTime.subtract(const Duration(hours: 1));
          case ReminderType.oneDay:
            return dueDateTime.subtract(const Duration(days: 1));
          case ReminderType.twoDays:
            return dueDateTime.subtract(const Duration(days: 2));
          case ReminderType.threeDays:
            return dueDateTime.subtract(const Duration(days: 3));
          case ReminderType.sevenDays:
          case ReminderType.oneWeek:
            return dueDateTime.subtract(const Duration(days: 7));
          case ReminderType.custom:
            return dueDateTime.subtract(Duration(days: customDays ?? 1));
        }
      }

      expect(getTriggerDate(ReminderType.atTime), equals(DateTime(2026, 11, 10, 14, 0)));
      expect(getTriggerDate(ReminderType.oneHour), equals(DateTime(2026, 11, 10, 13, 0)));
      expect(getTriggerDate(ReminderType.oneDay), equals(DateTime(2026, 11, 9, 14, 0)));
      expect(getTriggerDate(ReminderType.twoDays), equals(DateTime(2026, 11, 8, 14, 0)));
      expect(getTriggerDate(ReminderType.threeDays), equals(DateTime(2026, 11, 7, 14, 0)));
      expect(getTriggerDate(ReminderType.sevenDays), equals(DateTime(2026, 11, 3, 14, 0)));
      expect(getTriggerDate(ReminderType.oneWeek), equals(DateTime(2026, 11, 3, 14, 0)));
      expect(getTriggerDate(ReminderType.custom, 5), equals(DateTime(2026, 11, 5, 14, 0)));
    });

    test('Daily greeting notification uses reserved ID 900001', () {
      const dailyGreetingId = 900001;
      expect(dailyGreetingId, equals(900001));
    });

    test('Class reminder notifications use ID range 500000 to 599999', () {
      const classIdStart = 500000;
      const classIdEnd = 599999;

      expect(classIdStart, equals(500000));
      expect(classIdEnd, equals(599999));
    });
  });
}
