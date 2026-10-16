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

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
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
      orElse: () => Note(
        id: widget.noteId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    _isPinned = _note.isPinned;
    _titleController.text = _note.title;
    _rebuildControllers();
  }

  void _rebuildControllers() {
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocuses) {
      f.dispose();
    }
    _blockControllers.clear();
    _blockFocuses.clear();

    for (final block in _note.blocks) {
      final ctrl = TextEditingController(text: block.text);
      final focus = FocusNode();
      final idx = _blockControllers.length;
      focus.addListener(() {
        if (focus.hasFocus) {
          setState(() => _focusedBlockIndex = idx);
        }
      });
      _blockControllers.add(ctrl);
      _blockFocuses.add(focus);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _saveNow();
    _titleController.dispose();
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocuses) {
      f.dispose();
    }
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
    final blocks = List<NoteBlock>.generate(
      _note.blocks.length,
      (i) => _note.blocks[i].copyWith(
        text: i < _blockControllers.length ? _blockControllers[i].text : '',
      ),
    );
    return _note.copyWith(
      title: _titleController.text,
      blocks: blocks,
      updatedAt: DateTime.now(),
    );
  }

  void _addBlockAt(int afterIndex, BlockType type) {
    _saveNow();
    final newBlock = NoteBlock(id: generateNoteId(), type: type);
    final newBlocks = List<NoteBlock>.of(_note.blocks)..insert(afterIndex + 1, newBlock);
    
    final newCtrl = TextEditingController(text: '');
    final newFocus = FocusNode();
    final insertIdx = afterIndex + 1;
    newFocus.addListener(() {
      if (newFocus.hasFocus && mounted) {
        setState(() => _focusedBlockIndex = insertIdx);
      }
    });

    if (insertIdx <= _blockControllers.length) {
      _blockControllers.insert(insertIdx, newCtrl);
      _blockFocuses.insert(insertIdx, newFocus);
    } else {
      _blockControllers.add(newCtrl);
      _blockFocuses.add(newFocus);
    }

    setState(() {
      _note = _note.copyWith(blocks: newBlocks);
      _focusedBlockIndex = insertIdx;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (insertIdx < _blockFocuses.length && mounted) {
        _blockFocuses[insertIdx].requestFocus();
      }
    });
  }

  void _removeBlockAt(int index) {
    if (_note.blocks.length <= 1) {
      if (index < _blockControllers.length) {
        _blockControllers[index].clear();
      }
      return;
    }
    _saveNow();
    final targetIndex = (index - 1).clamp(0, _note.blocks.length - 2);

    if (targetIndex < _blockFocuses.length) {
      _blockFocuses[targetIndex].requestFocus();
    }

    final oldCtrl = index < _blockControllers.length ? _blockControllers.removeAt(index) : null;
    final oldFocus = index < _blockFocuses.length ? _blockFocuses.removeAt(index) : null;

    final newBlocks = List<NoteBlock>.of(_note.blocks)..removeAt(index);
    setState(() {
      _note = _note.copyWith(blocks: newBlocks);
      _focusedBlockIndex = targetIndex;
    });

    Future.microtask(() {
      oldCtrl?.dispose();
      oldFocus?.dispose();
    });
  }

  void _setBlockType(int index, BlockType newType) {
    if (index >= _note.blocks.length) return;
    final b = _note.blocks[index];
    final updated = b.copyWith(type: newType, checked: false);
    final newBlocks = List<NoteBlock>.of(_note.blocks)..[index] = updated;
    setState(() => _note = _note.copyWith(blocks: newBlocks));
    _scheduleAutosave();
  }

  void _toggleBlockType(BlockType type) {
    final i = _focusedBlockIndex;
    if (i >= _note.blocks.length) {
      _addBlockAt(_note.blocks.length - 1, type);
      return;
    }
    final current = _note.blocks[i];
    if (current.type == type) {
      _setBlockType(i, BlockType.paragraph);
    } else {
      _setBlockType(i, type);
    }
  }

  void _handleBackspaceEmpty(int index) {
    if (index >= _note.blocks.length) return;
    final b = _note.blocks[index];
    if (b.type == BlockType.checklist || b.type == BlockType.quote) {
      _setBlockType(index, BlockType.paragraph);
      return;
    }
    if (_note.blocks.length > 1) {
      _removeBlockAt(index);
    }
  }

  void _handleRemoveChecklist(int index) {
    if (index >= _note.blocks.length) return;
    final text = _blockControllers[index].text.trim();
    if (text.isEmpty && _note.blocks.length > 1) {
      _removeBlockAt(index);
    } else {
      _setBlockType(index, BlockType.paragraph);
    }
  }

  void _toggleCheck(int index) {
    final b = _note.blocks[index];
    final newBlocks = List<NoteBlock>.of(_note.blocks)..[index] = b.copyWith(checked: !b.checked);
    setState(() => _note = _note.copyWith(blocks: newBlocks));
    _scheduleAutosave();
  }

  void _applyStyle(NoteBlockStyle Function(NoteBlockStyle) fn) {
    final i = _focusedBlockIndex;
    if (i >= _note.blocks.length) return;
    final newBlock = _note.blocks[i].copyWith(style: fn(_note.blocks[i].style));
    final newBlocks = List<NoteBlock>.of(_note.blocks)..[i] = newBlock;
    setState(() => _note = _note.copyWith(blocks: newBlocks));
    _scheduleAutosave();
  }

  void _showFolderPicker() {
    final folders = context.read<NotesState>().folders;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Move to Folder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...folders.map((f) => ListTile(
                  title: Text(f),
                  trailing: f == _note.folder
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _note = _note.copyWith(folder: f));
                    context.read<NotesState>().moveToFolder(_note.id, f);
                    Navigator.pop(sheetCtx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showMoreMenu() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text('Folder (${_note.folder})'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showFolderPicker();
              },
            ),
            ListTile(
              leading: Icon(_note.isLocked ? Icons.lock_open : Icons.lock_outline),
              title: Text(_note.isLocked ? 'Unlock Note' : 'Lock Note'),
              onTap: () {
                setState(() => _note = _note.copyWith(isLocked: !_note.isLocked));
                context.read<NotesState>().toggleLock(_note.id);
                Navigator.pop(sheetCtx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Color Tag'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showColorPicker();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<NotesState>().deleteNote(_note.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    const colors = [
      null,
      0xFFE8963C, // Orange
      0xFF4A7C59, // Green
      0xFF3B6EA5, // Blue
      0xFF8B5E9E, // Purple
      0xFFD94F3D, // Red
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pick a Color Tag', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: colors.map((col) {
                  final isSelected = _note.colorTag == col;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _note = _note.copyWith(colorTag: col));
                      context.read<NotesState>().setColorTag(_note.id, col);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: col != null ? Color(col) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: col == null
                          ? const Icon(Icons.block, size: 16, color: Colors.grey)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final focusedBlock = _focusedBlockIndex < _note.blocks.length
        ? _note.blocks[_focusedBlockIndex]
        : null;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _EditorTopBar(
              folderName: _note.folder,
              isPinned: _isPinned,
              onBack: () => Navigator.of(context).pop(),
              onPinToggle: () {
                setState(() => _isPinned = !_isPinned);
                _note = _note.copyWith(isPinned: _isPinned);
                context.read<NotesState>().togglePin(_note.id);
              },
              onFolderTap: _showFolderPicker,
              onMore: _showMoreMenu,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => _scheduleAutosave(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: cs.onSurface,
                    ),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Untitled',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      _formatDate(_note.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  ...List.generate(
                    _note.blocks.length,
                    (i) => _BlockWidget(
                      key: ValueKey(_note.blocks[i].id),
                      block: _note.blocks[i],
                      controller: _blockControllers[i],
                      focusNode: _blockFocuses[i],
                      showHint: i == 0 && _note.blocks.length == 1,
                      onChanged: (_) => _scheduleAutosave(),
                      onEnter: () => _addBlockAt(i, BlockType.paragraph),
                      onBackspaceEmpty: () => _handleBackspaceEmpty(i),
                      onToggleCheck: () => _toggleCheck(i),
                      onRemoveChecklist: () => _handleRemoveChecklist(i),
                    ),
                  ),
                ],
              ),
            ),
            _FormattingBar(
              onOpenSheet: () {
                final block = _focusedBlockIndex < _note.blocks.length
                    ? _note.blocks[_focusedBlockIndex]
                    : null;
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => FormattingSheet(
                    currentStyle: block?.style ?? NoteBlockStyle.defaultStyle,
                    onStyleChanged: (s) => _applyStyle((_) => s),
                    onAddBlock: (type) {
                      Navigator.pop(context);
                      _toggleBlockType(type);
                    },
                  ),
                );
              },
              onBold: () => _applyStyle((s) => s.copyWith(bold: !s.bold)),
              onItalic: () => _applyStyle((s) => s.copyWith(italic: !s.italic)),
              onChecklist: () => _toggleBlockType(BlockType.checklist),
              onQuote: () => _toggleBlockType(BlockType.quote),
              isBold: focusedBlock?.style.bold ?? false,
              isItalic: focusedBlock?.style.italic ?? false,
              isChecklist: focusedBlock?.type == BlockType.checklist,
              isQuote: focusedBlock?.type == BlockType.quote,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}, ${dt.year} · ${_note.folder}';
  }
}

// ────────────────────────────────────────────
// Block widget
// ────────────────────────────────────────────

class _BlockWidget extends StatelessWidget {
  const _BlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.showHint,
    required this.onChanged,
    required this.onEnter,
    required this.onBackspaceEmpty,
    required this.onToggleCheck,
    required this.onRemoveChecklist,
  });

  final NoteBlock block;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showHint;
  final ValueChanged<String> onChanged;
  final VoidCallback onEnter, onBackspaceEmpty, onToggleCheck, onRemoveChecklist;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = block.style;

    // 2. TYPOGRAPHY HIERARCHY
    final double defaultFontSize = switch (block.type) {
      BlockType.checklist => 14.0,
      BlockType.quote => 15.0,
      BlockType.paragraph => 15.0,
    };
    final double fontSize = (s.fontSize != 15.0) ? s.fontSize : defaultFontSize;

    final double lineHeight = switch (block.type) {
      BlockType.checklist => 1.4,
      BlockType.quote => 1.55,
      BlockType.paragraph => 1.5,
    };

    final FontStyle fontStyle = block.type == BlockType.quote
        ? FontStyle.italic
        : (s.italic ? FontStyle.italic : FontStyle.normal);

    final Color? baseTextColor = block.type == BlockType.quote
        ? cs.onSurface.withValues(alpha: 0.9)
        : null;

    final Color? customTextColor = s.textColor != null
        ? Color(int.parse(s.textColor!.replaceFirst('#', '0xFF')))
        : baseTextColor;

    // 4. CHECKLIST DONE STATE
    final bool isChecked = block.type == BlockType.checklist && block.checked;
    final Color effectiveTextColor = isChecked
        ? cs.onSurfaceVariant.withValues(alpha: 0.5)
        : (customTextColor ?? cs.onSurface);
    final TextDecoration effectiveDecoration =
        isChecked ? TextDecoration.lineThrough : TextDecoration.none;

    final TextStyle textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: s.bold ? FontWeight.bold : FontWeight.normal,
      fontStyle: fontStyle,
      height: lineHeight,
      letterSpacing: block.type == BlockType.quote ? 0.2 : null,
      color: effectiveTextColor,
      decoration: effectiveDecoration,
    );

    // 6. EMPTY HINT STYLING
    final hintStyle = TextStyle(
      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
      fontSize: fontSize,
      fontStyle: fontStyle,
      height: lineHeight,
    );

    final String? hintText = switch (block.type) {
      BlockType.quote => '“Write a quote…”',
      BlockType.checklist => null,
      BlockType.paragraph => showHint ? 'Start writing…' : null,
    };

    Widget field = AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 150),
      style: textStyle,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspaceEmpty();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          maxLines: null,
          style: textStyle,
          textAlign: s.alignment,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: hintStyle,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          inputFormatters: [
            _BlockKeyHandler(
              onEnter: onEnter,
            ),
          ],
        ),
      ),
    );

    // 5. HIGHLIGHT RENDERING
    if (s.highlightColor != null) {
      final highlightInt = int.tryParse(s.highlightColor!.replaceFirst('#', '0x33'));
      if (highlightInt != null) {
        field = Container(
          decoration: BoxDecoration(
            color: Color(highlightInt),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: field,
        );
      }
    }

    // 3. QUOTE BLOCK — Authentic quotation look with quotation mark & accent bar
    if (block.type == BlockType.quote) {
      field = Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          border: Border(left: BorderSide(color: cs.primary, width: 3.5)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 1),
              child: Icon(
                Icons.format_quote_rounded,
                size: 20,
                color: cs.primary.withValues(alpha: 0.85),
              ),
            ),
            Expanded(child: field),
          ],
        ),
      );
    }

    // Checklist Alignment & Cross button to remove/undo
    if (block.type == BlockType.checklist) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onToggleCheck,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.only(right: 10),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: block.checked ? cs.primary : Colors.transparent,
                  border: Border.all(
                    color: block.checked ? cs.primary : cs.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: block.checked
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: field,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              tooltip: 'Remove checklist',
              onPressed: onRemoveChecklist,
            ),
          ],
        ),
      );
    }

    // 1. BLOCK SPACING
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: field,
    );
  }
}

class _BlockKeyHandler extends TextInputFormatter {
  const _BlockKeyHandler({
    required this.onEnter,
  });

  final VoidCallback onEnter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue old,
    TextEditingValue next,
  ) {
    if (next.text.endsWith('\n') && !old.text.endsWith('\n')) {
      Future.microtask(onEnter);
      return old;
    }
    return next;
  }
}

class _EditorTopBar extends StatelessWidget {
  const _EditorTopBar({
    required this.folderName,
    required this.isPinned,
    required this.onBack,
    required this.onPinToggle,
    required this.onFolderTap,
    required this.onMore,
  });

  final String folderName;
  final bool isPinned;
  final VoidCallback onBack, onPinToggle, onFolderTap, onMore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onFolderTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    folderName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 20,
              color: isPinned ? cs.primary : null,
            ),
            onPressed: onPinToggle,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 20),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _FormattingBar extends StatelessWidget {
  const _FormattingBar({
    required this.onOpenSheet,
    required this.onBold,
    required this.onItalic,
    required this.onChecklist,
    required this.onQuote,
    this.isBold = false,
    this.isItalic = false,
    this.isChecklist = false,
    this.isQuote = false,
  });

  final VoidCallback onOpenSheet, onBold, onItalic, onChecklist, onQuote;
  final bool isBold;
  final bool isItalic;
  final bool isChecklist;
  final bool isQuote;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.format_list_bulleted_rounded),
              onPressed: onOpenSheet,
              tooltip: 'Formatting sheet',
            ),
            _formatToggleButton(
              label: 'B',
              isActive: isBold,
              isBold: true,
              onTap: onBold,
              cs: cs,
            ),
            const SizedBox(width: 4),
            _formatToggleButton(
              label: 'I',
              isActive: isItalic,
              isItalic: true,
              onTap: onItalic,
              cs: cs,
            ),
            const SizedBox(width: 4),
            _iconToggleButton(
              icon: Icons.checklist_rounded,
              isActive: isChecklist,
              tooltip: 'Checklist',
              onTap: onChecklist,
              cs: cs,
            ),
            const SizedBox(width: 4),
            _iconToggleButton(
              icon: Icons.format_quote_rounded,
              isActive: isQuote,
              tooltip: 'Quote',
              onTap: onQuote,
              cs: cs,
            ),
            const Spacer(),
            Text(
              'Autosaved',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _iconToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
    required ColorScheme cs,
  }) {
    return Material(
      color: isActive ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: isActive ? cs.onPrimaryContainer : cs.onSurface,
        ),
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: onTap,
      ),
    );
  }

  Widget _formatToggleButton({
    required String label,
    required bool isActive,
    bool isBold = false,
    bool isItalic = false,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    return Material(
      color: isActive ? cs.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: isActive ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
