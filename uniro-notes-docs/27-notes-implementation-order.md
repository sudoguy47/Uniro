# 27 — Notes Implementation Order

**Purpose:** 7-phase build plan. Build in this exact order — each phase compiles independently.

---

## Phase 1 — Data Layer (No UI)
**Time: 30–45 min**

1. Create `lib/models/note.dart` (doc 20)
2. Create `lib/services/notes_store.dart` (doc 21)
3. Create `lib/state/notes_state.dart` (doc 22)
4. Edit `main.dart` (doc 26)

**Acceptance Criteria:**
- [ ] App compiles without errors
- [ ] `NotesState` accessible via `context.read<NotesState>()`
- [ ] Creating a note via `NotesState.createNote()` persists to SharedPreferences

---

## Phase 2 — Navigation Shell
**Time: 20 min**

1. Edit `app/app_shell.dart` (doc 26)
2. Create empty placeholder `lib/screens/notes/notes_screen.dart`:
```dart
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});
  @override Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Notes — Coming soon')));
}
```

**Acceptance Criteria:**
- [ ] App shows 5 tabs in nav bar
- [ ] Notes tab shows placeholder
- [ ] Existing tabs still work

---

## Phase 3 — Widgets
**Time: 60–90 min**

1. `lib/widgets/notes/note_card.dart` (doc 25)
2. `lib/widgets/notes/today_task_card.dart` — adapt `s.todayTasks` / `task.title` / `task.isCompleted` to your AppState API
3. `lib/widgets/notes/folder_chips_row.dart`
4. `lib/widgets/notes/floating_note_pill.dart`
5. `lib/widgets/notes/empty_notes_state.dart`
6. `lib/widgets/notes/formatting_sheet.dart`

**Acceptance Criteria:**
- [ ] Each widget compiles independently
- [ ] NoteCard renders with a test Note object
- [ ] TodayTaskCard shows today's tasks from AppState
- [ ] FormattingSheet opens as a bottom sheet

---

## Phase 4 — Notes Home Screen
**Time: 45–60 min**

1. Replace placeholder with full `lib/screens/notes/notes_screen.dart` (doc 23)

**Acceptance Criteria:**
- [ ] Grid renders pinned + unpinned sections
- [ ] Folder chips filter the grid
- [ ] Search debounced at 200 ms
- [ ] Empty state shown when no match
- [ ] Floating pill above nav bar
- [ ] Long-press context menu (pin/lock/delete)
- [ ] Delete shows undo SnackBar for 4 s

---

## Phase 5 — Note Editor Screen
**Time: 60–90 min**

1. Create `lib/screens/notes/note_editor_screen.dart` (doc 24)
2. Wire slide-up navigation from NotesScreen
3. Hide nav bar on editor open (doc 26 ValueNotifier approach)

**Acceptance Criteria:**
- [ ] Slides up from bottom (280 ms easeOutCubic)
- [ ] Nav bar hidden while editor open
- [ ] Enter adds new block; Backspace on empty removes block
- [ ] Checklist checkbox animates on tap (200 ms)
- [ ] Quote block shows left accent border
- [ ] Autosave fires 500 ms after typing
- [ ] flush() called on pop — no data loss
- [ ] Empty notes NOT saved
- [ ] System back button works

---

## Phase 6 — Formatting Sheet Integration
**Time: 30 min**

1. Connect FormattingSheet from editor bottom bar (already wired in doc 24)

**Acceptance Criteria:**
- [ ] Dark sheet opens with slide-up animation
- [ ] Bold/Italic toggles update text immediately
- [ ] Font size clamps 14–24
- [ ] Highlight color applies background to block
- [ ] Block-type buttons insert new block and close sheet
- [ ] Style changes persist after hot restart

---

## Phase 7 — Polish & Performance Audit
**Time: 30 min**

- [ ] Every `AnimationController`, `FocusNode`, `Timer` disposed
- [ ] `RepaintBoundary` around each NoteCard
- [ ] `context.select` used (not `context.watch`) on notes list, folder list, counts
- [ ] NotesScreen opens without any work on cold start (lazy IndexedStack)
- [ ] `MediaQuery.disableAnimations` respected in NoteCard stagger
- [ ] Tested on low-RAM device: no jank with 50+ cards
- [ ] Dark mode: all colors via `Theme.of(context).colorScheme` tokens

---

## Decisions Still Needed

| # | Question | Impact |
|---|----------|--------|
| 1 | **Lock:** 4-digit PIN or "Coming Soon"? | Whether to build PinEntryScreen |
| 2 | **`flutter_animate` in pubspec?** | Affects NoteCard stagger code |
| 3 | **`AppState.todayTasks` API** | Exact field names in TodayTaskCard |
| 4 | **Nav hide mechanism** | Which pattern fits your AppShell |
