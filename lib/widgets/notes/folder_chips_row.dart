import 'package:flutter/material.dart';
import '../../domain/haptics.dart';
import 'package:provider/provider.dart';
import '../../state/notes_state.dart';

class FolderChipsRow extends StatelessWidget {
  const FolderChipsRow({super.key});

  void _showAddFolderDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<NotesState>().addFolder(name);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showFolderOptionsSheet(BuildContext context, String folderName) {
    PremiumHaptics.confirm();
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
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Folder'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _showRenameFolderDialog(context, folderName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Folder', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmDeleteFolder(context, folderName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameFolderDialog(BuildContext context, String oldName) {
    final controller = TextEditingController(text: oldName);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'New folder name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != oldName) {
                context.read<NotesState>().renameFolder(oldName, newName);
              }
              Navigator.pop(dialogCtx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, String folderName) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Delete "$folderName"?'),
        content: const Text(
          'Notes inside this folder will be moved to Personal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<NotesState>().deleteFolder(folderName);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.select<NotesState, List<String>>((s) => s.folders);
    final counts = context.select<NotesState, Map<String, int>>((s) => s.folderCounts);
    final activeFolder = context.select<NotesState, String>((s) => s.activeFolder);
    final cs = Theme.of(context).colorScheme;

    final allChips = ['All', 'Pinned', ...folders];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        itemCount: allChips.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == allChips.length) {
            // "+ Add" chip
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _showAddFolderDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Folder',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final name = allChips[index];
          final isSelected = activeFolder == name;
          final count = counts[name] ?? 0;
          final isCustomFolder = name != 'All' && name != 'Pinned';

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              PremiumHaptics.select();
              context.read<NotesState>().setActiveFolder(name);
            },
            onLongPress: isCustomFolder
                ? () => _showFolderOptionsSheet(context, name)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? Colors.transparent : cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.onPrimary.withValues(alpha: 0.22)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
