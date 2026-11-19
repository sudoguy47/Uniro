import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../domain/haptics.dart';
import '../../../services/diagnostics.dart';
import '../../../services/error_log.dart';
import '../../../services/support_links.dart';
import '../../../state/app_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';

/// Modal bottom sheet for diagnostics, tester logs, and developer support links.
class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SupportSheet(),
    );
  }

  @override
  State<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<SupportSheet> {
  bool _busy = false;

  Future<void> _copyDiagnosticsAndOpenSupport() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = await buildDiagnosticsText(
        app: context.read<AppState>(),
        routine: context.read<RoutineState>(),
        notes: context.read<NotesState>(),
        context: context,
      );

      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      PremiumHaptics.confirm();
      AppNotification.success(context, 'Diagnostics copied! Opening Telegram…');
      await openTelegramSupport();
    } catch (_) {
      if (!mounted) return;
      AppNotification.error(context, "Couldn't build diagnostics.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearLogs() async {
    await ErrorLog.clear();
    if (!mounted) return;
    PremiumHaptics.confirm();
    AppNotification.info(context, 'Error logs cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: c.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.support_agent_rounded, color: c.accent, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Help & Developer Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _clearLogs,
                  child: Text(
                    'Clear logs',
                    style: TextStyle(fontSize: 12, color: c.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Encountering an issue or need assistance? You can copy device diagnostics and reach out directly to the developer.',
              style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Copy Diagnostics & Open Telegram button
            FilledButton.icon(
              onPressed: _busy ? null : _copyDiagnosticsAndOpenSupport,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(_busy
                  ? 'Generating…'
                  : 'Copy Diagnostics & Open Telegram'),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Links: Telegram Support + GitHub Profile
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PremiumHaptics.tap();
                      openTelegramSupport();
                    },
                    icon: Icon(Icons.send_rounded, size: 16, color: c.accent),
                    label: const Text('Telegram'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      PremiumHaptics.tap();
                      openGitHubProfile();
                    },
                    icon: Icon(Icons.code_rounded, size: 16, color: c.accent),
                    label: const Text('GitHub'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.textPrimary,
                      side: BorderSide(color: c.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
