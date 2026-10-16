import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Block Types
// ─────────────────────────────────────────────

enum BlockType { paragraph, checklist, quote }

// ─────────────────────────────────────────────
// Inline span range
// ─────────────────────────────────────────────

class SpanRange {
  final int start;
  final int end;
  final String? boldColor;
  final String? highlightColor;
  final bool bold;
  final bool italic;

  const SpanRange({
    required this.start,
    required this.end,
    this.boldColor,
    this.highlightColor,
    this.bold = false,
    this.italic = false,
  });

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    if (boldColor != null) 'boldColor': boldColor,
    if (highlightColor != null) 'highlightColor': highlightColor,
    if (bold) 'bold': bold,
    if (italic) 'italic': italic,
  };

  factory SpanRange.fromJson(Map<String, dynamic> j) => SpanRange(
    start: j['start'] as int,
    end: j['end'] as int,
    boldColor: j['boldColor'] as String?,
    highlightColor: j['highlightColor'] as String?,
    bold: j['bold'] as bool? ?? false,
    italic: j['italic'] as bool? ?? false,
  );
}

// ─────────────────────────────────────────────
// Block style (applies to whole block)
// ─────────────────────────────────────────────

class NoteBlockStyle {
  final bool bold;
  final bool italic;
  final String? textColor;
  final String? highlightColor;
  final double fontSize;
  final TextAlign alignment;
  final List<SpanRange> spans;

  const NoteBlockStyle({
    this.bold = false,
    this.italic = false,
    this.textColor,
    this.highlightColor,
    this.fontSize = 15.0,
    this.alignment = TextAlign.left,
    this.spans = const [],
  });

  NoteBlockStyle copyWith({
    bool? bold,
    bool? italic,
    String? textColor,
    String? highlightColor,
    double? fontSize,
    TextAlign? alignment,
    List<SpanRange>? spans,
  }) => NoteBlockStyle(
    bold: bold ?? this.bold,
    italic: italic ?? this.italic,
    textColor: textColor ?? this.textColor,
    highlightColor: highlightColor ?? this.highlightColor,
    fontSize: fontSize ?? this.fontSize,
    alignment: alignment ?? this.alignment,
    spans: spans ?? this.spans,
  );

  Map<String, dynamic> toJson() => {
    if (bold) 'bold': bold,
    if (italic) 'italic': italic,
    if (textColor != null) 'textColor': textColor,
    if (highlightColor != null) 'highlightColor': highlightColor,
    if (fontSize != 15.0) 'fontSize': fontSize,
    if (alignment != TextAlign.left) 'alignment': alignment.name,
    if (spans.isNotEmpty) 'spans': spans.map((s) => s.toJson()).toList(),
  };

  factory NoteBlockStyle.fromJson(Map<String, dynamic> j) {
    TextAlign align = TextAlign.left;
    if (j['alignment'] == 'center') align = TextAlign.center;
    if (j['alignment'] == 'right') align = TextAlign.right;
    return NoteBlockStyle(
      bold: j['bold'] as bool? ?? false,
      italic: j['italic'] as bool? ?? false,
      textColor: j['textColor'] as String?,
      highlightColor: j['highlightColor'] as String?,
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 15.0,
      alignment: align,
      spans: (j['spans'] as List<dynamic>? ?? [])
          .map((s) => SpanRange.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  static const NoteBlockStyle defaultStyle = NoteBlockStyle();
}

// ─────────────────────────────────────────────
// A single block
// ─────────────────────────────────────────────

class NoteBlock {
  final String id;
  final BlockType type;
  final String text;
  final bool checked;
  final NoteBlockStyle style;

  const NoteBlock({
    required this.id,
    required this.type,
    this.text = '',
    this.checked = false,
    this.style = NoteBlockStyle.defaultStyle,
  });

  NoteBlock copyWith({
    BlockType? type,
    String? text,
    bool? checked,
    NoteBlockStyle? style,
  }) => NoteBlock(
    id: id,
    type: type ?? this.type,
    text: text ?? this.text,
    checked: checked ?? this.checked,
    style: style ?? this.style,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'text': text,
    if (type == BlockType.checklist) 'checked': checked,
    if (style != NoteBlockStyle.defaultStyle) 'style': style.toJson(),
  };

  factory NoteBlock.fromJson(Map<String, dynamic> j) => NoteBlock(
    id: j['id'] as String,
    type: BlockType.values.firstWhere(
      (e) => e.name == j['type'],
      orElse: () => BlockType.paragraph,
    ),
    text: j['text'] as String? ?? '',
    checked: j['checked'] as bool? ?? false,
    style: j['style'] != null
        ? NoteBlockStyle.fromJson(j['style'] as Map<String, dynamic>)
        : NoteBlockStyle.defaultStyle,
  );
}

// ─────────────────────────────────────────────
// Note (top-level document)
// ─────────────────────────────────────────────

class Note {
  final String id;
  final String title;
  final List<NoteBlock> blocks;
  final String folder;
  final int? colorTag;
  final bool isPinned;
  final bool isLocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? courseId;
  /// True for built-in example content ("Use examples" seed).
  final bool isSample;

  const Note({
    required this.id,
    this.title = '',
    this.blocks = const [],
    this.folder = 'Personal',
    this.colorTag,
    this.isPinned = false,
    this.isLocked = false,
    required this.createdAt,
    required this.updatedAt,
    this.courseId,
    this.isSample = false,
  });

  bool get isEmpty =>
      title.trim().isEmpty && blocks.every((b) => b.text.trim().isEmpty);

  String get previewText => blocks
      .where((b) => b.text.trim().isNotEmpty)
      .take(3)
      .map((b) => b.text)
      .join('\n');

  Note copyWith({
    String? title,
    List<NoteBlock>? blocks,
    String? folder,
    int? colorTag,
    bool? isPinned,
    bool? isLocked,
    DateTime? updatedAt,
    String? courseId,
    bool clearCourseId = false,
    bool? isSample,
  }) => Note(
    id: id,
    title: title ?? this.title,
    blocks: blocks ?? this.blocks,
    folder: folder ?? this.folder,
    colorTag: colorTag ?? this.colorTag,
    isPinned: isPinned ?? this.isPinned,
    isLocked: isLocked ?? this.isLocked,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    courseId: clearCourseId ? null : (courseId ?? this.courseId),
    isSample: isSample ?? this.isSample,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'folder': folder,
    if (colorTag != null) 'colorTag': colorTag,
    'isPinned': isPinned,
    'isLocked': isLocked,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'courseId': courseId,
    if (isSample) 'isSample': true,
  };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    blocks: (j['blocks'] as List<dynamic>? ?? [])
        .map((b) => NoteBlock.fromJson(b as Map<String, dynamic>))
        .toList(),
    folder: j['folder'] as String? ?? 'Personal',
    colorTag: j['colorTag'] as int?,
    isPinned: j['isPinned'] as bool? ?? false,
    isLocked: j['isLocked'] as bool? ?? false,
    createdAt: DateTime.parse(j['createdAt'] as String),
    updatedAt: DateTime.parse(j['updatedAt'] as String),
    courseId: j['courseId'] as String?,
    isSample: j['isSample'] as bool? ?? false,
  );
}

// ─────────────────────────────────────────────
// UUID helper (no external package needed)
// ─────────────────────────────────────────────

String generateNoteId() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  return '${bytes.sublist(0, 4).map(hex).join()}-'
      '${bytes.sublist(4, 6).map(hex).join()}-'
      '${bytes.sublist(6, 8).map(hex).join()}-'
      '${bytes.sublist(8, 10).map(hex).join()}-'
      '${bytes.sublist(10).map(hex).join()}';
}
