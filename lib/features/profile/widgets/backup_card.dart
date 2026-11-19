import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../domain/haptics.dart';
import '../../../domain/sample_data.dart';
import '../../../services/backup_service.dart';
import '../../../services/local_store.dart';
import '../../../services/notification_service.dart';
import '../../../state/app_state.dart';
import '../../../state/attendance_state.dart';
import '../../../state/focus_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';

/// Data & Backup management card: Export Backup, Import Backup, and Example Data.
class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isTogglingExamples = false;

  Future<void> _exportBackup(BuildContext context) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    PremiumHaptics.tap();

    try {
      final bytes = await BackupService.buildBackupBytes();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'uniro_backup_$dateStr.json';

      String? savePath;
      try {
        savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Uniro Backup',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
          bytes: bytes,
        );
      } catch (_) {
        // Platform fallback below
      }

      // If saveFile didn't write to a chosen path, write to Downloads/Documents as fallback
      if (savePath == null) {
        Directory? targetDir;
        if (Platform.isAndroid) {
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            targetDir = downloadDir;
          } else {
            targetDir = await getExternalStorageDirectory();
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        if (targetDir != null && await targetDir.exists()) {
          final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
          await file.writeAsBytes(bytes, flush: true);
          savePath = file.path;
        }
      }

      if (!context.mounted) return;
      PremiumHaptics.confirm();
      if (savePath != null) {
        AppNotification.success(
          context,
          'Backup exported: $fileName',
        );
      } else {
        AppNotification.info(context, 'Backup export completed.');
      }
    } catch (e) {
      if (!context.mounted) return;
      AppNotification.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    if (_isImporting) return;
    setState(() => _isImporting = true);
    PremiumHaptics.tap();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;
      List<int>? rawBytes = picked.bytes;
      if (rawBytes == null && picked.path != null) {
        final f = File(picked.path!);
        if (await f.exists()) {
          rawBytes = await f.readAsBytes();
        }
      }

      if (rawBytes == null || rawBytes.isEmpty) {
        if (!context.mounted) return;
        AppNotification.warning(context, 'Selected file was empty or unreadable.');
        return;
      }

      final bytes = rawBytes is Uint8List ? rawBytes : Uint8List.fromList(rawBytes);

      // Validate & summarize before prompting
      final BackupSummary summary;
      try {
        summary = BackupService.summarizeBytes(bytes);
      } catch (e) {
        if (!context.mounted) return;
        AppNotification.error(context, e.toString());
        return;
      }

      if (!context.mounted) return;
      final confirmed = await _showImportConfirmationDialog(context, summary);
      if (confirmed != true || !context.mounted) return;

      // Proceed with restore & state reload
      final parsed = BackupService.parseBackup(utf8.decode(bytes));
      final restoreResult = await BackupService.restore(parsed);

      if (!context.mounted) return;
      final app = context.read<AppState>();
      final routine = context.read<RoutineState>();
      final notes = context.read<NotesState>();
      final attendance = context.read<AttendanceState>();
      final focus = context.read<FocusState>();

      await LocalStore.instance.init();
      app.loadFromStore();
      await routine.load();
      await notes.reloadFromDisk();
      await attendance.load();
      await focus.load();

      if (app.settings.notificationsEnabled) {
        NotificationService.instance.rearmAll(
          tasks: app.tasks,
          courses: routine.courses,
          slots: routine.slots,
          name: app.settings.name,
          enabled: true,
        );
      }

      if (!context.mounted) return;
      PremiumHaptics.confirm();
      AppNotification.success(
        context,
        'Import complete! Restored ${restoreResult.tasks} tasks, ${restoreResult.courses} courses, ${restoreResult.notes} notes.',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppNotification.error(context, 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<bool?> _showImportConfirmationDialog(
    BuildContext context,
    BackupSummary summary,
  ) {
    final c = Theme.of(context).extension<AppColors>()!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.restore_page_outlined, color: c.accent, size: 24),
            const SizedBox(width: 8),
            Text(
              'Restore Backup?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found valid Uniro backup. Existing data will be safely merged without duplicates.',
              style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.borderLight),
              ),
              child: Column(
                children: [
                  _statRow(c, 'Tasks', '${summary.tasks}'),
                  const SizedBox(height: 6),
                  _statRow(c, 'Courses', '${summary.courses}'),
                  const SizedBox(height: 6),
                  _statRow(c, 'Class Routine', '${summary.slots} slots'),
                  const SizedBox(height: 6),
                  _statRow(c, 'Notes', '${summary.notes}'),
                  const SizedBox(height: 6),
                  _statRow(c, 'Attendance', '${summary.attendance} records'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Merge & Restore'),
          ),
        ],
      ),
    );
  }

  Widget _statRow(AppColors c, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _toggleExamples() async {
    if (_isTogglingExamples) return;
    setState(() => _isTogglingExamples = true);
    try {
      final app = context.read<AppState>();
      final routine = context.read<RoutineState>();
      final notes = context.read<NotesState>();
      if (hasExampleData(app, routine, notes)) {
        PremiumHaptics.confirm();
        await hideExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        AppNotification.info(context, 'Example data hidden.');
      } else {
        PremiumHaptics.confirm();
        await seedExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        AppNotification.success(context, 'Example data loaded.');
      }
    } finally {
      if (mounted) setState(() => _isTogglingExamples = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final showingExamples = hasExampleData(
      context.watch<AppState>(),
      context.watch<RoutineState>(),
      context.watch<NotesState>(),
    );

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _NavRow(
            title: 'Export Backup',
            subtitle: _isExporting
                ? 'Generating backup file…'
                : 'Save all tasks, courses, notes & routine',
            busy: _isExporting,
            onTap: _isExporting ? null : () => _exportBackup(context),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),
          _NavRow(
            title: 'Import Backup',
            subtitle: _isImporting
                ? 'Reading backup file…'
                : 'Restore or merge a backup JSON file',
            busy: _isImporting,
            onTap: _isImporting ? null : () => _importBackup(context),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

          // Example Data Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Example Data',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        showingExamples
                            ? 'Sample tasks, classes & notes active'
                            : 'Load sample content to explore Uniro',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _isTogglingExamples ? null : _toggleExamples,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: c.textSecondary,
                  ),
                  child: Text(
                    _isTogglingExamples
                        ? '…'
                        : showingExamples
                            ? 'Hide'
                            : 'Load',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Typographic navigation row for the grouped list: title + subtitle,
/// busy spinner or chevron on the trailing edge.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (busy)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: c.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}
