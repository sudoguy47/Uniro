import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Complete, versioned JSON export/import of all locally stored user data.
///
/// Layout (v1):
/// ```json
/// {
///   "format": "uniro-backup",
///   "backupVersion": 1,
///   "app": "uniro",
///   "exportedAt": "...",
///   "appVersion": "1.0.4+2007",
///   "summary": {"tasks": N, "notes": N, "courses": N, ...},
///   "storage": {"ct_tasks": "<raw json>", ...},   // verbatim ct_* keys
///   "notes":   {"uniro_notes_v1": "...", "uniro_note_folders_v1": "..."},
///   "files":   {"avatar": {"base64": "...", "extension": ".jpg"}}
/// }
/// ```
///
/// Merge semantics on import (upsert, never blind-overwrite of lists):
/// - list keys (tasks, courses, slots, attendance, focus sessions) are merged
///   by element id; a record with the same id is replaced by the backup's copy,
///   unknown ids are added, and duplicates are impossible. Attendance records
///   are additionally de-duplicated by the slotId|date occurrence key.
/// - settings, focus engine and other singleton keys are overwritten with the
///   exported values (restore of user preferences).
/// - note folders are unioned.
/// - a one-shot snapshot of the pre-import state is kept on-device under
///   `ct_pre_import_backup` so an accidental import can be recovered manually.
class BackupService {
  static const String backupFormat = 'uniro-backup';
  static const int backupVersion = 1;
  static const int maxAvatarBytes = 5 * 1024 * 1024;

  /// Internal keys that are rebuilt automatically and must not round-trip.
  static const Set<String> _excludedKeys = {
    'ct_schema',
    'ct_class_notif_map',
    'ct_class_notif_next',
    'ct_attendance_notif_map',
    'ct_attendance_notif_next',
    'ct_needs_reschedule',
    'ct_tz_id',
    'ct_pre_import_backup',
    'ct_update_last_check_ms',
    'ct_update_skipped_version',
    'ct_update_skipped_code',
  };

  /// Keys whose lists are merged by id (or occurrence key) instead of
  /// being blindly overwritten.
  static const _listMergeByKey = <String, String>{
    'ct_tasks': 'id',
    'ct_courses': 'id',
    'ct_slots': 'id',
    'ct_focus_sessions_v2': 'id',
  };

  // ── Export ─────────────────────────────────────────────────────────────

  static Future<Uint8List> buildBackupBytes() async {
    final map = await buildBackup();
    return Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(map)));
  }

  static Future<Map<String, dynamic>> buildBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = <String, String>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith('ct_')) continue;
      if (_excludedKeys.contains(key)) continue;
      final v = prefs.getString(key);
      if (v == null) continue;
      storage[key] = v;
    }

    final notesJson = prefs.getString('uniro_notes_v1');
    final foldersList = prefs.getStringList('uniro_note_folders_v1');

    final files = <String, dynamic>{};
    final avatar = await _encodeAvatar(storage['ct_settings']);
    if (avatar != null) files['avatar'] = avatar;

    return {
      'format': backupFormat,
      'backupVersion': backupVersion,
      'app': 'uniro',
      'exportedAt': DateTime.now().toIso8601String(),
      'appVersion': await _appVersion(),
      'summary': _summarize(storage, notesJson, foldersList),
      'storage': storage,
      'notes': {
        if (notesJson != null) 'uniro_notes_v1': notesJson,
        if (foldersList != null)
          'uniro_note_folders_v1': jsonEncode(foldersList),
      },
      'files': files,
    };
  }

  static Map<String, int> _summarize(
    Map<String, String> storage,
    String? notesJson,
    List<String>? folders,
  ) {
    int countList(String? raw) {
      if (raw == null) return 0;
      try {
        final decoded = jsonDecode(raw);
        return decoded is List ? decoded.length : 0;
      } catch (_) {
        return 0;
      }
    }

    return {
      'tasks': countList(storage['ct_tasks']),
      'courses': countList(storage['ct_courses']),
      'slots': countList(storage['ct_slots']),
      'attendance': countList(storage['ct_attendance']),
      'focusSessions': countList(storage['ct_focus_sessions_v2']),
      'notes': countList(notesJson),
      'folders': folders?.length ?? 0,
    };
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Reads the configured avatar from disk and base64-encodes it (capped).
  /// Returns null when there is no avatar or it is unreadable.
  static Future<Map<String, dynamic>?> _encodeAvatar(String? settingsRaw) async {
    try {
      if (settingsRaw == null) return null;
      final decoded = jsonDecode(settingsRaw);
      if (decoded is! Map) return null;
      final avatarUri = decoded['avatarUri'] as String?;
      if (avatarUri == null || avatarUri.isEmpty) return null;
      final file = File(avatarUri);
      if (!await file.exists()) return null;
      final size = await file.length();
      if (size <= 0 || size > maxAvatarBytes) return null;
      final bytes = await file.readAsBytes();
      final ext = _extensionOf(avatarUri);
      return {'base64': base64Encode(bytes), 'extension': ext};
    } catch (_) {
      return null;
    }
  }

  static String _extensionOf(String path) {
    final idx = path.lastIndexOf('.');
    if (idx < 0 || idx > path.length - 2) return '.jpg';
    final ext = path.substring(idx).toLowerCase();
    const ok = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'};
    return ok.contains(ext) ? ext : '.jpg';
  }

  // ── Validation ─────────────────────────────────────────────────────────

  /// Counts shown in the confirmation dialog before a destructive-ish op.
  static BackupSummary summarizeBytes(Uint8List bytes) {
    final parsed = parseBackup(utf8.decode(bytes, allowMalformed: false));
    return BackupSummary(
      tasks: _countListString(parsed.storage['ct_tasks']),
      courses: _countListString(parsed.storage['ct_courses']),
      slots: _countListString(parsed.storage['ct_slots']),
      attendance: _countListString(parsed.storage['ct_attendance']),
      focusSessions:
          _countListString(parsed.storage['ct_focus_sessions_v2']),
      notes: _countListString(parsed.notes['uniro_notes_v1']),
      exportedAt: parsed.exportedAt,
      appVersion: parsed.appVersion,
      hasAvatar: parsed.files.containsKey('avatar'),
    );
  }

  static int _countListString(String? raw) {
    if (raw == null) return 0;
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded.length : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Parses and validates a backup string. Throws [BackupException] with a
  /// user-facing message on any problem. Nothing is written here.
  static ParsedBackup parseBackup(String content) {
    dynamic root;
    try {
      root = jsonDecode(content);
    } on FormatException {
      throw const BackupException(
          'This file is not valid JSON. Export a fresh backup and try again.');
    }
    if (root is! Map) {
      throw const BackupException('This file does not contain a Uniro backup.');
    }

    final format = root['format'] as String?;
    if (format != backupFormat) {
      throw const BackupException(
          'This is not a Uniro backup file (unrecognized format tag).');
    }
    final versionRaw = root['backupVersion'];
    final version = versionRaw is num ? versionRaw.toInt() : -1;
    if (version < 1) {
      throw const BackupException('This backup is missing a version number.');
    }
    if (version > backupVersion) {
      throw BackupException(
          'This backup was made by a newer version of Uniro (backup v$version). '
          'Update the app, then try again.');
    }

    final storageRaw = root['storage'];
    if (storageRaw is! Map) {
      throw const BackupException('This backup is missing its data section.');
    }
    final storage = <String, String>{};
    storageRaw.forEach((k, v) {
      final key = k.toString();
      // Never restore the rebuildable / environment keys even if present.
      if (!key.startsWith('ct_') || _excludedKeys.contains(key)) return;
      if (v is String) {
        storage[key] = v;
      } else if (v is Map || v is List || v is num || v is bool) {
        storage[key] = jsonEncode(v);
      } else if (v == null) {
        // skip
      } else {
        throw BackupException('Corrupt value in backup under "$key".');
      }
    });

    // Every payload must at least be JSON-decodable; reject corrupt files
    // before touching any state.
    for (final entry in storage.entries) {
      try {
        jsonDecode(entry.value);
      } catch (_) {
        throw BackupException(
            'The backup is corrupted at "${entry.key}". Nothing was imported.');
      }
    }

    final notesRaw = root['notes'];
    final notes = <String, String>{};
    if (notesRaw is Map) {
      notesRaw.forEach((k, v) {
        final key = k.toString();
        if (v is String) {
          try {
            jsonDecode(v);
            notes[key] = v;
          } catch (_) {
            throw BackupException(
                'The backup is corrupted at "$key". Nothing was imported.');
          }
        }
      });
    }

    final filesRaw = root['files'];
    final files = <String, dynamic>{};
    if (filesRaw is Map) {
      filesRaw.forEach((k, v) {
        files[k.toString()] = v;
      });
    }

    final exportedAt = root['exportedAt'] as String?;
    final appVersion = root['appVersion'] as String?;

    return ParsedBackup(
      storage: storage,
      notes: notes,
      files: files,
      exportedAt: exportedAt,
      appVersion: appVersion,
    );
  }

  // ── Restore ───────────────────────────────────────────────────────────

  /// Restores a parsed backup into SharedPreferences + notes keys, merging
  /// rather than blindly overwriting list data. Callers must reload their
  /// in-RAM state afterwards (see ExportImportCard).
  static Future<BackupRestoreResult> restore(ParsedBackup parsed) async {
    final prefs = await SharedPreferences.getInstance();

    // Snapshot current data first (one-shot, kept only on-device).
    try {
      final current = await buildBackup();
      await prefs.setString(
          'ct_pre_import_backup', jsonEncode(current));
    } catch (_) {
      // Snapshot failure must never block a confirmed restore.
    }

    final mergedStorage = <String, String>{};

    // 1. Merge the id-keyed lists.
    for (final entry in _listMergeByKey.entries) {
      final key = entry.key;
      final incoming = parsed.storage[key];
      if (incoming == null) continue;
      mergedStorage[key] = _mergeJsonListById(
        existingRaw: prefs.getString(key),
        incomingRaw: incoming,
      );
    }

    // 2. Attendance: merge by id, de-dupe by slotId|date (newest wins).
    final attendanceIncoming = parsed.storage['ct_attendance'];
    if (attendanceIncoming != null) {
      mergedStorage['ct_attendance'] = _mergeJsonListByOccurrence(
        existingRaw: prefs.getString('ct_attendance'),
        incomingRaw: attendanceIncoming,
      );
    }

    // 3. Everything else (settings, focus engine, onboarding flags, …)
    //    restores verbatim.
    for (final entry in parsed.storage.entries) {
      if (_listMergeByKey.containsKey(entry.key)) continue;
      if (entry.key == 'ct_attendance') continue;
      mergedStorage[entry.key] = entry.value;
    }

    // Write merged storage.
    for (final entry in mergedStorage.entries) {
      await prefs.setString(entry.key, entry.value);
    }

    // 4. Notes: merge list by id; folders union.
    int mergedNotes = 0;
    final notesIncoming = parsed.notes['uniro_notes_v1'];
    if (notesIncoming != null) {
      final merged = _mergeJsonListById(
        existingRaw: prefs.getString('uniro_notes_v1'),
        incomingRaw: notesIncoming,
      );
      await prefs.setString('uniro_notes_v1', merged);
      mergedNotes = _countListString(merged);
    }

    final foldersIncoming = parsed.notes['uniro_note_folders_v1'];
    if (foldersIncoming != null) {
      final incoming = _decodeStringList(foldersIncoming);
      final existing = prefs.getStringList('uniro_note_folders_v1') ?? const [];
      final union = <String>[
        ...existing,
        for (final f in incoming)
          if (!existing.contains(f)) f,
      ];
      await prefs.setStringList('uniro_note_folders_v1', union);
    }

    // 5. Avatar: write the bundled image to the app documents directory and
    //    point settings.avatarUri at it.
    String? avatarPath;
    final avatarSpec = parsed.files['avatar'];
    if (avatarSpec is Map) {
      avatarPath = await _writeAvatar(avatarSpec);
    }
    if (avatarPath != null) {
      final settingsRaw =
          mergedStorage['ct_settings'] ?? prefs.getString('ct_settings');
      if (settingsRaw != null) {
        try {
          final settings =
              Map<String, dynamic>.from(jsonDecode(settingsRaw) as Map);
          settings['avatarUri'] = avatarPath;
          mergedStorage['ct_settings'] = jsonEncode(settings);
          await prefs.setString('ct_settings', mergedStorage['ct_settings']!);
        } catch (_) {
          // Avatar stored but settings patch failed: the backup is still
          // valid, the user just keeps the old avatar reference.
        }
      }
    }

    return BackupRestoreResult(
      tasks: _countListString(mergedStorage['ct_tasks']),
      courses: _countListString(mergedStorage['ct_courses']),
      slots: _countListString(mergedStorage['ct_slots']),
      attendance: _countListString(mergedStorage['ct_attendance']),
      focusSessions: _countListString(mergedStorage['ct_focus_sessions_v2']),
      notes: mergedNotes,
      avatarRestored: avatarPath != null,
    );
  }

  /// Merges two JSON lists by their `id` field. Items without an id are
  /// appended verbatim (defensive). Backup wins on id conflict.
  static String _mergeJsonListById({
    required String? existingRaw,
    required String incomingRaw,
  }) {
    final existing = _decodeList(existingRaw);
    final incoming = _decodeList(incomingRaw);
    final byId = <String, dynamic>{};
    final noId = <dynamic>[];
    void put(dynamic item) {
      if (item is Map) {
        final id = item['id']?.toString();
        if (id != null && id.isNotEmpty) {
          byId[id] = item;
          return;
        }
      }
      noId.add(item);
    }

    for (final item in existing) {
      put(item);
    }
    for (final item in incoming) {
      put(item);
    }
    return jsonEncode([...byId.values, ...noId]);
  }

  /// Attendance merge: upsert by id, then collapse occurrences
  /// (slotId|date) keeping the newest recordedAt.
  static String _mergeJsonListByOccurrence({
    required String? existingRaw,
    required String incomingRaw,
  }) {
    final merged = _mergeJsonListById(
      existingRaw: existingRaw,
      incomingRaw: incomingRaw,
    );
    final list = _decodeList(merged);
    final byOccurrence = <String, Map<String, dynamic>>{};
    for (final item in list) {
      if (item is! Map) continue;
      final slotId = item['slotId']?.toString() ?? '';
      final date = item['date']?.toString() ?? '';
      if (slotId.isEmpty || date.isEmpty) {
        byOccurrence['noocc:${item['id'] ?? DateTime.now().microsecondsSinceEpoch}'] =
            Map<String, dynamic>.from(item);
        continue;
      }
      final key = '$slotId|$date';
      final existing = byOccurrence[key];
      if (existing == null) {
        byOccurrence[key] = Map<String, dynamic>.from(item);
        continue;
      }
      final a = existing['recordedAt']?.toString() ?? '';
      final b = item['recordedAt']?.toString() ?? '';
      if (b.compareTo(a) >= 0) {
        byOccurrence[key] = Map<String, dynamic>.from(item);
      }
    }
    return jsonEncode(byOccurrence.values.toList());
  }

  static List<dynamic> _decodeList(String? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  static List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<String?> _writeAvatar(Map<dynamic, dynamic> spec) async {
    try {
      final b64 = spec['base64'] as String?;
      if (b64 == null || b64.isEmpty) return null;
      final extRaw = spec['extension'] as String?;
      var ext = (extRaw ?? '.jpg').toLowerCase();
      const ok = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'};
      if (!ok.contains(ext)) ext = '.jpg';
      final bytes = base64Decode(b64);
      if (bytes.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}uniro_avatar_restored$ext');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}

class ParsedBackup {
  const ParsedBackup({
    required this.storage,
    required this.notes,
    required this.files,
    this.exportedAt,
    this.appVersion,
  });

  final Map<String, String> storage;
  final Map<String, String> notes;
  final Map<String, dynamic> files;
  final String? exportedAt;
  final String? appVersion;
}

class BackupSummary {
  const BackupSummary({
    required this.tasks,
    required this.courses,
    required this.slots,
    required this.attendance,
    required this.focusSessions,
    required this.notes,
    required this.exportedAt,
    required this.appVersion,
    required this.hasAvatar,
  });

  final int tasks;
  final int courses;
  final int slots;
  final int attendance;
  final int focusSessions;
  final int notes;
  final String? exportedAt;
  final String? appVersion;
  final bool hasAvatar;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.tasks,
    required this.courses,
    required this.slots,
    required this.attendance,
    required this.focusSessions,
    required this.notes,
    required this.avatarRestored,
  });

  final int tasks;
  final int courses;
  final int slots;
  final int attendance;
  final int focusSessions;
  final int notes;
  final bool avatarRestored;

  String get summaryText =>
      '$tasks tasks · $courses courses · $slots classes · '
      '$attendance attendance records · $notes notes';
}

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}
