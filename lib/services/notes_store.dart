import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger.dart';
import '../models/note.dart';
import 'error_log.dart';
import 'note_security_service.dart';

const _kNotesKey = 'uniro_notes_v1';
const _kFoldersKey = 'uniro_note_folders_v1';

class NotesStore {
  List<Note> _notes = [];
  List<String> _folders = ['Personal', 'Study', 'Work'];
  Timer? _debounce;
  SharedPreferences? _prefs;

  List<Note> get notes => List.unmodifiable(_notes);
  List<String> get folders => List.unmodifiable(_folders);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final rawFolders = _prefs!.getStringList(_kFoldersKey);
    if (rawFolders != null && rawFolders.isNotEmpty) _folders = rawFolders;
    final raw = _prefs!.getString(_kNotesKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final parsed = <Note>[];
      for (final e in list) {
        try {
          if (e is Map<String, dynamic>) {
            parsed.add(Note.fromJson(e));
          } else if (e is Map) {
            parsed.add(Note.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (err, st) {
          ErrorLog.record(err, st, 'load_notes');
        }
      }
      bool needsSave = false;
      for (var i = 0; i < parsed.length; i++) {
        final n = parsed[i];
        if (n.isLocked && n.encryptedPayload == null && n.blocks.isNotEmpty) {
          try {
            final encrypted =
                await NoteSecurityService.instance.encryptBlocks(n.blocks);
            parsed[i] = n.copyWith(
              encryptedPayload: encrypted,
              blocks: const [],
            );
            needsSave = true;
          } catch (e, st) {
            AppLog.e('Failed to encrypt legacy locked note ${n.id}', e, st);
          }
        }
      }
      _notes = parsed;
      if (needsSave) {
        await _flushNotes();
      }
    } catch (e, st) {
      ErrorLog.record(e, st, 'load_notes_json');
      _notes = [];
    }
  }

  void saveNotes(List<Note> notes) {
    _notes = List.of(notes);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _flushNotes);
  }

  Future<void> _flushNotes() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      _kNotesKey,
      jsonEncode(_notes.map((n) => n.toJson()).toList()),
    );
  }

  Future<void> saveFolders(List<String> folders) async {
    _folders = List.of(folders);
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_kFoldersKey, _folders);
  }

  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      await _flushNotes();
    }
  }

  void dispose() => _debounce?.cancel();
}
