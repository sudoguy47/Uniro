import 'package:flutter/material.dart';
import '../../../services/device_channel.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';

/// Profile > Notifications > gallery permission status + request.
/// Sits beside the notification toggle so photo access is managed in the
/// same place. Refreshes on resume (user may grant in system settings).
class GalleryPermissionTile extends StatefulWidget {
  const GalleryPermissionTile({super.key});

  @override
  State<GalleryPermissionTile> createState() => _GalleryPermissionTileState();
}

class _GalleryPermissionTileState extends State<GalleryPermissionTile>
    with WidgetsBindingObserver {
  String _status = 'unknown';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final s = await DeviceChannel.getStoragePermissionStatus();
      if (mounted) setState(() => _status = s);
    } catch (_) {}
  }

  Future<void> _onAction() async {
    if (_busy) return;
    if (_status == 'permanentlyDenied') {
      await DeviceChannel.openAppSettings();
      return;
    }
    setState(() => _busy = true);
    try {
      final s = await DeviceChannel.requestStoragePermission();
      if (!mounted) return;
      setState(() => _status = s);
      if (s == 'granted') {
        AppNotification.success(context, 'Gallery access allowed.');
      } else if (s == 'permanentlyDenied') {
        AppNotification.warning(context, 'Gallery blocked — enable it in app settings.');
      } else {
        AppNotification.error(context, "Couldn't get gallery access.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final granted = _status == 'granted';
    final blocked = _status == 'permanentlyDenied';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gallery permission',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: c.textPrimary,
                ),
              ),
              Text(
                granted
                    ? 'Allowed'
                    : blocked
                        ? 'Blocked — enable in settings'
                        : _status == 'denied'
                            ? 'Not allowed'
                            : 'Checking…',
                style: TextStyle(fontSize: 12, color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (!granted)
          TextButton(
            onPressed: _busy ? null : _onAction,
            child: Text(blocked
                ? 'Open settings'
                : _busy
                    ? 'Asking…'
                    : 'Allow'),
          )
        else
          Icon(Icons.check_circle_outline,
              size: 20, color: c.textSecondary),
      ],
    );
  }
}
