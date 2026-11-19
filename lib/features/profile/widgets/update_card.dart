import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../services/update_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/update_dialog.dart';

/// App updates via GitHub Releases: installed version, manual check,
/// "up to date" confirmation, and the same update dialog as startup.
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    installedVersion().then((v) {
      if (mounted && v.isNotEmpty) setState(() => _version = v);
    });
  }

  Future<void> _manualCheck() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final update = await checkForUpdate(force: true);
      if (!mounted) return;
      if (update == null) {
        AppNotification.info(context, 'You are up to date.');
      } else {
        await showUpdateDialog(context, update);
      }
    } on UpdateException catch (e) {
      if (mounted) AppNotification.warning(context, e.message);
    } catch (_) {
      if (mounted) {
        AppNotification.warning(
          context,
          'Could not check for updates. Try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
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
      child: LayoutBuilder(builder: (context, cons) {
        final btnW = (cons.maxWidth * 0.44).clamp(110.0, 190.0);
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App updates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _version.isEmpty
                        ? 'Check for new releases'
                        : 'Installed v$_version',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: btnW,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _checking
                      ? null
                      : () {
                          PremiumHaptics.select();
                          _manualCheck();
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                      _checking ? 'Checking…' : 'Check for updates'),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
