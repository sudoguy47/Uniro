import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/responsive.dart';
import '../../../domain/haptics.dart';
import '../../../services/diagnostics.dart';
import '../../../services/error_log.dart';
import '../../../services/support_links.dart';
import '../../../state/app_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';

/// Profile > Help: copy-paste diagnostics for testers, plus clearing the
/// local error log. Everything stays on-device; nothing is uploaded.
class HelpCard extends StatefulWidget {
  const HelpCard({super.key});

  @override
  State<HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<HelpCard> {
  bool _busy = false;
  bool _copied = false;

  Future<void> _copyDiagnostics() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!mounted) return;
      late final String text;
      try {
        text = await buildDiagnosticsText(
          app: context.read<AppState>(),
          routine: context.read<RoutineState>(),
          notes: context.read<NotesState>(),
          context: context,
        );
      } catch (_) {
        if (!mounted) return;
        AppNotification.error(context, "Couldn't build diagnostics.");
        return;
      }
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {
        if (!mounted) return;
        AppNotification.error(context, "Couldn't copy to clipboard.");
        return;
      }
      if (!mounted) return;
      PremiumHaptics.confirm();
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });

      AppNotification.success(context, 'Diagnostics copied! Opening Telegram…');
      // Automatically pop up / open Telegram profile so the user can send diagnostics
      await openTelegramSupport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearLogs() async {
    await ErrorLog.clear();
    if (!mounted) return;
    AppNotification.info(context, 'Error log cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  context.isCompact ? 'Diagnostics' : 'Help & Diagnostics',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: _clearLogs,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Clear logs',
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Something broken? Copy diagnostics and send them to developer support.',
            style: TextStyle(
                fontSize: 13, color: c.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _busy ? null : _copyDiagnostics,
              icon: Icon(
                _copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                size: 18,
              ),
              label: Text(
                _copied
                    ? 'Copied to clipboard!'
                    : _busy
                        ? 'Building diagnostics…'
                        : (context.isCompact
                            ? 'Diagnostics & Support'
                            : 'Copy Diagnostics & Open Telegram'),
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    _copied ? const Color(0xFF2E7D32) : c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: c.border),
          const SizedBox(height: 12),
          Text(
            'Support & Developer',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          // Telegram support link
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openTelegramSupport,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.send_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telegram Support',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            '@Hold_on47',
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded,
                        size: 16, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // GitHub profile link
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: openGitHubProfile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: c.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.code_rounded, size: 18, color: c.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GitHub Profile',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          Text(
                            'github.com/sudoguy47',
                            style: TextStyle(
                                fontSize: 12, color: c.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.open_in_new_rounded,
                        size: 16, color: c.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
