import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/sample_data.dart';
import 'package:uniro1/models/class_slot.dart';
import 'package:uniro1/models/course.dart';
import 'package:uniro1/models/note.dart';
import 'package:uniro1/models/task.dart';

void main() {
  group('buildSampleBundle', () {
    test('produces flagged content for every area', () {
      final b = buildSampleBundle(DateTime(2026, 10, 16, 12));
      expect(b.tasks.length, 10);
      expect(b.courses.length, 4);
      expect(b.slots.length, 5);
      expect(b.notes.length, greaterThanOrEqualTo(2));
      for (final t in b.tasks) {
        expect(t.isSample, isTrue);
      }
      for (final c in b.courses) {
        expect(c.isSample, isTrue);
      }
      for (final s in b.slots) {
        expect(s.isSample, isTrue);
      }
      for (final n in b.notes) {
        expect(n.isSample, isTrue);
      }
    });

    test('ids are unique across the bundle', () {
      final b = buildSampleBundle(DateTime(2026, 10, 16, 12));
      final ids = <String>{
        ...b.tasks.map((t) => t.id),
        ...b.courses.map((c) => c.id),
        ...b.slots.map((s) => s.id),
        ...b.notes.map((n) => n.id),
      };
      expect(
          ids.length,
          b.tasks.length +
              b.courses.length +
              b.slots.length +
              b.notes.length);
    });

    test('task dates sit around today and parse cleanly', () {
      final now = DateTime(2026, 10, 16, 12);
      final b = buildSampleBundle(now);
      for (final t in b.tasks) {
        final d = DateTime.parse(t.dueDate);
        expect(d.isAfter(now.subtract(const Duration(days: 1))), isTrue);
        expect(d.isBefore(now.add(const Duration(days: 11))), isTrue);
      }
    });

    test('slots reference bundled courses with sane times', () {
      final b = buildSampleBundle(DateTime(2026, 10, 16, 12));
      final courseIds = b.courses.map((c) => c.id).toSet();
      for (final s in b.slots) {
        expect(courseIds, contains(s.courseId));
        expect(s.weekday, inInclusiveRange(1, 7));
        expect(s.endMinutes, greaterThan(s.startMinutes));
      }
    });

    test('notes are non-empty (survive the updateNote guard)', () {
      final b = buildSampleBundle(DateTime(2026, 10, 16, 12));
      for (final n in b.notes) {
        expect(n.isEmpty, isFalse);
      }
    });
  });

  group('isSample persistence', () {
    test('Task round-trips the flag, defaults false', () {
      final t = Task(
        title: 'x',
        type: TaskType.assignment,
        dueDate: '2026-10-17',
        priority: TaskPriority.high,
        isSample: true,
      );
      expect(Task.fromJson(t.toJson()).isSample, isTrue);
      final plain = Task(
        title: 'x',
        type: TaskType.assignment,
        dueDate: '2026-10-17',
        priority: TaskPriority.high,
      );
      expect(plain.isSample, isFalse);
      expect(Task.fromJson(plain.toJson()).isSample, isFalse);
    });

    test('Course / ClassSlot / Note round-trip the flag', () {
      final c = Course(name: 'M', isSample: true);
      expect(Course.fromJson(c.toJson()).isSample, isTrue);
      expect(Course.fromJson({'name': 'M'}).isSample, isFalse);

      final s = ClassSlot(
          courseId: 'c', weekday: 1, startMinutes: 60, endMinutes: 120,
          isSample: true);
      expect(ClassSlot.fromJson(s.toJson()).isSample, isTrue);
      expect(ClassSlot.fromJson({'courseId': 'c'}).isSample, isFalse);

      final n = Note(
        id: 'n',
        title: 't',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isSample: true,
      );
      expect(Note.fromJson(n.toJson()).isSample, isTrue);
    });
  });
}
