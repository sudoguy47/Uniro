import 'package:flutter/material.dart';

import '../services/support_links.dart';
import '../theme/app_colors.dart';

bool _dialogOpen = false;

/// "Need a hand?" follow-up shown after Profile > Help > Copy
/// diagnostics succeeds. Confirms the copy, nudges the user to review
/// the text before sharing, and offers support links (only the ones
/// actually configured in [support_links.dart]). Dismiss via Close,
/// back button, or tapping outside. Never throws.
Future<void> showSupportDialog(BuildContext context) async {
  if (_dialogOpen) return;
  _dialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => const _SupportDialogBody(),
    );
  } catch (_) {
  } finally {
    _dialogOpen = false;
  }
}

class _SupportDialogBody extends StatelessWidget {
  const _SupportDialogBody();

  /// Guards with a timeout: a stalled platform channel must never
  /// leave the user without feedback.
  Future<void> _open(
      BuildContext context, Future<bool> Function() open) async {
    var ok = false;
    try {
      ok = await open().timeout(const Duration(seconds: 3));
    } catch (_) {
      ok = false;
    }
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the link.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return AlertDialog(
      backgroundColor: c.cardBg,
      title: Text('Need a hand?',
          style: TextStyle(color: c.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Diagnostics copied to your clipboard. Give them a quick '
              'review before sharing — they describe your device and app state.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            if (hasTelegramSupport) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _open(context, openTelegramSupport),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Telegram Support'),
              ),
            ],
            if (hasGitHubProfile) ...[
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: () => _open(context, openGitHubProfile),
                  icon: Icon(
                    Icons.code_rounded,
                    size: 16,
                    color: c.textSecondary,
                  ),
                  label: Text(
                    'GitHub Profile',
                    style:
                        TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: c.textSecondary)),
        ),
      ],
    );
  }
}
