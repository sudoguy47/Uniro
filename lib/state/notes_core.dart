import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/local_store.dart';
import '../domain/preloaded_notes.dart';

mixin NotesCore on ChangeNotifier {
  List<Note> _notes = [];
  List<String> _folders = ['Personal', 'Study', 'Work'];
  String? _activeFolder; // null = "All"
  String _searchQuery = '';

  // ── Debounce Timer ────────────────────────────────────────────────────────
  Timer? _saveDebounce;
  bool _disposed = false;

  // ── Memoized Caches ───────────────────────────────────────────────────────
  List<Note>? _cachedNotes;
  Map<String, int>? _cachedFolderCounts;

  void _clearCaches() {
    _cachedNotes = null;
    _cachedFolderCounts = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveDebounce?.cancel();
    super.dispose();
  }

  List<Note> get allNotes => List.unmodifiable(_notes);
  List<String> get folders => List.unmodifiable(_folders);
  String? get activeFolder => _activeFolder;
  String get searchQuery => _searchQuery;

  void _persist() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!_disposed) persistNow();
    });
  }

  void persistNow() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    LocalStore.instance.save('notes', _notes.map((n) => n.toJson()).toList());
    LocalStore.instance.save('note_folders', _folders);
  }

  void loadFromStore() {
    final rawNotes = LocalStore.instance.load('notes');
    if (rawNotes is List && rawNotes.isNotEmpty) {
      _notes = rawNotes
          .map((j) => Note.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    } else {
      _notes = getPreloadedNotes();
      persistNow();
    }

    final rawFolders = LocalStore.instance.load('note_folders');
    if (rawFolders is List && rawFolders.isNotEmpty) {
      _folders = rawFolders.map((f) => f.toString()).toList();
    }

    _clearCaches();
    notifyListeners();
  }

  // ── Filtered & Ordered Notes ──────────────────────────────────────────────
  List<Note> get notes {
    if (_cachedNotes != null) return _cachedNotes!;

    var list = _notes.where((n) {
      if (_activeFolder != null && n.folder != _activeFolder) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = n.title.toLowerCase().contains(q);
        if (matchTitle) return true;
        for (final b in n.blocks) {
          if (b.text.toLowerCase().contains(q)) return true;
        }
        return false;
      }
      return true;
    }).toList();

    // Sort: Pinned first, then newest updated
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return _cachedNotes = List.unmodifiable(list);
  }

  Map<String, int> get folderCounts {
    if (_cachedFolderCounts != null) return _cachedFolderCounts!;

    final map = <String, int>{'All': _notes.length};
    for (final f in _folders) {
      map[f] = _notes.where((n) => n.folder == f).length;
    }
    return _cachedFolderCounts = Map.unmodifiable(map);
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void addNote(Note note) {
    if (note.isEmpty) return;
    _notes.insert(0, note);
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void updateNote(Note note) {
    final i = _notes.indexWhere((n) => n.id == note.id);
    if (i < 0) {
      if (!note.isEmpty) addNote(note);
      return;
    }
    if (note.isEmpty) {
      deleteNote(note.id);
      return;
    }
    _notes[i] = note;
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void deleteNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void togglePin(String id) {
    final i = _notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _notes[i] = _notes[i].copyWith(
      isPinned: !_notes[i].isPinned,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void toggleLock(String id) {
    final i = _notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _notes[i] = _notes[i].copyWith(
      isLocked: !_notes[i].isLocked,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void moveNoteToFolder(String id, String newFolder) {
    final i = _notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _notes[i] = _notes[i].copyWith(
      folder: newFolder,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void setNoteColorTag(String id, int? colorInt) {
    final i = _notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _notes[i] = _notes[i].copyWith(
      colorTag: colorInt,
      clearColorTag: colorInt == null,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void setActiveFolder(String? folder) {
    if (_activeFolder == folder) return;
    _activeFolder = folder;
    _cachedNotes = null;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    if (_searchQuery == q) return;
    _searchQuery = q;
    _cachedNotes = null;
    notifyListeners();
  }

  void addFolder(String folderName) {
    final name = folderName.trim();
    if (name.isEmpty || _folders.contains(name)) return;
    _folders.add(name);
    _clearCaches();
    notifyListeners();
    _persist();
  }

  void renameFolder(String oldName, String newName) {
    final name = newName.trim();
    if (name.isEmpty || name == oldName) return;
    final i = _folders.indexOf(oldName);
    if (i >= 0) {
      _folders[i] = name;
      for (var j = 0; j < _notes.length; j++) {
        if (_notes[j].folder == oldName) {
          _notes[j] = _notes[j].copyWith(folder: name);
        }
      }
      if (_activeFolder == oldName) _activeFolder = name;
      _clearCaches();
      notifyListeners();
      _persist();
    }
  }

  void deleteFolder(String folderName) {
    if (!_folders.contains(folderName)) return;
    _folders.remove(folderName);
    // Move notes in deleted folder to 'Personal'
    for (var j = 0; j < _notes.length; j++) {
      if (_notes[j].folder == folderName) {
        _notes[j] = _notes[j].copyWith(folder: 'Personal');
      }
    }
    if (_activeFolder == folderName) _activeFolder = null;
    _clearCaches();
    notifyListeners();
    _persist();
  }
}
