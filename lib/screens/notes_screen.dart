import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/task.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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

  // Floating pill and navbar dimensions to ensure the last row is never hidden
  static const double _pillHeight = 52.0;
  static const double _navBarHeight = 58.0;
  static const double _gridBottomPadding = _pillHeight + _navBarHeight + 16.0;

  /// Returns a high-contrast text color based on background luminance.
  /// If any color is ever used as a solid fill, picks dark text on light fill,
  /// or light text on dark fill, ensuring minimum 4.5:1 WCAG contrast.
  static Color _pickTextColor(Color background, Color onSurface) {
    const darkText = Color(0xFF1A1713);
    const lightText = Color(0xFFF5F0E8);

    final bgLum = background.computeLuminance();
    final darkLum = darkText.computeLuminance();
    final lightLum = lightText.computeLuminance();

    final darkContrast = (bgLum > darkLum)
        ? (bgLum + 0.05) / (darkLum + 0.05)
        : (darkLum + 0.05) / (bgLum + 0.05);
    final lightContrast = (bgLum > lightLum)
        ? (bgLum + 0.05) / (lightLum + 0.05)
        : (lightLum + 0.05) / (bgLum + 0.05);

    final onSurfaceLum = onSurface.computeLuminance();
    final onSurfaceContrast = (bgLum > onSurfaceLum)
        ? (bgLum + 0.05) / (onSurfaceLum + 0.05)
        : (onSurfaceLum + 0.05) / (bgLum + 0.05);

    if (onSurfaceContrast >= 4.5) {
      return onSurface;
    }

    return darkContrast >= lightContrast ? darkText : lightText;
  }

  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          context.read<NotesState>().setSearchQuery(_searchCtrl.text);
        }
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openNoteEditor(Note note) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note),
      ),
    );
  }

  void _createNewNote({bool isChecklist = false}) {
    HapticFeedback.lightImpact();
    final activeFolder = context.read<NotesState>().activeFolder ?? 'Personal';
    final initialBlocks = isChecklist
        ? [NoteBlock(type: NoteBlockType.checklist)]
        : [NoteBlock(type: NoteBlockType.paragraph)];

    final newNote = Note(
      folder: activeFolder,
      blocks: initialBlocks,
    );

    context.read<NotesState>().addNote(newNote);
    _openNoteEditor(newNote);
  }

  void _showAddFolderDialog() {
    final c = Theme.of(context).extension<AppColors>()!;
    final folderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('New Folder', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: folderCtrl,
          autofocus: true,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name (e.g. Science)',
            hintStyle: TextStyle(color: c.textTertiary),
            filled: true,
            fillColor: c.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final name = folderCtrl.text.trim();
              if (name.isNotEmpty) {
                context.read<NotesState>().addFolder(name);
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  void _showNoteOptionsSheet(Note note) {
    final c = Theme.of(context).extension<AppColors>()!;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: c.accent,
              ),
              title: Text(note.isPinned ? 'Unpin Note' : 'Pin to top',
                  style: TextStyle(color: c.textPrimary)),
              onTap: () {
                context.read<NotesState>().togglePin(note.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                note.isLocked ? Icons.lock_open : Icons.lock_outline,
                color: c.textPrimary,
              ),
              title: Text(note.isLocked ? 'Unlock Note' : 'Lock Note',
                  style: TextStyle(color: c.textPrimary)),
              onTap: () {
                context.read<NotesState>().toggleLock(note.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () {
                final deletedNote = note;
                context.read<NotesState>().deleteNote(note.id);
                Navigator.pop(ctx);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Note deleted'),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: c.accent,
                      onPressed: () {
                        context.read<NotesState>().addNote(deletedNote);
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final notes = context.select((NotesState s) => s.notes);
    final folderCounts = context.select((NotesState s) => s.folderCounts);
    final folders = context.select((NotesState s) => s.folders);
    final activeFolder = context.select((NotesState s) => s.activeFolder);

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayTasks = context.select(
      (AppState s) => s.tasksForDate(todayStr),
    );

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header: Title & Expandable Search ────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        if (!_isSearching)
                          Expanded(
                            child: Text(
                              'Notes',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: c.border),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                autofocus: true,
                                style: TextStyle(color: c.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search title or notes…',
                                  hintStyle: TextStyle(color: c.textTertiary),
                                  prefixIcon: Icon(Icons.search,
                                      size: 18, color: c.textTertiary),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _isSearching = false);
                                    },
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                ),
                              ),
                            ),
                          ),
                        if (!_isSearching)
                          IconButton(
                            icon: Icon(Icons.search_rounded,
                                color: c.textPrimary, size: 24),
                            onPressed: () {
                              setState(() => _isSearching = true);
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Folder Chips Bar ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildFolderChip(
                          label: 'All Notes',
                          count: folderCounts['All'] ?? 0,
                          isSelected: activeFolder == null,
                          onTap: () =>
                              context.read<NotesState>().setActiveFolder(null),
                          c: c,
                        ),
                        ...folders.map((f) => _buildFolderChip(
                              label: f,
                              count: folderCounts[f] ?? 0,
                              isSelected: activeFolder == f,
                              onTap: () => context
                                  .read<NotesState>()
                                  .setActiveFolder(f),
                              c: c,
                            )),
                        // Add Folder Chip
                        GestureDetector(
                          onTap: _showAddFolderDialog,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: c.cardBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: c.border),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 16, color: c.accent),
                                const SizedBox(width: 4),
                                Text(
                                  'Folder',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: c.accent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Today Task Card ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildTodayCard(todayTasks, c),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                // ── Notes 2-Column Grid ───────────────────────────────────────
                if (notes.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: _gridBottomPadding),
                    sliver: SliverToBoxAdapter(child: _buildEmptyState(c)),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      _gridBottomPadding,
                    ),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final note = notes[index];
                          return RepaintBoundary(
                            child: _buildNoteCard(note, c),
                          );
                        },
                        childCount: notes.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom Floating Pill Action Bar ─────────────────────────────────
          Positioned(
            bottom: 92 + MediaQuery.of(context).padding.bottom,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: c.navActiveBg,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _createNewNote(isChecklist: false),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'New Note',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.navActiveText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 20,
                      color: c.navActiveText.withValues(alpha: 0.25),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _createNewNote(isChecklist: true),
                      child: Icon(
                        Icons.check_box_outlined,
                        size: 20,
                        color: c.navActiveText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColors c,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppTheme.fast,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? c.navActiveBg : c.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? Colors.transparent : c.border,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? c.navActiveText : c.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? c.accent
                    : c.cardBgRaised,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : c.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(List<Task> todayTasks, AppColors c) {
    final pendingTasks =
        todayTasks.where((t) => t.status == TaskStatus.pending).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODAY\'S TASKS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: c.accentDark,
                ),
              ),
              Icon(Icons.today_rounded, size: 16, color: c.accentDark),
            ],
          ),
          const SizedBox(height: 8),
          if (pendingTasks.isEmpty)
            Text(
              'No tasks due today 🎉',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            )
          else
            Column(
              children: pendingTasks.take(3).map((t) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.read<AppState>().completeTask(t.id);
                        },
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: c.accent, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note, AppColors c) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    // Locked notes use the theme surface color without bright fill or color tags
    final hasColorTag = note.colorTag != null && !note.isLocked;
    final tagColor = hasColorTag ? Color(note.colorTag!) : null;

    // Background: the theme surface color (AppColors) in both light and dark,
    // plus a very light tint of that color (about 10% opacity) over the surface.
    final cardBg = tagColor != null
        ? Color.alphaBlend(tagColor.withValues(alpha: 0.10), c.cardBg)
        : c.cardBg;

    // Title uses onSurface, body uses onSurface at 70% opacity.
    // Minimum contrast 4.5:1 in both themes. If any color is ever used as a solid fill,
    // pick the text color from its luminance (dark text on light fill, light text on dark fill).
    final titleColor = _pickTextColor(cardBg, onSurface);
    final bodyColor = titleColor.withValues(alpha: 0.70);

    return GestureDetector(
      onTap: () => _openNoteEditor(note),
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showNoteOptionsSheet(note);
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: note.isPinned ? c.accent : c.border,
            width: note.isPinned ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (tagColor != null)
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.isLocked)
                    SizedBox(
                      height: 18,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (note.isPinned)
                            Icon(Icons.push_pin_rounded,
                                size: 14, color: c.accent),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            note.title.isNotEmpty ? note.title : 'Untitled',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (note.isPinned)
                          Icon(Icons.push_pin_rounded,
                              size: 14, color: c.accent),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: note.isLocked
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 28,
                                  color: bodyColor,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Locked',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: bodyColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: note.blocks.take(3).map((b) {
                              final isChecklist =
                                  b.type == NoteBlockType.checklist;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  isChecklist ? '• ${b.text}' : b.text,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: bodyColor,
                                    height: 1.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.cardBgRaised,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note.folder,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: bodyColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.note_add_rounded, size: 40, color: c.accent),
            ),
            const SizedBox(height: 16),
            Text(
              'Write your first note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep study thoughts, meeting logs, and checklists organized.',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _createNewNote(isChecklist: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Create Note',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
