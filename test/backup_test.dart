import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/services/backup_service.dart';
import 'package:uniro1/services/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStore.instance.init();
  });

  Future<void> seedSampleData() async {
    LocalStore.instance.save('tasks', [
      {
        'id': 't1',
        'title': 'Submit assignment',
        'type': 'assignment',
        'dueDate': '2026-11-10',
        'priority': 'high',
        'status': 'pending',
        'reminders': <Map<String, dynamic>>[],
        'createdAt': '2026-11-01T00:00:00.000',
      },
      {
        'id': 't2',
        'title': 'Read chapter 4',
        'type': 'other',
        'dueDate': '2026-11-12',
        'priority': 'low',
        'status': 'pending',
        'reminders': <Map<String, dynamic>>[],
        'createdAt': '2026-11-01T00:00:00.000',
      },
    ]);
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
        'room': 'SEU 536',
      },
    ]);
    LocalStore.instance.save('attendance', [
      {
        'id': 'a1',
        'slotId': 's1',
        'courseId': 'c1',
        'courseName': 'Data Structures',
        'courseCode': 'CSE 2101',
        'date': '2026-11-03',
        'startMinutes': 540,
        'endMinutes': 630,
        'status': 'attended',
        'recordedAt': '2026-11-03T10:31:00.000',
      },
    ]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uniro_notes_v1', jsonEncode([
      {
        'id': 'n1',
        'title': 'Lecture notes',
        'blocks': [
          {'id': 'b1', 'type': 'paragraph', 'text': 'Trees & graphs'},
        ],
        'folder': 'Study',
        'isPinned': false,
        'isLocked': false,
        'createdAt': '2026-11-01T00:00:00.000',
        'updatedAt': '2026-11-01T00:00:00.000',
      },
    ]));
    await prefs.setStringList('uniro_note_folders_v1', ['Personal', 'Study']);
  }

  group('backup round trip', () {
    test('export then restore into a wiped device preserves the data',
        () async {
      await seedSampleData();

      final bytes = await BackupService.buildBackupBytes();
      final summary = BackupService.summarizeBytes(bytes);
      expect(summary.tasks, 2);
      expect(summary.courses, 1);
      expect(summary.slots, 1);
      expect(summary.attendance, 1);
      expect(summary.notes, 1);

      final parsed = BackupService.parseBackup(utf8.decode(bytes));
      final result = await BackupService.restore(parsed);

      expect(result.tasks, 2);
      expect(result.courses, 1);
      expect(result.slots, 1);
      expect(result.attendance, 1);
      expect(result.notes, 1);

      // Wipe the device, then restore from the export.
      SharedPreferences.setMockInitialValues({});
      await LocalStore.instance.init();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ct_tasks'), isNull);

      final result2 = await BackupService.restore(parsed);
      expect(result2.tasks, 2);

      final restoredTasks =
          jsonDecode(prefs.getString('ct_tasks')!) as List<dynamic>;
      expect(restoredTasks.map((t) => t['id']), containsAll(['t1', 't2']));
      expect(jsonDecode(prefs.getString('ct_courses')!).length, 1);
      expect(jsonDecode(prefs.getString('ct_slots')!).length, 1);
      expect(jsonDecode(prefs.getString('ct_attendance')!).length, 1);
      expect(jsonDecode(prefs.getString('uniro_notes_v1')!).length, 1);
      expect(prefs.getStringList('uniro_note_folders_v1'),
          containsAll(['Personal', 'Study']));
    });

    test('importing the same backup twice does not duplicate records',
        () async {
      await seedSampleData();
      final bytes = await BackupService.buildBackupBytes();
      final parsed = BackupService.parseBackup(utf8.decode(bytes));

      final first = await BackupService.restore(parsed);
      final second = await BackupService.restore(parsed);

      expect(first.tasks, 2);
      expect(second.tasks, 2);
      expect(second.notes, 1);
      expect(second.attendance, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('ct_tasks')!).length, 2);
      expect(jsonDecode(prefs.getString('uniro_notes_v1')!).length, 1);
    });

    test('import merges instead of clobbering: newer local items survive',
        () async {
      await seedSampleData();
      final bytes = await BackupService.buildBackupBytes();
      final parsed = BackupService.parseBackup(utf8.decode(bytes));

      // Local device adds a brand-new task after the backup was made.
      LocalStore.instance.save('tasks', [
        {
          'id': 't-local',
          'title': 'Local-only task',
          'type': 'other',
          'dueDate': '2026-11-20',
          'priority': 'medium',
          'status': 'pending',
          'reminders': <Map<String, dynamic>>[],
          'createdAt': '2026-11-02T00:00:00.000',
        },
      ]);

      await BackupService.restore(parsed);
      final prefs = await SharedPreferences.getInstance();
      final tasks = jsonDecode(prefs.getString('ct_tasks')!) as List<dynamic>;
      final ids = tasks.map((t) => t['id']).toList();
      expect(ids, containsAll(['t-local', 't1', 't2']));
    });

    test('attendance occurrence conflicts keep the newest recordedAt',
        () async {
      await seedSampleData(); // attendance: a1, recordedAt 10:31
      final bytes = await BackupService.buildBackupBytes();
      final parsed = BackupService.parseBackup(utf8.decode(bytes));

      // On this device the same occurrence was re-marked later.
      LocalStore.instance.save('attendance', [
        {
          'id': 'a-local',
          'slotId': 's1',
          'courseId': 'c1',
          'courseName': 'Data Structures',
          'courseCode': 'CSE 2101',
          'date': '2026-11-03',
          'startMinutes': 540,
          'endMinutes': 630,
          'status': 'absent',
          'recordedAt': '2026-11-03T12:00:00.000',
        },
      ]);

      await BackupService.restore(parsed);
      final prefs = await SharedPreferences.getInstance();
      final attendance =
          jsonDecode(prefs.getString('ct_attendance')!) as List<dynamic>;
      expect(attendance.length, 1);
      // The local record is newer, so it wins over the backup's a1.
      expect(attendance.single['status'], 'absent');
      expect(attendance.single['id'], 'a-local');
    });

    test('pre-import snapshot is written before restore', () async {
      await seedSampleData();
      final bytes = await BackupService.buildBackupBytes();
      final parsed = BackupService.parseBackup(utf8.decode(bytes));
      await BackupService.restore(parsed);
      final prefs = await SharedPreferences.getInstance();
      final snapshot = prefs.getString('ct_pre_import_backup');
      expect(snapshot, isNotNull);
      final decoded = jsonDecode(snapshot!) as Map<String, dynamic>;
      expect(decoded['format'], BackupService.backupFormat);
    });

    test('settings are restored from the backup', () async {
      await seedSampleData();
      LocalStore.instance.save('settings', {
        'name': 'Backup Student',
        'theme': 'dark',
        'weekStartDay': 6,
        'minAttendancePercent': 80,
      });
      final bytes = await BackupService.buildBackupBytes();
      final parsed = BackupService.parseBackup(utf8.decode(bytes));

      // Change settings locally, then restore.
      LocalStore.instance.save('settings', {
        'name': 'Local Student',
        'theme': 'light',
        'weekStartDay': 1,
        'minAttendancePercent': 60,
      });
      await BackupService.restore(parsed);

      final prefs = await SharedPreferences.getInstance();
      final settings =
          jsonDecode(prefs.getString('ct_settings')!) as Map<String, dynamic>;
      expect(settings['name'], 'Backup Student');
      expect(settings['theme'], 'dark');
      expect(settings['minAttendancePercent'], 80);
    });

    test('does not carry environment keys into the backup', () async {
      await seedSampleData();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ct_tz_id', 'Asia/Dhaka');
      await prefs.setString('ct_attendance_notif_map', '{"s1|2026-11-03":600001}');
      await prefs.setString('ct_class_notif_next', '600100');

      final bytes = await BackupService.buildBackupBytes();
      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final storage = decoded['storage'] as Map<String, dynamic>;
      expect(storage.containsKey('ct_tz_id'), isFalse);
      expect(storage.containsKey('ct_attendance_notif_map'), isFalse);
      expect(storage.containsKey('ct_class_notif_next'), isFalse);
    });
  });

  group('backup validation', () {
    test('rejects non-JSON content', () {
      expect(
        () => BackupService.parseBackup('definitely not json {'),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects a JSON file that is not a Uniro backup', () {
      expect(
        () => BackupService.parseBackup('{"hello":"world"}'),
        throwsA(isA<BackupException>()),
      );
      expect(
        () => BackupService.parseBackup('[1,2,3]'),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects a backup from a newer app version', () {
      final content = jsonEncode({
        'format': 'uniro-backup',
        'backupVersion': 999,
        'storage': <String, dynamic>{},
      });
      expect(
        () => BackupService.parseBackup(content),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects a backup missing its storage section', () {
      final content = jsonEncode({
        'format': 'uniro-backup',
        'backupVersion': 1,
      });
      expect(
        () => BackupService.parseBackup(content),
        throwsA(isA<BackupException>()),
      );
    });

    test('rejects a backup with corrupt payload before writing anything',
        () async {
      await seedSampleData();
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString('ct_tasks');

      final content = jsonEncode({
        'format': 'uniro-backup',
        'backupVersion': 1,
        'storage': {
          'ct_tasks': '{not valid json',
        },
      });
      expect(
        () => BackupService.parseBackup(content),
        throwsA(isA<BackupException>()),
      );

      // Nothing was imported.
      expect(prefs.getString('ct_tasks'), before);
    });

    test('invalid backup aborts before touching data (restore never called)',
        () {
      expect(
        () => BackupService.parseBackup('garbage'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}
