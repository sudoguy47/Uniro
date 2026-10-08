import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uniro1/models/note.dart';
import 'package:uniro1/services/notes_store.dart';
import 'package:uniro1/state/notes_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Note Model', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final note = Note(
        id: generateNoteId(),
        title: 'Meeting Notes',
        folder: 'Work',
        isPinned: true,
        blocks: [
          const NoteBlock(
            id: 'b1',
            type: BlockType.paragraph,
            text: 'Discuss roadmap',
          ),
          const NoteBlock(
            id: 'b2',
            type: BlockType.checklist,
            text: 'Send summary',
            checked: true,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();
      final fromJson = Note.fromJson(json);

      expect(fromJson.id, note.id);
      expect(fromJson.title, 'Meeting Notes');
      expect(fromJson.folder, 'Work');
      expect(fromJson.isPinned, true);
      expect(fromJson.blocks.length, 2);
      expect(fromJson.blocks[1].checked, true);
      expect(fromJson.blocks[1].type, BlockType.checklist);
    });

    test('isEmpty returns correct boolean', () {
      final now = DateTime.now();
      final emptyNote = Note(
        id: '1',
        title: '   ',
        blocks: [const NoteBlock(id: 'b1', type: BlockType.paragraph, text: ' ')],
        createdAt: now,
        updatedAt: now,
      );
      expect(emptyNote.isEmpty, true);

      final nonEmptyNote = emptyNote.copyWith(title: 'Title');
      expect(nonEmptyNote.isEmpty, false);
    });
  });

  group('NotesState & NotesStore', () {
    test('createNote adds note and can update and delete', () async {
      final store = NotesStore();
      await store.load();
      final state = NotesState(store: store);

      expect(state.allNotes.isEmpty, true);

      // Create note
      final note = state.createNote();
      expect(state.allNotes.length, 1);
      expect(state.allNotes.first.id, note.id);

      // Update note
      final updated = note.copyWith(title: 'New Title');
      state.updateNote(updated);
      expect(state.allNotes.first.title, 'New Title');

      // Toggle pin
      state.togglePin(note.id);
      expect(state.pinnedNotes.length, 1);

      // Toggle lock
      state.toggleLock(note.id);
      expect(state.allNotes.first.isLocked, true);

      // Delete note
      final deleted = state.deleteNote(note.id);
      expect(deleted?.id, note.id);
      expect(state.allNotes.isEmpty, true);

      // Restore note
      state.restoreNote(deleted!);
      expect(state.allNotes.length, 1);
    });

    test('folder management works properly', () async {
      final store = NotesStore();
      await store.load();
      final state = NotesState(store: store);

      expect(state.folders, contains('Personal'));

      await state.addFolder('Project X');
      expect(state.folders, contains('Project X'));

      await state.renameFolder('Project X', 'Project Y');
      expect(state.folders, contains('Project Y'));
      expect(state.folders, isNot(contains('Project X')));

      await state.deleteFolder('Project Y');
      expect(state.folders, isNot(contains('Project Y')));
    });

    test('search filters notes by title and block text', () async {
      final store = NotesStore();
      await store.load();
      final state = NotesState(store: store);

      final n1 = state.createNote();
      state.updateNote(n1.copyWith(
        title: 'Flutter dev',
        blocks: [const NoteBlock(id: 'b1', type: BlockType.paragraph, text: 'widgets')],
      ));

      final n2 = state.createNote();
      state.updateNote(n2.copyWith(
        title: 'Android studio',
        blocks: [const NoteBlock(id: 'b2', type: BlockType.paragraph, text: 'gradle setup')],
      ));

      state.setSearch('widgets');
      expect(state.filteredNotes.length, 1);
      expect(state.filteredNotes.first.title, 'Flutter dev');

      state.setSearch('studio');
      expect(state.filteredNotes.length, 1);
      expect(state.filteredNotes.first.title, 'Android studio');

      state.setSearch('');
      expect(state.filteredNotes.length, 2);
    });
  });
}
