import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum NoteBlockType {
  paragraph,
  heading1,
  heading2,
  bullet,
  numbered,
  checklist,
  quote,
  divider,
}

class InlineStyleSpan {
  final int start;
  final int end;
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final int? highlightColor;
  final int? textColor;
  final double? fontSize;

  const InlineStyleSpan({
    required this.start,
    required this.end,
    this.bold,
    this.italic,
    this.underline,
    this.highlightColor,
    this.textColor,
    this.fontSize,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'highlightColor': highlightColor,
        'textColor': textColor,
        'fontSize': fontSize,
      };

  factory InlineStyleSpan.fromJson(Map<String, dynamic> j) => InlineStyleSpan(
        start: j['start'] ?? 0,
        end: j['end'] ?? 0,
        bold: j['bold'],
        italic: j['italic'],
        underline: j['underline'],
        highlightColor: j['highlightColor'],
        textColor: j['textColor'],
        fontSize: (j['fontSize'] as num?)?.toDouble(),
      );
}

class NoteBlock {
  final String id;
  NoteBlockType type;
  String text;
  bool checked;
  bool bold;
  bool italic;
  bool underline;
  int? highlightColor;
  int? textColor;
  double fontSize;
  TextAlign alignment;
  List<InlineStyleSpan> spans;

  NoteBlock({
    String? id,
    this.type = NoteBlockType.paragraph,
    this.text = '',
    this.checked = false,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.highlightColor,
    this.textColor,
    this.fontSize = 16.0,
    this.alignment = TextAlign.left,
    List<InlineStyleSpan>? spans,
  })  : id = id ?? const Uuid().v4(),
        spans = spans ?? [];

  NoteBlock copyWith({
    NoteBlockType? type,
    String? text,
    bool? checked,
    bool? bold,
    bool? italic,
    bool? underline,
    int? highlightColor,
    int? textColor,
    double? fontSize,
    TextAlign? alignment,
    List<InlineStyleSpan>? spans,
  }) {
    return NoteBlock(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      checked: checked ?? this.checked,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      highlightColor: highlightColor ?? this.highlightColor,
      textColor: textColor ?? this.textColor,
      fontSize: fontSize ?? this.fontSize,
      alignment: alignment ?? this.alignment,
      spans: spans ?? List.from(this.spans),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'text': text,
        'checked': checked,
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'highlightColor': highlightColor,
        'textColor': textColor,
        'fontSize': fontSize,
        'alignment': alignment.name,
        'spans': spans.map((s) => s.toJson()).toList(),
      };

  factory NoteBlock.fromJson(Map<String, dynamic> j) => NoteBlock(
        id: j['id'],
        type: _parseBlockType(j['type']),
        text: j['text'] ?? '',
        checked: j['checked'] ?? false,
        bold: j['bold'] ?? false,
        italic: j['italic'] ?? false,
        underline: j['underline'] ?? false,
        highlightColor: j['highlightColor'],
        textColor: j['textColor'],
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 16.0,
        alignment: _parseAlignment(j['alignment']),
        spans: (j['spans'] as List? ?? [])
            .map((s) => InlineStyleSpan.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );

  static NoteBlockType _parseBlockType(dynamic val) {
    if (val == null) return NoteBlockType.paragraph;
    for (final t in NoteBlockType.values) {
      if (t.name == val) return t;
    }
    return NoteBlockType.paragraph;
  }

  static TextAlign _parseAlignment(dynamic val) {
    if (val == null) return TextAlign.left;
    for (final a in TextAlign.values) {
      if (a.name == val) return a;
    }
    return TextAlign.left;
  }
}

class Note {
  final String id;
  String title;
  List<NoteBlock> blocks;
  String folder;
  int? colorTag; // ARGB Color int
  bool isPinned;
  bool isLocked;
  bool moveCheckedToBottom;
  String createdAt;
  String updatedAt;

  Note({
    String? id,
    this.title = '',
    List<NoteBlock>? blocks,
    this.folder = 'Personal',
    this.colorTag,
    this.isPinned = false,
    this.isLocked = false,
    this.moveCheckedToBottom = false,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        blocks = blocks ?? [NoteBlock()],
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  bool get isEmpty {
    if (title.trim().isNotEmpty) return false;
    for (final b in blocks) {
      if (b.text.trim().isNotEmpty) return false;
    }
    return true;
  }

  int get wordCount {
    int count = 0;
    final titleWords = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    count += titleWords;
    for (final b in blocks) {
      if (b.text.trim().isNotEmpty) {
        count += b.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      }
    }
    return count;
  }

  Note copyWith({
    String? title,
    List<NoteBlock>? blocks,
    String? folder,
    int? colorTag,
    bool clearColorTag = false,
    bool? isPinned,
    bool? isLocked,
    bool? moveCheckedToBottom,
    String? updatedAt,
  }) {
    return Note(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      blocks: blocks ?? this.blocks.map((b) => b.copyWith()).toList(),
      folder: folder ?? this.folder,
      colorTag: clearColorTag ? null : (colorTag ?? this.colorTag),
      isPinned: isPinned ?? this.isPinned,
      isLocked: isLocked ?? this.isLocked,
      moveCheckedToBottom: moveCheckedToBottom ?? this.moveCheckedToBottom,
      updatedAt: updatedAt ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'folder': folder,
        'colorTag': colorTag,
        'isPinned': isPinned,
        'isLocked': isLocked,
        'moveCheckedToBottom': moveCheckedToBottom,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'],
        title: j['title'] ?? '',
        blocks: (j['blocks'] as List? ?? [])
            .map((b) => NoteBlock.fromJson(Map<String, dynamic>.from(b)))
            .toList(),
        folder: j['folder'] ?? 'Personal',
        colorTag: j['colorTag'],
        isPinned: j['isPinned'] ?? false,
        isLocked: j['isLocked'] ?? false,
        moveCheckedToBottom: j['moveCheckedToBottom'] ?? false,
        createdAt: j['createdAt'],
        updatedAt: j['updatedAt'],
      );
}
