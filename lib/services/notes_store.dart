import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

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
      _notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
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
