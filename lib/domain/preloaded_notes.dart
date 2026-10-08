import 'package:flutter/material.dart';
import '../models/note.dart';

List<Note> getPreloadedNotes() {
  final now = DateTime.now();

  return [
    Note(
      title: 'Movies and authors',
      folder: 'Work',
      isPinned: true,
      colorTag: 0xFFF5F0E8,
      blocks: [
        NoteBlock(
          type: NoteBlockType.paragraph,
          text: 'Interstellar — Christopher Nolan\nThe Godfather — Francis Ford Coppola\nFight Club — David Fincher\nParasite — Bong Joon-ho',
          fontSize: 15,
        ),
      ],
      updatedAt: now.subtract(const Duration(minutes: 10)).toIso8601String(),
    ),
    Note(
      title: 'Locked Note',
      folder: 'Personal',
      isPinned: true,
      isLocked: true,
      colorTag: 0xFFFFFFFF,
      blocks: [
        NoteBlock(
          type: NoteBlockType.paragraph,
          text: 'Confidential personal reflection notes.',
        ),
      ],
      updatedAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
    ),
    Note(
      title: 'Art Gallery',
      folder: 'Study',
      colorTag: 0xFFE8963C,
      blocks: [
        NoteBlock(
          type: NoteBlockType.paragraph,
          text: 'MOMA Contemporary art — 11 W 53rd St, New York',
          bold: true,
          fontSize: 15,
        ),
      ],
      updatedAt: now.subtract(const Duration(hours: 3)).toIso8601String(),
    ),
    Note(
      title: 'Weekly Study Checklist',
      folder: 'Study',
      blocks: [
        NoteBlock(
          type: NoteBlockType.checklist,
          text: 'Check your e-mail and course portal',
          checked: true,
        ),
        NoteBlock(
          type: NoteBlockType.checklist,
          text: 'Sort your assignment inbox',
          checked: true,
        ),
        NoteBlock(
          type: NoteBlockType.checklist,
          text: 'Prepare operating systems lab report',
          checked: false,
        ),
      ],
      updatedAt: now.subtract(const Duration(days: 1)).toIso8601String(),
    ),
  ];
}
