import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../services/note_security_service.dart';
import '../services/notes_store.dart';

class NotesState extends ChangeNotifier {
  final NotesStore _store;
  final NoteSecurityService _security;

  NotesState({required NotesStore store, NoteSecurityService? securityService})
      : _store = store,
        _security = securityService ?? NoteSecurityService.instance {
    _notes = List.of(_store.notes);
    _folders = List.of(_store.folders);
  }

  late List<Note> _notes;
  late List<String> _folders;
  String _activeFolder = 'All';
  String _searchQuery = '';

  List<String> get folders => List.unmodifiable(_folders);
  String get activeFolder => _activeFolder;
  String get searchQuery => _searchQuery;

  List<Note> get allNotes {
    final sorted = List.of(_notes)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return sorted;
  }

  List<Note> get filteredNotes {
    var list = allNotes;
    if (_activeFolder != 'All') {
      list = _activeFolder == 'Pinned'
          ? list.where((n) => n.isPinned).toList()
          : list.where((n) => n.folder == _activeFolder).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((n) {
        if (n.title.toLowerCase().contains(q)) return true;
        // Search must not reveal content of locked notes without authentication
        if (n.isLocked) return false;
        return n.blocks.any((b) => b.text.toLowerCase().contains(q));
      }).toList();
    }
    return list;
  }

  List<Note> get pinnedNotes => filteredNotes.where((n) => n.isPinned).toList();
  List<Note> get unpinnedNotes => filteredNotes.where((n) => !n.isPinned).toList();

  Map<String, int> get folderCounts {
    final map = <String, int>{'All': _notes.length};
    for (final f in _folders) {
      map[f] = _notes.where((n) => n.folder == f).length;
    }
    map['Pinned'] = _notes.where((n) => n.isPinned).length;
    return map;
  }

  void setSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setActiveFolder(String folder) {
    if (_activeFolder == folder) return;
    _activeFolder = folder;
    notifyListeners();
  }

  Future<void> addFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _folders.contains(trimmed)) return;
    _folders = [..._folders, trimmed];
    notifyListeners();
    await _store.saveFolders(_folders);
  }

  Future<void> renameFolder(String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || oldName == trimmed) return;
    _folders = _folders.map((f) => f == oldName ? trimmed : f).toList();
    _notes = _notes.map((n) =>
        n.folder == oldName ? n.copyWith(folder: trimmed) : n).toList();
    if (_activeFolder == oldName) {
      _activeFolder = trimmed;
    }
    notifyListeners();
    await _store.saveFolders(_folders);
    _store.saveNotes(_notes);
  }

  Future<void> deleteFolder(String name) async {
    _folders = _folders.where((f) => f != name).toList();
    _notes = _notes.map((n) =>
        n.folder == name ? n.copyWith(folder: 'Personal') : n).toList();
    if (_activeFolder == name) {
      _activeFolder = 'All';
    }
    notifyListeners();
    await _store.saveFolders(_folders);
    _store.saveNotes(_notes);
  }

  Note createNote({BlockType firstBlockType = BlockType.paragraph, String? courseId}) {
    final now = DateTime.now();
    final note = Note(
      id: generateNoteId(),
      folder: (_activeFolder == 'All' || _activeFolder == 'Pinned')
          ? 'Personal'
          : _activeFolder,
      blocks: [NoteBlock(id: generateNoteId(), type: firstBlockType)],
      createdAt: now,
      updatedAt: now,
      courseId: courseId,
    );
    _notes = [note, ..._notes];
    _store.saveNotes(_notes);
    notifyListeners();
    return note;
  }

  Future<void> updateNote(Note updated) async {
    if (updated.isEmpty) return;
    Note noteToSave = updated;

    // Encrypt blocks at rest if locked
    if (updated.isLocked && updated.blocks.isNotEmpty) {
      try {
        final encrypted =
            await _security.encryptBlocks(updated.blocks);
        noteToSave = updated.copyWith(
          encryptedPayload: encrypted,
          blocks: const [],
        );
      } catch (_) {}
    }

    final idx = _notes.indexWhere((n) => n.id == noteToSave.id);
    if (idx == -1) {
      _notes = [noteToSave, ..._notes];
    } else {
      _notes = List.of(_notes)..[idx] = noteToSave;
    }
    _store.saveNotes(_notes);
    notifyListeners();
  }

  Note? deleteNote(String id) {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return null;
    final deleted = _notes[idx];
    _notes = List.of(_notes)..removeAt(idx);
    _store.saveNotes(_notes);
    notifyListeners();
    return deleted;
  }

  void restoreNote(Note note) {
    _notes = [note, ..._notes];
    _store.saveNotes(_notes);
    notifyListeners();
  }

  void togglePin(String id) {
    _notes = _notes.map((n) => n.id == id
        ? n.copyWith(isPinned: !n.isPinned, updatedAt: DateTime.now())
        : n).toList();
    _store.saveNotes(_notes);
    notifyListeners();
  }

  /// Toggles note lock status with biometric/credential authentication and AES-GCM encryption.
  /// Returns `true` if successful, or `false` if authentication failed or biometrics are unavailable.
  Future<bool> toggleLock(String id, {List<NoteBlock>? activeBlocks}) async {
    final idx = _notes.indexWhere((n) => n.id == id);
    if (idx == -1) return false;
    final note = _notes[idx];

    if (!note.isLocked) {
      // Locking note: verify device credential setup first
      final canAuth = await _security.canAuthenticate();
      if (!canAuth) {
        return false;
      }
      final blocksToEncrypt = (activeBlocks != null && activeBlocks.isNotEmpty)
          ? activeBlocks
          : note.blocks;
      try {
        final encrypted =
            await _security.encryptBlocks(blocksToEncrypt);
        final lockedNote = note.copyWith(
          isLocked: true,
          encryptedPayload: encrypted,
          blocks: const [],
          updatedAt: DateTime.now(),
        );
        _notes = List.of(_notes)..[idx] = lockedNote;
        _store.saveNotes(_notes);
        notifyListeners();
        return true;
      } catch (_) {
        return false;
      }
    } else {
      // Unlocking note: authenticate user first
      final auth = await _security.authenticate(
        localizedReason: 'Authenticate to remove note lock',
      );
      if (!auth) return false;

      List<NoteBlock> decryptedBlocks = const [];
      if (note.encryptedPayload != null && note.encryptedPayload!.isNotEmpty) {
        try {
          decryptedBlocks = await _security
              .decryptBlocks(note.encryptedPayload!);
        } catch (_) {
          return false;
        }
      }
      final unlockedNote = note.copyWith(
        isLocked: false,
        blocks: decryptedBlocks,
        clearEncryptedPayload: true,
        updatedAt: DateTime.now(),
      );
      _notes = List.of(_notes)..[idx] = unlockedNote;
      _store.saveNotes(_notes);
      notifyListeners();
      return true;
    }
  }

  void setColorTag(String id, int? color) {
    _notes = _notes.map((n) => n.id == id
        ? n.copyWith(colorTag: color, updatedAt: DateTime.now())
        : n).toList();
    _store.saveNotes(_notes);
    notifyListeners();
  }

  void moveToFolder(String id, String folder) {
    _notes = _notes.map((n) => n.id == id
        ? n.copyWith(folder: folder, updatedAt: DateTime.now())
        : n).toList();
    _store.saveNotes(_notes);
    notifyListeners();
  }

  /// Unlinks a deleted course from all notes (notes themselves are kept).
  void unlinkCourse(String courseId) {
    var changed = false;
    _notes = _notes.map((n) {
      if (n.courseId == courseId) {
        changed = true;
        return n.copyWith(clearCourseId: true, updatedAt: DateTime.now());
      }
      return n;
    }).toList();
    if (!changed) return;
    _store.saveNotes(_notes);
    notifyListeners();
  }

  /// Re-reads notes + folders from disk (used after a backup import).
  /// Never throws.
  Future<void> reloadFromDisk() async {
    await _store.load();
    _notes = List.of(_store.notes);
    _folders = List.of(_store.folders);
    if (_activeFolder != 'All' &&
        _activeFolder != 'Pinned' &&
        !_folders.contains(_activeFolder)) {
      _activeFolder = 'All';
    }
    notifyListeners();
  }

  Future<void> flush() async {
    await _store.flush();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }
}
