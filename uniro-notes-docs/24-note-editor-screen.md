# 24 — Note Editor Screen

**File:** `lib/screens/notes/note_editor_screen.dart`  
**Purpose:** Full-screen block-based editor. Nav bar hidden here.

## Complete Code

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../state/notes_state.dart';
import '../../widgets/notes/formatting_sheet.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});
  final String noteId;
  @override State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late Note _note;
  final _titleController = TextEditingController();
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocuses = [];
  Timer? _autosaveTimer;
  bool _isPinned = false;
  int _focusedBlockIndex = 0;

  @override
  void initState() {
    super.initState();
    final ns = context.read<NotesState>();
    _note = ns.allNotes.firstWhere(
      (n) => n.id == widget.noteId,
      orElse: () => Note(id: widget.noteId,
          createdAt: DateTime.now(), updatedAt: DateTime.now()),
    );
    _isPinned = _note.isPinned;
    _titleController.text = _note.title;
    _rebuildControllers();
  }

  void _rebuildControllers() {
    for (final c in _blockControllers) c.dispose();
    for (final f in _blockFocuses) f.dispose();
    _blockControllers.clear();
    _blockFocuses.clear();
    for (final block in _note.blocks) {
      final ctrl = TextEditingController(text: block.text);
      final focus = FocusNode();
      final idx = _blockControllers.length;
      focus.addListener(() { if (focus.hasFocus) setState(() => _focusedBlockIndex = idx); });
      _blockControllers.add(ctrl);
      _blockFocuses.add(focus);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _saveNow();
    _titleController.dispose();
    for (final c in _blockControllers) c.dispose();
    for (final f in _blockFocuses) f.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  void _saveNow() {
    final updated = _buildNote();
    if (!updated.isEmpty) {
      context.read<NotesState>().updateNote(updated);
      _note = updated;
    }
  }

  Note _buildNote() {
    final blocks = List<NoteBlock>.generate(_note.blocks.length,
        (i) => _note.blocks[i].copyWith(text: _blockControllers[i].text));
    return _note.copyWith(
      title: _titleController.text,
      blocks: blocks,
      updatedAt: DateTime.now(),
    );
  }

  void _addBlockAt(int afterIndex, BlockType type) {
    _saveNow();
    final newBlock = NoteBlock(id: generateNoteId(), type: type);
    final newBlocks = List.of(_note.blocks)..insert(afterIndex + 1, newBlock);
    setState(() { _note = _note.copyWith(blocks: newBlocks); _rebuildControllers(); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (afterIndex + 1 < _blockFocuses.length)
        _blockFocuses[afterIndex + 1].requestFocus();
    });
  }

  void _removeBlockAt(int index) {
    if (_note.blocks.length <= 1) return;
    _saveNow();
    final newBlocks = List.of(_note.blocks)..removeAt(index);
    setState(() { _note = _note.copyWith(blocks: newBlocks); _rebuildControllers(); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prev = (index - 1).clamp(0, _blockFocuses.length - 1);
      _blockFocuses[prev].requestFocus();
    });
  }

  void _toggleCheck(int index) {
    final b = _note.blocks[index];
    final newBlocks = List.of(_note.blocks)..[index] = b.copyWith(checked: !b.checked);
    setState(() => _note = _note.copyWith(blocks: newBlocks));
    _scheduleAutosave();
  }

  void _applyStyle(NoteBlockStyle Function(NoteBlockStyle) fn) {
    final i = _focusedBlockIndex;
    if (i >= _note.blocks.length) return;
    final newBlock = _note.blocks[i].copyWith(style: fn(_note.blocks[i].style));
    final newBlocks = List.of(_note.blocks)..[i] = newBlock;
    setState(() => _note = _note.copyWith(blocks: newBlocks));
    _scheduleAutosave();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(child: Column(children: [
        _EditorTopBar(
          folderName: _note.folder,
          isPinned: _isPinned,
          onBack: () => Navigator.of(context).pop(),
          onPinToggle: () {
            setState(() => _isPinned = !_isPinned);
            _note = _note.copyWith(isPinned: _isPinned);
            context.read<NotesState>().togglePin(_note.id);
          },
          onMore: () {},
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 60),
            children: [
              TextField(
                controller: _titleController,
                onChanged: (_) => _scheduleAutosave(),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Title', border: InputBorder.none,
                  contentPadding: EdgeInsets.zero),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(
                  _formatDate(_note.createdAt),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...List.generate(_note.blocks.length, (i) => _BlockWidget(
                key: ValueKey(_note.blocks[i].id),
                block: _note.blocks[i],
                controller: _blockControllers[i],
                focusNode: _blockFocuses[i],
                onChanged: (_) => _scheduleAutosave(),
                onEnter: () => _addBlockAt(i, BlockType.paragraph),
                onBackspaceEmpty: () => _removeBlockAt(i),
                onToggleCheck: () => _toggleCheck(i),
              )),
            ],
          ),
        ),
        _FormattingBar(
          onOpenSheet: () {
            final block = _focusedBlockIndex < _note.blocks.length
                ? _note.blocks[_focusedBlockIndex] : null;
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => FormattingSheet(
                currentStyle: block?.style ?? NoteBlockStyle.defaultStyle,
                onStyleChanged: (s) => _applyStyle((_) => s),
                onAddBlock: (type) { Navigator.pop(context); _addBlockAt(_focusedBlockIndex, type); },
              ),
            );
          },
          onBold: () => _applyStyle((s) => s.copyWith(bold: !s.bold)),
          onItalic: () => _applyStyle((s) => s.copyWith(italic: !s.italic)),
          onChecklist: () => _addBlockAt(_focusedBlockIndex, BlockType.checklist),
          onQuote: () => _addBlockAt(_focusedBlockIndex, BlockType.quote),
        ),
      ])),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[dt.weekday-1]}, ${months[dt.month-1]} ${dt.day}, ${dt.year} · ${_note.folder}';
  }
}

// ────────────────────────────────────────────
// Block widget
// ────────────────────────────────────────────

class _BlockWidget extends StatelessWidget {
  const _BlockWidget({
    super.key, required this.block, required this.controller,
    required this.focusNode, required this.onChanged,
    required this.onEnter, required this.onBackspaceEmpty, required this.onToggleCheck,
  });
  final NoteBlock block;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnter, onBackspaceEmpty, onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = block.style;
    final textStyle = TextStyle(
      fontSize: s.fontSize,
      fontWeight: s.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      color: s.textColor != null
          ? Color(int.parse(s.textColor!.replaceFirst('#', '0xFF'))) : null,
    );

    Widget field = TextField(
      controller: controller, focusNode: focusNode,
      onChanged: onChanged, maxLines: null, style: textStyle,
      textAlign: s.alignment,
      decoration: InputDecoration(
        hintText: block.type == BlockType.quote ? 'Add a quote…' : 'Start writing…',
        border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true,
      ),
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      inputFormatters: [_BlockKeyHandler(
        onEnter: onEnter,
        onBackspaceEmpty: () { if (controller.text.isEmpty) onBackspaceEmpty(); },
      )],
    );

    if (block.type == BlockType.quote) {
      field = Container(
        decoration: BoxDecoration(border: Border(
            left: BorderSide(color: cs.primary, width: 3))),
        padding: const EdgeInsets.only(left: 12),
        child: field,
      );
    }

    if (block.type == BlockType.checklist) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggleCheck,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.only(top: 8, right: 10),
                width: 20, height: 20,
                decoration: BoxDecoration(
                  color: block.checked ? cs.primary : Colors.transparent,
                  border: Border.all(
                    color: block.checked ? cs.primary : cs.outline, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: block.checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            Expanded(child: field),
          ],
        ),
      );
    }

    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: field);
  }
}

class _BlockKeyHandler extends TextInputFormatter {
  const _BlockKeyHandler({required this.onEnter, required this.onBackspaceEmpty});
  final VoidCallback onEnter, onBackspaceEmpty;
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    if (next.text.endsWith('\n') && !old.text.endsWith('\n')) {
      Future.microtask(onEnter);
      return old;
    }
    if (next.text.isEmpty && old.text.isEmpty) Future.microtask(onBackspaceEmpty);
    return next;
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.folderName, required this.isPinned,
    required this.onBack, required this.onPinToggle, required this.onMore,
  });
  final String folderName;
  final bool isPinned;
  final VoidCallback onBack, onPinToggle, onMore;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: onBack),
        Expanded(child: Text(folderName,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.primary))),
        IconButton(
          icon: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 20),
          onPressed: onPinToggle),
        IconButton(icon: const Icon(Icons.more_horiz_rounded, size: 20), onPressed: onMore),
      ]),
    );
  }
}

class _FormattingBar extends StatelessWidget {
  const _FormattingBar({
    required this.onOpenSheet, required this.onBold,
    required this.onItalic, required this.onChecklist, required this.onQuote,
  });
  final VoidCallback onOpenSheet, onBold, onItalic, onChecklist, onQuote;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: [
        IconButton(icon: const Icon(Icons.format_list_bulleted_rounded), onPressed: onOpenSheet),
        GestureDetector(onTap: onBold, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: const Text('B', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
        GestureDetector(onTap: onItalic, child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: const Text('I', style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic)))),
        IconButton(icon: const Icon(Icons.checklist_rounded), onPressed: onChecklist),
        IconButton(icon: const Icon(Icons.format_quote_rounded), onPressed: onQuote),
        const Spacer(),
        Text('Autosaved', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        const SizedBox(width: 8),
      ]),
    );
  }
}
```

## Key Behaviors
- `resizeToAvoidBottomInset: true` — keyboard pushes content up
- `flush()` called on `dispose()` — no data loss on pop
- Empty notes never saved
- System back button works automatically (Navigator.push route)
