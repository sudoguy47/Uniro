import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../services/notification_service.dart';
import '../state/notes_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/new_task_sheet.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, required this.note});

  final Note note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late Note _note;
  late TextEditingController _titleController;
  final List<TextEditingController> _blockControllers = [];
  final List<FocusNode> _blockFocusNodes = [];

  // Undo / Redo History Stack
  final List<Note> _undoStack = [];
  final List<Note> _redoStack = [];

  // Status & Timers
  Timer? _autosaveTimer;
  Timer? _wordCountDebounce;
  Timer? _savedStatusFadeTimer;
  String _saveStatus = ''; // 'Saving...', 'Saved', ''
  bool _unlocked = false;
  int _debouncedWordCount = 0;

  static const List<int> _colorPalette = [
    0x00000000, // None / Transparent
    0xFFE8963C, // Accent Orange
    0xFFD5803B, // Ochre
    0xFF3B6EA5, // Soft Blue
    0xFF4A7C59, // Sage Green
    0xFF8B5E9E, // Muted Purple
    0xFFD94F3D, // Red / Overdue
  ];

  static const List<int> _textColors = [
    0,          // Default Theme Primary Text
    0xFFD94F3D, // Red
    0xFFE8963C, // Orange
    0xFF4A7C59, // Green
    0xFF3B6EA5, // Blue
    0xFF8B5E9E, // Purple
    0xFF888888, // Gray
  ];

  static const List<int> _pastelHighlights = [
    0,          // None (Slash)
    0xFFFFF176, // Soft Yellow
    0xFFA5D6A7, // Soft Green
    0xFF90CAF9, // Soft Blue
    0xFFF48FB1, // Soft Pink
    0xFFFFCC80, // Soft Orange
    0xFFE1BEE7, // Soft Lavender
  ];

  @override
  void initState() {
    super.initState();
    _note = widget.note.copyWith();
    _unlocked = !_note.isLocked;
    _debouncedWordCount = _note.wordCount;

    _titleController = TextEditingController(text: _note.title);
    _titleController.addListener(_onContentChanged);

    _initBlockControllers();
  }

  void _pushHistorySnapshot() {
    if (_undoStack.length >= 25) _undoStack.removeAt(0);
    _undoStack.add(_note.copyWith());
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _redoStack.add(_note.copyWith());
    setState(() {
      _note = _undoStack.removeLast();
      _titleController.value = _titleController.value.copyWith(
        text: _note.title,
        selection: TextSelection.collapsed(offset: _note.title.length),
      );
      _initBlockControllers();
    });
    _saveNow();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    HapticFeedback.selectionClick();
    _undoStack.add(_note.copyWith());
    setState(() {
      _note = _redoStack.removeLast();
      _titleController.value = _titleController.value.copyWith(
        text: _note.title,
        selection: TextSelection.collapsed(offset: _note.title.length),
      );
      _initBlockControllers();
    });
    _saveNow();
  }

  void _initBlockControllers() {
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocusNodes) {
      f.dispose();
    }
    _blockControllers.clear();
    _blockFocusNodes.clear();

    if (_note.blocks.isEmpty) {
      _note.blocks.add(NoteBlock());
    }

    for (var i = 0; i < _note.blocks.length; i++) {
      final block = _note.blocks[i];
      final ctrl = TextEditingController(text: block.text);
      final focus = FocusNode();

      ctrl.addListener(() {
        final newText = ctrl.text;
        _checkAutoFormatShortcuts(i, newText);
        block.text = ctrl.text;
        _onContentChanged();
      });

      _blockControllers.add(ctrl);
      _blockFocusNodes.add(focus);
    }
  }

  void _checkAutoFormatShortcuts(int index, String text) {
    final block = _note.blocks[index];
    if (text.isEmpty && index > 0 && block.text.isEmpty) {
      if (block.type != NoteBlockType.paragraph) {
        setState(() {
          block.type = NoteBlockType.paragraph;
        });
      } else {
        _deleteBlockAt(index);
      }
      return;
    }

    if (text == '- ' || text == '* ') {
      setState(() {
        block.type = NoteBlockType.bullet;
        block.text = '';
        _blockControllers[index].value = const TextEditingValue(text: '');
      });
    } else if (text == '[] ') {
      setState(() {
        block.type = NoteBlockType.checklist;
        block.text = '';
        _blockControllers[index].value = const TextEditingValue(text: '');
      });
    } else if (text == '# ') {
      setState(() {
        block.type = NoteBlockType.heading1;
        block.text = '';
        _blockControllers[index].value = const TextEditingValue(text: '');
      });
    } else if (text == '## ') {
      setState(() {
        block.type = NoteBlockType.heading2;
        block.text = '';
        _blockControllers[index].value = const TextEditingValue(text: '');
      });
    } else if (text == '1. ') {
      setState(() {
        block.type = NoteBlockType.numbered;
        block.text = '';
        _blockControllers[index].value = const TextEditingValue(text: '');
      });
    } else if (text == '/') {
      _showSlashMenu(index);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _wordCountDebounce?.cancel();
    _savedStatusFadeTimer?.cancel();
    _titleController.dispose();
    for (final c in _blockControllers) {
      c.dispose();
    }
    for (final f in _blockFocusNodes) {
      f.dispose();
    }
    _saveNow();
    super.dispose();
  }

  void _onContentChanged() {
    _pushHistorySnapshot();
    _note.title = _titleController.text;

    // Update debounced word count (300ms)
    _wordCountDebounce?.cancel();
    _wordCountDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _debouncedWordCount = _note.wordCount;
        });
      }
    });

    // Save status
    setState(() {
      _saveStatus = 'Saving...';
    });

    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveNow();
    });
  }

  void _saveNow() {
    if (!mounted) return;
    _note.title = _titleController.text;

    if (_note.isEmpty) {
      context.read<NotesState>().deleteNote(_note.id);
    } else {
      context.read<NotesState>().updateNote(_note);
    }

    _savedStatusFadeTimer?.cancel();
    if (mounted) {
      setState(() {
        _saveStatus = 'Saved';
      });
      _savedStatusFadeTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _saveStatus = '';
          });
        }
      });
    }
  }

  void _addNewBlockAfter(int index, {NoteBlockType? type}) {
    final newBlock = NoteBlock(type: type ?? _note.blocks[index].type);
    setState(() {
      _note.blocks.insert(index + 1, newBlock);
      _initBlockControllers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (index + 1 < _blockFocusNodes.length) {
        _blockFocusNodes[index + 1].requestFocus();
      }
    });
  }

  void _deleteBlockAt(int index) {
    if (_note.blocks.length <= 1) return;
    setState(() {
      _note.blocks.removeAt(index);
      _initBlockControllers();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = (index - 1).clamp(0, _blockFocusNodes.length - 1);
      if (target < _blockFocusNodes.length) {
        _blockFocusNodes[target].requestFocus();
      }
    });
  }

  void _insertQuickStartTemplate(String type) {
    HapticFeedback.lightImpact();
    setState(() {
      if (type == 'Checklist') {
        _note.blocks = [NoteBlock(type: NoteBlockType.checklist)];
      } else if (type == 'Class notes') {
        _note.blocks = [
          NoteBlock(type: NoteBlockType.heading2, text: 'Topic Summary'),
          NoteBlock(type: NoteBlockType.bullet, text: 'Key discussion point 1'),
          NoteBlock(type: NoteBlockType.bullet, text: 'Key discussion point 2'),
          NoteBlock(type: NoteBlockType.bullet, text: 'Key discussion point 3'),
        ];
      } else if (type == 'To-do for today') {
        _note.blocks = [
          NoteBlock(type: NoteBlockType.checklist, text: 'Task 1'),
          NoteBlock(type: NoteBlockType.checklist, text: 'Task 2'),
          NoteBlock(type: NoteBlockType.checklist, text: 'Task 3'),
        ];
      }
      _initBlockControllers();
    });
    _saveNow();
  }

  void _showSlashMenu(int index) {
    final c = Theme.of(context).extension<AppColors>()!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border, width: 1),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Insert Block',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.notes_rounded, color: c.textPrimary),
              title: const Text('Paragraph'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.paragraph);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.title_rounded, color: c.textPrimary),
              title: const Text('Heading 1'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.heading1);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.text_fields_rounded, color: c.textPrimary),
              title: const Text('Heading 2'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.heading2);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.check_box_outlined, color: c.textPrimary),
              title: const Text('Checklist'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.checklist);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.format_list_bulleted_rounded, color: c.textPrimary),
              title: const Text('Bullet List'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.bullet);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.format_list_numbered_rounded, color: c.textPrimary),
              title: const Text('Numbered List'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.numbered);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.format_quote_rounded, color: c.textPrimary),
              title: const Text('Quote'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.quote);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.horizontal_rule_rounded, color: c.textPrimary),
              title: const Text('Divider'),
              onTap: () {
                setState(() => _note.blocks[index].type = NoteBlockType.divider);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.add_task_rounded, color: c.accent),
              title: Text('Make a Task', style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _makeChecklistItemTask(_note.blocks[index].text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _makeChecklistItemTask(String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewTaskSheet(
        onClose: () {},
        initialDate: DateTime.now(),
      ),
    );
  }

  void _showFolderPicker() {
    final c = Theme.of(context).extension<AppColors>()!;
    final folders = context.read<NotesState>().folders;
    final folderCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border, width: 1),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Folder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                ),
              ),
            ),
            ...folders.map((f) {
              final isCurrent = f == _note.folder;
              return ListTile(
                title: Text(
                  f,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent ? c.accent : c.textPrimary,
                  ),
                ),
                trailing: isCurrent ? Icon(Icons.check, color: c.accent) : null,
                onTap: () {
                  setState(() => _note.folder = f);
                  _saveNow();
                  Navigator.pop(ctx);
                },
              );
            }),
            const Divider(),
            ListTile(
              leading: Icon(Icons.create_new_folder_outlined, color: c.accent),
              title: Text('New folder', style: TextStyle(color: c.accent, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog<void>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: c.cardBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: c.border, width: 1),
                    ),
                    title: Text('New Folder', style: TextStyle(color: c.textPrimary)),
                    content: TextField(
                      controller: folderCtrl,
                      autofocus: true,
                      style: TextStyle(color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Folder name',
                        filled: true,
                        fillColor: c.inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    actionsAlignment: MainAxisAlignment.end,
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
                      TextButton(
                        onPressed: () {
                          final name = folderCtrl.text.trim();
                          if (name.isNotEmpty) {
                            context.read<NotesState>().addFolder(name);
                            setState(() => _note.folder = name);
                            _saveNow();
                          }
                          Navigator.pop(dialogCtx);
                        },
                        child: Text('Add', style: TextStyle(color: c.accent)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showOverflowMenu() {
    final c = Theme.of(context).extension<AppColors>()!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border, width: 1),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),

                  // Color Tag Picker Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Color tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.textTertiary)),
                        const SizedBox(height: 8),
                        Row(
                          children: _colorPalette.map((colInt) {
                            final isSelected = colInt == 0 ? _note.colorTag == null : _note.colorTag == colInt;
                            final color = colInt == 0 ? c.inputBg : Color(colInt);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _note.colorTag = colInt == 0 ? null : colInt;
                                });
                                setSheetState(() {});
                                _saveNow();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 10),
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                  border: Border.all(color: isSelected ? c.accent : c.border, width: isSelected ? 2.5 : 1),
                                ),
                                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.black54) : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),

                  ListTile(
                    leading: Icon(_note.isPinned ? Icons.push_pin : Icons.push_pin_outlined, color: c.accent),
                    title: Text(_note.isPinned ? 'Unpin Note' : 'Pin to top', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      setState(() => _note.isPinned = !_note.isPinned);
                      _saveNow();
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: Icon(_note.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, color: c.textPrimary),
                    title: Text(_note.isLocked ? 'Unlock Note' : 'Lock Note', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      setState(() => _note.isLocked = !_note.isLocked);
                      _saveNow();
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.folder_outlined, color: c.textPrimary),
                    title: Text('Move to folder (${_note.folder})', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showFolderPicker();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.alarm_add_rounded, color: c.textPrimary),
                    title: Text('Add reminder', style: TextStyle(color: c.textPrimary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null && mounted) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (pickedTime != null && mounted) {
                          NotificationService.instance.showInstantNotification(
                            title: 'Reminder: ${_note.title}',
                            body: 'Scheduled for ${DateFormat('MMM d, h:mm a').format(DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute))}',
                          );
                        }
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.add_task_rounded, color: c.textPrimary),
                    title: Text('Link to Uniro task', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => NewTaskSheet(
                          onClose: () {},
                          initialDate: DateTime.now(),
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    value: _note.moveCheckedToBottom,
                    title: Text('Move checked to bottom', style: TextStyle(color: c.textPrimary, fontSize: 14)),
                    activeColor: c.accent,
                    onChanged: (val) {
                      setState(() => _note.moveCheckedToBottom = val);
                      setSheetState(() {});
                      _saveNow();
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.share_outlined, color: c.textPrimary),
                    title: Text('Share as text', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '${_note.title}\n\n${_note.blocks.map((b) => b.text).join('\n')}'));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Note copied to clipboard')),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.copy_rounded, color: c.textPrimary),
                    title: Text('Duplicate note', style: TextStyle(color: c.textPrimary)),
                    onTap: () {
                      final dup = _note.copyWith(title: '${_note.title} (Copy)');
                      context.read<NotesState>().addNote(dup);
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('Delete Note', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      showDialog<void>(
                        context: context,
                        builder: (confirmCtx) => AlertDialog(
                          backgroundColor: c.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: c.border, width: 1),
                          ),
                          title: Text('Delete Note?', style: TextStyle(color: c.textPrimary)),
                          content: Text('Are you sure you want to delete this note?', style: TextStyle(color: c.textSecondary)),
                          actionsAlignment: MainAxisAlignment.end,
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(confirmCtx), child: Text('Cancel', style: TextStyle(color: c.textSecondary))),
                            TextButton(
                              onPressed: () {
                                context.read<NotesState>().deleteNote(_note.id);
                                Navigator.pop(confirmCtx);
                                Navigator.pop(context);
                              },
                              child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTextFormatSheet(int blockIndex) {
    final c = Theme.of(context).extension<AppColors>()!;
    final block = _note.blocks[blockIndex];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: c.border, width: 1),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.60,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title Row: "Format" & "Reset"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Format', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            block.bold = false;
                            block.italic = false;
                            block.underline = false;
                            block.highlightColor = null;
                            block.textColor = null;
                            block.fontSize = 16.0;
                            block.alignment = TextAlign.left;
                            block.type = NoteBlockType.paragraph;
                          });
                          setSheetState(() {});
                          _saveNow();
                        },
                        child: Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 1. Text Style Segmented Row
                  _sheetSectionLabel('TEXT STYLE', c),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _styleSegment('Normal', block.type == NoteBlockType.paragraph, () {
                        setState(() => block.type = NoteBlockType.paragraph);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('Heading 1', block.type == NoteBlockType.heading1, () {
                        setState(() => block.type = NoteBlockType.heading1);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('Heading 2', block.type == NoteBlockType.heading2, () {
                        setState(() => block.type = NoteBlockType.heading2);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('Quote', block.type == NoteBlockType.quote, () {
                        setState(() => block.type = NoteBlockType.quote);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Emphasis Row
                  _sheetSectionLabel('EMPHASIS', c),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _toggleIconBtn(Icons.format_bold_rounded, block.bold, () {
                        setState(() => block.bold = !block.bold);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Bold', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.format_italic_rounded, block.italic, () {
                        setState(() => block.italic = !block.italic);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Italic', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.format_underlined_rounded, block.underline, () {
                        setState(() => block.underline = !block.underline);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Underline', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.strikethrough_s_rounded, block.checked, () {
                        setState(() => block.checked = !block.checked);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Strikethrough', c),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Lists Row
                  _sheetSectionLabel('LISTS', c),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _toggleIconBtn(Icons.format_list_bulleted_rounded, block.type == NoteBlockType.bullet, () {
                        setState(() {
                          block.type = block.type == NoteBlockType.bullet ? NoteBlockType.paragraph : NoteBlockType.bullet;
                        });
                        setSheetState(() {});
                        _saveNow();
                      }, 'Bullet', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.format_list_numbered_rounded, block.type == NoteBlockType.numbered, () {
                        setState(() {
                          block.type = block.type == NoteBlockType.numbered ? NoteBlockType.paragraph : NoteBlockType.numbered;
                        });
                        setSheetState(() {});
                        _saveNow();
                      }, 'Numbered', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.check_box_outlined, block.type == NoteBlockType.checklist, () {
                        setState(() {
                          block.type = block.type == NoteBlockType.checklist ? NoteBlockType.paragraph : NoteBlockType.checklist;
                        });
                        setSheetState(() {});
                        _saveNow();
                      }, 'Checklist', c),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Align Row
                  _sheetSectionLabel('ALIGN', c),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _toggleIconBtn(Icons.format_align_left_rounded, block.alignment == TextAlign.left, () {
                        setState(() => block.alignment = TextAlign.left);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Left', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.format_align_center_rounded, block.alignment == TextAlign.center, () {
                        setState(() => block.alignment = TextAlign.center);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Center', c),
                      const SizedBox(width: 8),
                      _toggleIconBtn(Icons.format_align_right_rounded, block.alignment == TextAlign.right, () {
                        setState(() => block.alignment = TextAlign.right);
                        setSheetState(() {});
                        _saveNow();
                      }, 'Right', c),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 5. Text Color
                  _sheetSectionLabel('TEXT COLOR', c),
                  const SizedBox(height: 8),
                  Row(
                    children: _textColors.map((colInt) {
                      final isDefault = colInt == 0;
                      final isSelected = isDefault ? block.textColor == null : block.textColor == colInt;
                      final color = isDefault ? c.textPrimary : Color(colInt);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            block.textColor = isDefault ? null : colInt;
                          });
                          setSheetState(() {});
                          _saveNow();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? c.accent : c.border,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          child: isSelected
                              ? Icon(Icons.check, size: 16, color: isDefault && Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 6. Highlight Color
                  _sheetSectionLabel('HIGHLIGHT', c),
                  const SizedBox(height: 8),
                  Row(
                    children: _pastelHighlights.map((colInt) {
                      final isNone = colInt == 0;
                      final isSelected = isNone ? block.highlightColor == null : block.highlightColor == colInt;
                      final color = isNone ? Colors.transparent : Color(colInt);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            block.highlightColor = isNone ? null : colInt;
                          });
                          setSheetState(() {});
                          _saveNow();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                            border: Border.all(
                              color: isSelected ? c.accent : c.border,
                              width: isSelected ? 2.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: isNone
                              ? Icon(Icons.block_rounded, size: 16, color: c.textTertiary)
                              : (isSelected ? const Icon(Icons.check, size: 16, color: Colors.black87) : null),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 7. Size Segmented Control
                  _sheetSectionLabel('SIZE', c),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _styleSegment('Small', block.fontSize == 14.0, () {
                        setState(() => block.fontSize = 14.0);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('Normal', block.fontSize == 16.0, () {
                        setState(() => block.fontSize = 16.0);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('Large', block.fontSize == 20.0, () {
                        setState(() => block.fontSize = 20.0);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                      _styleSegment('XL', block.fontSize == 24.0, () {
                        setState(() => block.fontSize = 24.0);
                        setSheetState(() {});
                        _saveNow();
                      }, c),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetSectionLabel(String text, AppColors c) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: c.textTertiary,
      ),
    );
  }

  Widget _styleSegment(String label, bool isSelected, VoidCallback onTap, AppColors c) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppTheme.fast,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? c.accent : c.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? c.accent : c.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : c.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _toggleIconBtn(IconData icon, bool active, VoidCallback onTap, String tooltip, AppColors c) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: AppTheme.fast,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active ? c.accent : c.inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: active ? Colors.white : c.textPrimary),
        ),
      ),
    );
  }

  void _verifyPinDialog() {
    final c = Theme.of(context).extension<AppColors>()!;
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border, width: 1),
        ),
        title: Text('Locked Note', style: TextStyle(color: c.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter PIN to unlock this note:', style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: '1234',
                filled: true,
                fillColor: c.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              if (pinCtrl.text.length == 4) {
                setState(() => _unlocked = true);
                Navigator.pop(ctx);
              }
            },
            child: Text('Unlock', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (!_unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_unlocked) _verifyPinDialog();
      });
      return Scaffold(
        backgroundColor: c.pageBg,
        appBar: AppBar(
          backgroundColor: c.pageBg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: c.textTertiary),
              const SizedBox(height: 12),
              Text('Locked Note', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
            ],
          ),
        ),
      );
    }

    final dateFormatted = DateFormat('EEE, d MMM yyyy').format(
      DateTime.tryParse(_note.updatedAt) ?? DateTime.now(),
    );

    // Filter/Order blocks if moveCheckedToBottom is enabled
    var displayBlocks = List<NoteBlock>.from(_note.blocks);
    if (_note.moveCheckedToBottom) {
      displayBlocks.sort((a, b) {
        if (a.type == NoteBlockType.checklist && b.type == NoteBlockType.checklist) {
          if (a.checked && !b.checked) return 1;
          if (!a.checked && b.checked) return -1;
        }
        return 0;
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _saveNow();
      },
      child: Scaffold(
        backgroundColor: c.pageBg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(59),
          child: Column(
            children: [
              AppBar(
                backgroundColor: c.pageBg,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: c.textPrimary),
                  onPressed: () {
                    _saveNow();
                    Navigator.pop(context);
                  },
                ),
                title: GestureDetector(
                  onTap: _showFolderPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.cardBgRaised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_note.folder} v',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                centerTitle: false,
                actions: [
                  // Undo Button
                  Opacity(
                    opacity: _undoStack.isNotEmpty ? 1.0 : 0.4,
                    child: IconButton(
                      icon: Icon(Icons.undo_rounded, color: c.textPrimary),
                      onPressed: _undoStack.isNotEmpty ? _undo : null,
                      tooltip: 'Undo',
                    ),
                  ),
                  // Redo Button
                  Opacity(
                    opacity: _redoStack.isNotEmpty ? 1.0 : 0.4,
                    child: IconButton(
                      icon: Icon(Icons.redo_rounded, color: c.textPrimary),
                      onPressed: _redoStack.isNotEmpty ? _redo : null,
                      tooltip: 'Redo',
                    ),
                  ),
                  // Pin Toggle
                  IconButton(
                    icon: Icon(
                      _note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                      color: _note.isPinned ? c.accent : c.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _note.isPinned = !_note.isPinned);
                      _saveNow();
                    },
                    tooltip: 'Pin',
                  ),
                  // Overflow Menu
                  IconButton(
                    icon: Icon(Icons.more_vert_rounded, color: c.textPrimary),
                    onPressed: _showOverflowMenu,
                    tooltip: 'More options',
                  ),
                ],
              ),

              // 3px Color Tag Indicator Line
              if (_note.colorTag != null)
                Container(
                  height: 3,
                  width: double.infinity,
                  color: Color(_note.colorTag!),
                ),
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Save Status Indicator Bar
              if (_saveStatus.isNotEmpty)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _saveStatus.isNotEmpty ? 1.0 : 0.0,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      _saveStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Large Title Field (28sp bold, max 2 lines)
                      TextField(
                        controller: _titleController,
                        maxLines: 2,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: c.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(
                            color: c.textPrimary.withValues(alpha: 0.45),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) {
                          if (_blockFocusNodes.isNotEmpty) {
                            _blockFocusNodes.first.requestFocus();
                          }
                        },
                      ),

                      // Meta Row
                      Text(
                        '$dateFormatted · $_debouncedWordCount words · ${_note.folder}',
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Start Chips (Shown only when note is completely empty)
                      if (_note.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildQuickChip('Checklist', c),
                              _buildQuickChip('Class notes', c),
                              _buildQuickChip('To-do for today', c),
                            ],
                          ),
                        ),

                      // Blocks List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: displayBlocks.length,
                        itemBuilder: (context, index) {
                          final block = displayBlocks[index];
                          final realIndex = _note.blocks.indexOf(block);
                          return _buildBlockTile(realIndex >= 0 ? realIndex : index, block, c);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Docked Formatting Toolbar (above keyboard)
              if (keyboardOpen) _buildDockedFormattingToolbar(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, AppColors c) {
    return GestureDetector(
      onTap: () => _insertQuickStartTemplate(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: c.cardBgRaised,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Text(
          '+ $label',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildDockedFormattingToolbar(AppColors c) {
    return Container(
      height: 48,
      width: double.infinity,
      color: c.cardBg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _toolBtn(
              icon: Icons.title_rounded,
              tooltip: 'Text format',
              onTap: () => _showTextFormatSheet(0),
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_bold_rounded,
              tooltip: 'Bold',
              onTap: () {
                if (_note.blocks.isNotEmpty) {
                  setState(() => _note.blocks.first.bold = !_note.blocks.first.bold);
                  _saveNow();
                }
              },
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_italic_rounded,
              tooltip: 'Italic',
              onTap: () {
                if (_note.blocks.isNotEmpty) {
                  setState(() => _note.blocks.first.italic = !_note.blocks.first.italic);
                  _saveNow();
                }
              },
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_underlined_rounded,
              tooltip: 'Underline',
              onTap: () {
                if (_note.blocks.isNotEmpty) {
                  setState(() => _note.blocks.first.underline = !_note.blocks.first.underline);
                  _saveNow();
                }
              },
              c: c,
            ),
            _toolBtn(
              icon: Icons.check_box_outlined,
              tooltip: 'Checklist',
              onTap: () => _addNewBlockAfter(_note.blocks.length - 1, type: NoteBlockType.checklist),
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_list_bulleted_rounded,
              tooltip: 'Bullet list',
              onTap: () => _addNewBlockAfter(_note.blocks.length - 1, type: NoteBlockType.bullet),
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_list_numbered_rounded,
              tooltip: 'Numbered list',
              onTap: () => _addNewBlockAfter(_note.blocks.length - 1, type: NoteBlockType.numbered),
              c: c,
            ),
            _toolBtn(
              icon: Icons.format_quote_rounded,
              tooltip: 'Quote',
              onTap: () => _addNewBlockAfter(_note.blocks.length - 1, type: NoteBlockType.quote),
              c: c,
            ),
            _toolBtn(
              icon: Icons.horizontal_rule_rounded,
              tooltip: 'Divider',
              onTap: () => _addNewBlockAfter(_note.blocks.length - 1, type: NoteBlockType.divider),
              c: c,
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required AppColors c,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? c.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(icon, size: 20, color: active ? Colors.white : c.textPrimary),
          onPressed: onTap,
        ),
      ),
    );
  }

  Widget _buildBlockTile(int index, NoteBlock block, AppColors c) {
    if (index >= _blockControllers.length) return const SizedBox.shrink();

    final ctrl = _blockControllers[index];
    final focus = _blockFocusNodes[index];

    final isFirstParagraph = index == 0 && _note.blocks.length == 1 && _note.title.isEmpty;
    final hintText = isFirstParagraph ? 'Start writing...' : '';

    final double fontSize = switch (block.type) {
      NoteBlockType.heading1 => 22.0,
      NoteBlockType.heading2 => 18.0,
      _ => block.fontSize,
    };

    final textStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: (block.bold || block.type == NoteBlockType.heading1 || block.type == NoteBlockType.heading2)
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: block.italic ? FontStyle.italic : FontStyle.normal,
      color: (block.type == NoteBlockType.checklist && block.checked)
          ? c.textSecondary.withValues(alpha: 0.5)
          : (block.textColor != null ? Color(block.textColor!) : c.textPrimary),
      decoration: (block.type == NoteBlockType.checklist && block.checked)
          ? TextDecoration.lineThrough
          : (block.underline ? TextDecoration.underline : null),
    );

    if (block.type == NoteBlockType.divider) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(color: c.border, thickness: 1.5),
      );
    }

    Widget input = TextField(
      controller: ctrl,
      focusNode: focus,
      minLines: 1,
      maxLines: null,
      textAlign: block.alignment,
      style: textStyle,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: fontSize),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
      ),
      onSubmitted: (_) {
        _addNewBlockAfter(index);
      },
    );

    if (block.type == NoteBlockType.bullet) {
      input = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle)),
          ),
          Expanded(child: input),
        ],
      );
    } else if (block.type == NoteBlockType.numbered) {
      input = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Text('${index + 1}.', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary, fontSize: fontSize)),
          ),
          Expanded(child: input),
        ],
      );
    } else if (block.type == NoteBlockType.checklist) {
      input = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => block.checked = !block.checked);
              _saveNow();
            },
            child: AnimatedContainer(
              duration: AppTheme.micro,
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: block.checked ? c.accent : Colors.transparent,
                border: Border.all(
                  color: block.checked ? c.accent : c.border,
                  width: 2,
                ),
              ),
              child: block.checked ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
            ),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _makeChecklistItemTask(ctrl.text);
              },
              child: input,
            ),
          ),
        ],
      );
    } else if (block.type == NoteBlockType.quote) {
      input = Container(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.accent, width: 3)),
        ),
        child: input,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: input),
          if (_note.blocks.length > 1)
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: c.textTertiary),
              onPressed: () => _deleteBlockAt(index),
              tooltip: 'Remove block',
            ),
        ],
      ),
    );
  }
}
