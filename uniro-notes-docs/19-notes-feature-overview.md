# 19 — Notes Feature Overview

**Purpose:** High-level architecture, folder structure, and integration plan for the Notes feature inside Uniro (CampusTracker).

---

## What We Are Building

A self-contained note-taking module added as the **3rd tab** in the existing bottom navigation bar. Notes are stored locally (offline-first), support rich block-based editing, folders, color tags, pin/lock, and show today's tasks inline.

---

## Tab Order (after this feature)

| # | Tab | Icon (outlined → filled) |
|---|-----|-------------------------|
| 1 | Dashboard | `Icons.grid_view_outlined` → `Icons.grid_view` |
| 2 | Calendar | `Icons.calendar_today_outlined` → `Icons.calendar_today` |
| 3 | **Notes** | `Icons.description_outlined` → `Icons.description` |
| 4 | Done | `Icons.check_circle_outline` → `Icons.check_circle` |
| 5 | Profile | `Icons.person_outline` → `Icons.person` |

---

## New Files to Create

```
lib/
  models/
    note.dart              # Note, NoteBlock, BlockType, NoteBlockStyle, SpanRange
  services/
    notes_store.dart       # JSON persistence, debounce 350 ms
  state/
    notes_state.dart       # ChangeNotifier, folder list, search, CRUD
  screens/
    notes/
      notes_screen.dart        # Home: chips, grid, today card, FAB
      note_editor_screen.dart  # Full-screen editor
  widgets/
    notes/
      note_card.dart           # Staggered grid card
      today_task_card.dart     # Today's tasks card (reads AppState)
      folder_chips_row.dart    # Horizontally scrollable chips
      formatting_sheet.dart    # Dark bottom sheet for text formatting
      floating_note_pill.dart  # Floating pill FAB
      empty_notes_state.dart   # SVG-like shape illustration
```

## Files to Edit (minimal)

```
lib/
  app/
    app_shell.dart    # Add Notes as 3rd tab, hide nav on editor
  main.dart           # Register NotesState provider
```

---

## Architecture Integration

```
main.dart
  └─ MultiProvider
       ├─ AppState (existing)
       └─ NotesState          ← NEW
            └─ NotesStore     ← NEW (injected)

AppShell (IndexedStack)
  ├─ [0] DashboardScreen
  ├─ [1] CalendarScreen
  ├─ [2] NotesScreen          ← NEW (built lazily on first visit)
  ├─ [3] DoneScreen
  └─ [4] ProfileScreen

NotesScreen
  ├─ TodayTaskCard            (reads context.watch<AppState>)
  ├─ FolderChipsRow           (reads context.select on NotesState.folders)
  └─ NoteGrid                 (reads context.select on NotesState.filteredNotes)
        └─ NoteCard × N       (RepaintBoundary wrapped)

NoteEditorScreen (full-screen route, nav hidden)
  ├─ BlockList (ListView.builder)
  └─ FormattingBottomSheet    (showModalBottomSheet)
```

---

## Data Flow

```
User creates note
  → NotesState.createNote()
    → adds to _notes list
    → notifyListeners()
    → NotesStore.scheduleSave()   ← debounce 350 ms
      → SharedPreferences.setString('notes_data', jsonEncode(...))
```

---

## Bootstrap Integration

In `main.dart`, load notes **during the existing two-phase bootstrap** so notes are in RAM before the first frame:

```dart
// In your existing _bootstrap() or initState:
final notesStore = NotesStore();
await notesStore.load();  // reads SharedPreferences synchronously after await
final notesState = NotesState(store: notesStore);
// Then pass to MultiProvider
```

The `NotesScreen` itself is built **lazily** inside `IndexedStack` — it does zero work at cold start.

---

## Dependencies

No new packages required. Uses only:
- `shared_preferences` (already a dependency)
- `provider` (already a dependency)
- `flutter_animate` (use **only if already in pubspec.yaml**; otherwise use `AnimationController` + `CurvedAnimation`)

---

## Out of Scope (this step)

- Voice input, camera/OCR, images in notes
- Biometric lock (decide: 4-digit PIN or "Coming Soon" — see doc 20)
- Cloud sync
- Undo/redo history
