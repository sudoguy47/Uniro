import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../state/notes_state.dart';
import '../../widgets/notes/folder_chips_row.dart';
import '../../widgets/notes/note_card.dart';
import '../../widgets/notes/floating_note_pill.dart';
import '../../widgets/notes/empty_notes_state.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  bool _searchVisible = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        context.read<NotesState>().setSearch(val);
      }
    });
  }

  void _openEditor(Note note) {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => NoteEditorScreen(noteId: note.id),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 280),
    ));
  }

  void _createNote({BlockType type = BlockType.paragraph}) {
    final note = context.read<NotesState>().createNote(firstBlockType: type);
    _openEditor(note);
  }

  void _deleteNote(Note note) {
    final deleted = context.read<NotesState>().deleteNote(note.id);
    if (deleted == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () => context.read<NotesState>().restoreNote(deleted),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Notes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _searchVisible
                                ? Icons.search_off_rounded
                                : Icons.search_rounded,
                          ),
                          onPressed: () {
                            setState(() => _searchVisible = !_searchVisible);
                            if (!_searchVisible) {
                              _searchController.clear();
                              context.read<NotesState>().setSearch('');
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar
                SliverToBoxAdapter(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _searchVisible
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Search notes…',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // Folder chips
                const SliverToBoxAdapter(child: FolderChipsRow()),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // Notes grid
                _NotesGridSliver(
                  onTap: _openEditor,
                  onDelete: _deleteNote,
                ),

                // Bottom padding to avoid nav bar and floating pill
                const SliverPadding(padding: EdgeInsets.only(bottom: 140)),
              ],
            ),

            // Floating pill above bottom nav bar
            Positioned(
              bottom: 74 + MediaQuery.of(context).padding.bottom * 0.4,
              left: 0,
              right: 0,
              child: FloatingNotePill(
                onNewNote: () => _createNote(),
                onNewChecklist: () => _createNote(type: BlockType.checklist),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesGridSliver extends StatelessWidget {
  const _NotesGridSliver({required this.onTap, required this.onDelete});
  final void Function(Note) onTap;
  final void Function(Note) onDelete;

  @override
  Widget build(BuildContext context) {
    final pinned = context.select<NotesState, List<Note>>((s) => s.pinnedNotes);
    final unpinned = context.select<NotesState, List<Note>>((s) => s.unpinnedNotes);

    if (pinned.isEmpty && unpinned.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyNotesState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (pinned.isNotEmpty) ...[
            const _SectionLabel(label: 'PINNED', icon: Icons.push_pin_rounded),
            _TwoColGrid(notes: pinned, onTap: onTap, onDelete: onDelete),
            const SizedBox(height: 8),
          ],
          if (unpinned.isNotEmpty) ...[
            const _SectionLabel(label: 'ALL NOTES'),
            _TwoColGrid(notes: unpinned, onTap: onTap, onDelete: onDelete),
          ],
        ]),
      ),
    );
  }
}

class _TwoColGrid extends StatelessWidget {
  const _TwoColGrid({
    required this.notes,
    required this.onTap,
    required this.onDelete,
  });

  final List<Note> notes;
  final void Function(Note) onTap;
  final void Function(Note) onDelete;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < notes.length; i += 2) {
      final left = notes[i];
      final right = (i + 1 < notes.length) ? notes[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RepaintBoundary(
                  child: NoteCard(
                    note: left,
                    animationIndex: i,
                    onTap: () => onTap(left),
                    onDelete: () => onDelete(left),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: right != null
                    ? RepaintBoundary(
                        child: NoteCard(
                          note: right,
                          animationIndex: i + 1,
                          onTap: () => onTap(right),
                          onDelete: () => onDelete(right),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
}
