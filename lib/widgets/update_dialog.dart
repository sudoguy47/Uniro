import 'package:flutter/material.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';

/// Bottom sheet shown when a newer GitHub release is detected.
///
/// States: idle (Update Now / Later) -> downloading (progress + percent,
/// buttons disabled) -> installing (hands the APK to the system installer).
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.updateInfo});

  final UpdateInfo updateInfo;

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _downloading = true;
      _progress = 0;
      _error = null;
    });

    final apkPath = await UpdateService.downloadApk(
      widget.updateInfo.downloadUrl,
      (progress) {
        if (mounted) setState(() => _progress = progress);
      },
    );

    if (!mounted) return;

    if (apkPath == null) {
      setState(() {
        _downloading = false;
        _error = 'Download failed. Check your connection and try again.';
      });
      return;
    }

    setState(() => _downloading = false);
    await UpdateService.installApk(apkPath);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final info = widget.updateInfo;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Update Available!',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Version transition chip
          Row(
            children: [
              _VersionChip(
                label: 'v${info.currentVersion}',
                bg: c.inputBg,
                fg: c.textSecondary,
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: c.textTertiary),
              _VersionChip(
                label: 'v${info.latestVersion}',
                bg: c.accentLight,
                fg: c.accentDark,
              ),
              if (info.formattedSize.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  info.formattedSize,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Release notes / changelog
          if (info.releaseNotes.trim().isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.borderLight),
              ),
              child: SingleChildScrollView(
                child: Text(
                  info.releaseNotes.trim(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.45,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ),

          // Progress area (hidden until download starts)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _downloading
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: c.inputBg,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Downloading... ${(_progress * 100).round()}%',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.overdue,
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              Expanded(
                child: TextButton(
                  // Allow dismissing while downloading? No — keep it simple,
                  // but a failed download must be re-activatable.
                  onPressed: _downloading ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: c.textSecondary,
                    disabledForegroundColor: c.textTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: c.border),
                    ),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextButton(
                  onPressed: _downloading ? null : _startUpdate,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    backgroundColor: _downloading ? c.accent.withValues(alpha: 0.55) : c.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _downloading
                        ? '${(_progress * 100).round()}%'
                        : 'Update Now',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Convenience helper to show the sheet from anywhere with a BuildContext.
void showUpdateSheet(BuildContext context, UpdateInfo info) {
  showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).extension<AppColors>()!.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => UpdateDialog(updateInfo: info),
  );
}
