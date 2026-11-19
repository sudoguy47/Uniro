import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/domain/attendance_logic.dart';
import 'package:uniro1/models/attendance_record.dart';
import 'package:uniro1/models/course.dart';
import 'package:uniro1/services/local_store.dart';
import 'package:uniro1/state/attendance_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  group('attendancePercentage', () {
    test('zero total never divides by zero', () {
      expect(attendancePercentage(0, 0), 0.0);
    });

    test('computes attended / total * 100', () {
      expect(attendancePercentage(3, 4), 75.0);
      expect(attendancePercentage(1, 3), closeTo(33.333, 0.001));
      expect(attendancePercentage(10, 10), 100.0);
    });
  });

  group('summarizeByCourse', () {
    List<AttendanceRecord> records(List<List<dynamic>> rows) {
      return rows.map((r) => AttendanceRecord(
            slotId: r[0] as String,
            courseId: r[1] as String,
            courseName: r[2] as String,
            courseCode: r[3] as String,
            date: r[4] as String,
            startMinutes: r[5] as int,
            endMinutes: r[6] as int,
            status: r[7] == 'attended'
                ? AttendanceStatus.attended
                : AttendanceStatus.absent,
          )).toList();
    }

    test('groups per course with correct totals and percentages', () {
      final list = records([
        ['s1', 'c1', 'Data Structures', 'CSE 2101', '2026-10-01', 540, 630,
          'attended'],
        ['s1', 'c1', 'Data Structures', 'CSE 2101', '2026-10-08', 540, 630,
          'attended'],
        ['s1', 'c1', 'Data Structures', 'CSE 2101', '2026-10-15', 540, 630,
          'absent'],
        ['s2', 'c2', 'Operating Systems', 'CSE 2201', '2026-10-02', 600, 690,
          'absent'],
      ]);
      final summaries = summarizeByCourse(list);
      expect(summaries, hasLength(2));
      final ds =
          summaries.firstWhere((s) => s.courseId == 'c1');
      expect(ds.total, 3);
      expect(ds.attended, 2);
      expect(ds.missed, 1);
      expect(ds.percentage, closeTo(66.666, 0.001));
      final os =
          summaries.firstWhere((s) => s.courseId == 'c2');
      expect(os.total, 1);
      expect(os.attended, 0);
      expect(os.percentage, 0.0);
    });

    test('empty input yields empty summary', () {
      expect(summarizeByCourse(const []), isEmpty);
    });
  });

  group('mergeAttendanceRecords', () {
    AttendanceRecord rec(String slotId, String date, String status,
        {String recordedAt = '2026-10-01T00:00:00.000'}) {
      return AttendanceRecord(
        slotId: slotId,
        courseId: 'c1',
        courseName: 'X',
        courseCode: 'X1',
        date: date,
        startMinutes: 540,
        endMinutes: 630,
        status: status == 'attended'
            ? AttendanceStatus.attended
            : AttendanceStatus.absent,
        recordedAt: recordedAt,
      );
    }

    test('same id survives merge once', () {
      final a = [rec('s1', '2026-10-01', 'attended')];
      final b = [rec('s1', '2026-10-01', 'attended')];
      // Same record content but different ids merge by occurrence instead.
      final merged = mergeAttendanceRecords(a, b);
      expect(merged, hasLength(1));
    });

    test('duplicate occurrence collapses, newest recordedAt wins', () {
      final old = rec('s1', '2026-10-01', 'absent',
          recordedAt: '2026-10-01T08:00:00.000');
      final newer = rec('s1', '2026-10-01', 'attended',
          recordedAt: '2026-10-01T09:00:00.000');
      final merged = mergeAttendanceRecords([old], [newer]);
      expect(merged, hasLength(1));
      expect(merged.single.status, AttendanceStatus.attended);
    });

    test('merge is idempotent', () {
      final a = rec('s1', '2026-10-01', 'attended');
      final round1 = mergeAttendanceRecords([a], [a]);
      final round2 = mergeAttendanceRecords(round1, [a]);
      expect(round2, hasLength(1));
    });

    test('distinct occurrences all survive', () {
      final merged = mergeAttendanceRecords(
        [rec('s1', '2026-10-01', 'attended')],
        [rec('s1', '2026-10-08', 'absent')],
      );
      expect(merged, hasLength(2));
    });
  });

  group('payload parsing', () {
    test('round-trip', () {
      final payload = attendancePayload('slot-123', '2026-11-03');
      expect(payload, 'att|slot-123|2026-11-03');
      final parsed = parseAttendancePayload(payload);
      expect(parsed, isNotNull);
      expect(parsed!.slotId, 'slot-123');
      expect(parsed.date, '2026-11-03');
    });

    test('rejects non-attendance or malformed payloads', () {
      expect(parseAttendancePayload(null), isNull);
      expect(parseAttendancePayload('daily_greeting'), isNull);
      expect(parseAttendancePayload('att||2026-11-03'), isNull);
      expect(parseAttendancePayload('att|slot|not-a-date'), isNull);
      expect(parseAttendancePayload('att|slot'), isNull);
    });
  });

  group('raw store upsert', () {
    test('creates and updates a single record per occurrence', () {
      upsertAttendanceRaw(
        slotId: 's1',
        date: '2026-11-03',
        status: AttendanceStatus.attended,
        startMinutes: 540,
        endMinutes: 630,
        courseId: 'c1',
        courseName: 'Data Structures',
        courseCode: 'CSE 2101',
      );
      var records = readAttendanceRecordsRaw();
      expect(records, hasLength(1));
      expect(records.single.status, AttendanceStatus.attended);
      expect(records.single.courseName, 'Data Structures');

      // Second mark for the same occurrence must not duplicate.
      upsertAttendanceRaw(
        slotId: 's1',
        date: '2026-11-03',
        status: AttendanceStatus.absent,
        startMinutes: 540,
        endMinutes: 630,
      );
      records = readAttendanceRecordsRaw();
      expect(records, hasLength(1));
      expect(records.single.status, AttendanceStatus.absent);

      // A different date is a separate occurrence.
      upsertAttendanceRaw(
        slotId: 's1',
        date: '2026-11-10',
        status: AttendanceStatus.attended,
        startMinutes: 540,
        endMinutes: 630,
      );
      records = readAttendanceRecordsRaw();
      expect(records, hasLength(2));
    });

    test('recordAttendanceFromNotification maps actions and snapshots slot',
        () {
      LocalStore.instance.save('courses', [
        {'id': 'c1', 'name': 'Data Structures', 'code': 'CSE 2101'},
      ]);
      LocalStore.instance.save('slots', [
        {
          'id': 's1',
          'courseId': 'c1',
          'weekday': 2,
          'startMinutes': 540,
          'endMinutes': 630,
        },
      ]);

      expect(
        recordAttendanceFromNotification(
            slotId: 's1', date: '2026-11-03', actionId: 'attended'),
        isTrue,
      );
      var records = readAttendanceRecordsRaw();
      expect(records, hasLength(1));
      expect(records.single.status, AttendanceStatus.attended);
      expect(records.single.courseCode, 'CSE 2101');
      expect(records.single.startMinutes, 540);

      expect(
        recordAttendanceFromNotification(
            slotId: 's1', date: '2026-11-03', actionId: 'missed'),
        isTrue,
      );
      records = readAttendanceRecordsRaw();
      expect(records, hasLength(1));
      expect(records.single.status, AttendanceStatus.absent);

      expect(
        recordAttendanceFromNotification(
            slotId: 's1', date: '2026-11-04', actionId: 'dismissed-nothing'),
        isFalse,
      );
    });
  });

  group('summarizeByCourse with registered courses', () {
    test('includes courses with 0 records', () {
      final course1 = Course(id: 'c1', name: 'CSE', code: 'CSE 101');
      final course2 = Course(id: 'c2', name: 'Math', code: 'MATH 101');

      final summaries = summarizeByCourse([], courses: [course1, course2]);
      expect(summaries, hasLength(2));
      expect(summaries.map((s) => s.courseId), containsAll(['c1', 'c2']));
      expect(summaries.every((s) => s.total == 0 && s.attended == 0), isTrue);
    });
  });

  group('canBunk and needToAttend logic', () {
    test('canBunk returns safe classes to skip when percentage is above target', () {
      // 8 attended out of 8 classes (100%), target 75% -> can bunk (8 * 100 ~/ 75) - 8 = 10 - 8 = 2
      const summary = SubjectAttendanceSummary(
        courseId: 'c1',
        courseName: 'CSE',
        courseCode: '',
        total: 8,
        attended: 8,
        missed: 0,
      );
      expect(summary.canBunk(75), 2);
      expect(summary.needToAttend(75), 0);
    });

    test('needToAttend returns needed consecutive classes when below target', () {
      // 6 attended out of 10 classes (60%), target 75% -> ceil((75*10 - 600) / 25) = 150 / 25 = 6
      const summary = SubjectAttendanceSummary(
        courseId: 'c1',
        courseName: 'CSE',
        courseCode: '',
        total: 10,
        attended: 6,
        missed: 4,
      );
      expect(summary.canBunk(75), 0);
      expect(summary.needToAttend(75), 6);
    });

    test('overall calculators match expectations', () {
      expect(calculateOverallCanBunk(8, 8, 75), 2);
      expect(calculateOverallNeedToAttend(6, 10, 75), 6);
    });
  });

  group('AttendanceState Data Integrity Tests', () {
    test('decrement removes latest record (by date and timestamp) and undo restores original record', () async {
      final state = AttendanceState();
      await state.load();

      // Log 3 records across different dates out of chronological order
      await state.logManual(
        courseId: 'course_ds',
        courseName: 'Data Structures',
        date: '2026-10-01',
        status: AttendanceStatus.attended,
        slotId: 'slot_1',
      );
      await state.logManual(
        courseId: 'course_ds',
        courseName: 'Data Structures',
        date: '2026-10-15',
        status: AttendanceStatus.attended,
        slotId: 'slot_3',
      );
      await state.logManual(
        courseId: 'course_ds',
        courseName: 'Data Structures',
        date: '2026-10-08',
        status: AttendanceStatus.attended,
        slotId: 'slot_2',
      );

      expect(state.records.length, equals(3));

      // Decrement must remove the LATEST record (2026-10-15), NOT the oldest (2026-10-01)
      final removed = await state.removeLatestAttended('course_ds');
      expect(removed, isNotNull);
      expect(removed!.date, equals('2026-10-15'));
      expect(removed.slotId, equals('slot_3'));

      // Check remaining records are the earlier ones
      expect(state.records.length, equals(2));
      final remainingDates = state.records.map((r) => r.date).toList();
      expect(remainingDates, containsAll(['2026-10-01', '2026-10-08']));
      expect(remainingDates, isNot(contains('2026-10-15')));

      // Undo must restore the exact same record with identical ID and date
      await state.restoreRecord(removed);
      expect(state.records.length, equals(3));
      final restoredRecord = state.records.firstWhere((r) => r.id == removed.id);
      expect(restoredRecord.date, equals('2026-10-15'));
      expect(restoredRecord.slotId, equals('slot_3'));
      expect(restoredRecord.status, equals(AttendanceStatus.attended));
    });

    test('duplicate quick-mark is prevented (updates status instead of adding duplicate)', () async {
      final state = AttendanceState();
      await state.load();

      // Quick mark for today as attended
      final first = await state.logManual(
        courseId: 'course_algo',
        courseName: 'Algorithms',
        date: '2026-11-12',
        status: AttendanceStatus.attended,
      );
      expect(state.records.length, equals(1));
      expect(first.status, equals(AttendanceStatus.attended));

      // Quick mark AGAIN for same course on same date as attended
      final second = await state.logManual(
        courseId: 'course_algo',
        courseName: 'Algorithms',
        date: '2026-11-12',
        status: AttendanceStatus.attended,
      );
      // Must NOT add duplicate record!
      expect(state.records.length, equals(1));
      expect(second.id, equals(first.id));

      // Quick mark for same course on same date as absent (toggled status)
      final third = await state.logManual(
        courseId: 'course_algo',
        courseName: 'Algorithms',
        date: '2026-11-12',
        status: AttendanceStatus.absent,
      );
      // Still only 1 record, but updated to absent
      expect(state.records.length, equals(1));
      expect(third.id, equals(first.id));
      expect(third.status, equals(AttendanceStatus.absent));
      expect(state.records.first.status, equals(AttendanceStatus.absent));
    });
  });
}
