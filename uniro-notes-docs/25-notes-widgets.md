# 25 — Notes Widgets

**Folder:** `lib/widgets/notes/`  
**Files:** `note_card.dart`, `today_task_card.dart`, `folder_chips_row.dart`, `floating_note_pill.dart`, `formatting_sheet.dart`, `empty_notes_state.dart`

---

## note_card.dart — Key Points

- `RepaintBoundary` is applied **at the call site** in `notes_screen.dart`, not inside the widget
- Stagger animation: `AnimationController` delayed by `animationIndex * 50 ms`
- Respects `MediaQuery.of(context).disableAnimations`
- Long-press shows context menu: Pin / Lock / Delete
- Shows checklist preview (up to 4 items) if note has checklist blocks; else text preview
- Locked notes show lock icon instead of body content
- Color tag shown as small dot in top-right of title row
- Pin stripe = top border with `colorScheme.primary` when `note.isPinned`

```dart
class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.animationIndex = 0,
  });
  final Note note;
  final VoidCallback onTap, onDelete;
  final int animationIndex;
  // ... (see Notion doc 25 for full implementation)
}
```

---

## today_task_card.dart — Key Points

- Uses `context.select<AppState, List<dynamic>>((s) => s.todayTasks)`
- ⚠️ **Adapt to your AppState API:** change `s.todayTasks`, `task.title`, `task.isCompleted`, `context.read<AppState>().toggleTaskDone(task)` to match your actual field names
- Shows max 4 tasks; empty state shows "No tasks due today ✓"
- Circular animated checkbox matches Done screen style

---

## folder_chips_row.dart — Key Points

- `ListView` horizontal scroll with chips: `['All', 'Pinned', ...folders, '+ Add']`
- Active chip: `colorScheme.primary` background
- Long-press on user folders → rename / delete bottom sheet
- Add folder → `AlertDialog` with TextField
- Uses `context.select` for `folders`, `folderCounts`, `activeFolder`

---

## floating_note_pill.dart — Key Points

- Pill-shaped `Container` centered at bottom
- Left half: "+ New Note" (calls `onNewNote`)
- Divider: thin vertical line
- Right half: checklist icon (calls `onNewChecklist`)
- Drop shadow uses `colorScheme.primary` tinted shadow

---

## formatting_sheet.dart — Key Points

- Dark themed (`Color(0xFF1C1C1E)` background)
- `showModalBottomSheet` with `isScrollControlled: true`
- Sections: Highlight Color dots · Text Color dots · Format (B/I/Quote/Checklist) · Alignment + Font size stepper
- Font size clamps 14.0–24.0
- All state held locally in `_FormattingSheetState`; calls `onStyleChanged` on every change
- `onAddBlock` closes sheet and inserts a new block of the chosen type

---

## empty_notes_state.dart — Key Points

- `CustomPaint` draws a simple notebook illustration (no images, no Lottie)
- "Nothing here yet" headline + "Tap the + button to write your first note." body
- Centered in available space via `SliverFillRemaining`

---

> See the full widget code in the Notion documentation hub — **25 — Notes Widgets**.
