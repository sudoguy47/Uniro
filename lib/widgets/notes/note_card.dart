import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/haptics.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/note.dart';
import '../../state/notes_state.dart';

class NoteCard extends StatefulWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    required this.onDelete,
    this.animationIndex = 0,
  });

  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final int animationIndex;

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _staggerTimer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final disableAnim = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableAnim) {
        _animController.value = 1.0;
      } else {
        final delayMs = (widget.animationIndex * 40).clamp(0, 300);
        _staggerTimer = Timer(Duration(milliseconds: delayMs), () {
          if (mounted) _animController.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _staggerTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _showContextMenu() {
    PremiumHaptics.confirm();
    final cs = Theme.of(context).colorScheme;
    final note = widget.note;

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
              leading: Icon(
                note.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: cs.primary,
              ),
              title: Text(note.isPinned ? 'Unpin Note' : 'Pin to top'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<NotesState>().togglePin(note.id);
              },
            ),
            ListTile(
              leading: Icon(
                note.isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              ),
              title: Text(note.isLocked ? 'Unlock Note' : 'Lock Note'),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.read<NotesState>().toggleLock(note.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete Note', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final note = widget.note;

    final hasColorTag = note.colorTag != null && !note.isLocked;
    final tagColor = hasColorTag ? Color(note.colorTag!) : null;

    final cardBg = tagColor != null
        ? Color.alphaBlend(tagColor.withValues(alpha: 0.12), cs.surface)
        : cs.surface;

    final checklistBlocks = note.blocks
        .where((b) => b.type == BlockType.checklist)
        .toList();
    final hasChecklist = checklistBlocks.isNotEmpty && !note.isLocked;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: _showContextMenu,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                top: BorderSide(
                  color: note.isPinned ? cs.primary : (cs.outlineVariant.withValues(alpha: 0.6)),
                  width: note.isPinned ? 3.5 : 1.0,
                ),
                left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1.0),
                right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1.0),
                bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Title + color tag dot + pin icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isNotEmpty ? note.title : 'Untitled',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tagColor != null) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tagColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    if (note.isPinned) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.push_pin_rounded, size: 14, color: cs.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                // Content
                if (note.isLocked) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 26,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Locked',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (hasChecklist) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: checklistBlocks.take(4).map((b) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              b.checked
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 13,
                              color: b.checked ? cs.primary : cs.outline,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                b.text.trim().isNotEmpty ? b.text : 'Checklist item',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: b.checked
                                      ? cs.onSurfaceVariant.withValues(alpha: 0.6)
                                      : cs.onSurfaceVariant,
                                  decoration: b.checked
                                      ? TextDecoration.lineThrough
                                      : null,
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
                ] else ...[
                  Text(
                    note.previewText.isNotEmpty
                        ? note.previewText
                        : 'No additional text',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),

                // Bottom row: Folder chip + Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note.folder,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatCardDate(note.updatedAt),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCardDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year) {
      return DateFormat('MMM d').format(dt);
    }
    return DateFormat('MMM d, yyyy').format(dt);
  }
}
