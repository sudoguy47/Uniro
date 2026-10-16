import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/device_channel.dart';
import '../services/update_service.dart';
import '../theme/app_colors.dart';

bool _dialogOpen = false;

/// Shows the update dialog for [update], unless one is already open.
/// States: version info -> downloading (progress + cancel) -> verifying ->
/// installer (auto-opened) / install-permission / error (retry + browser).
/// Later/Skip behave as before. Never throws.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) async {
  if (_dialogOpen) return;
  _dialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => _UpdateDialogBody(update: update),
    );
  } catch (_) {
  } finally {
    _dialogOpen = false;
  }
}

enum _Phase {
  ready,
  downloading,
  verifying,
  openingInstaller,
  needPermission,
  installerOpened,
  error,
}

class _UpdateDialogBody extends StatefulWidget {
  const _UpdateDialogBody({required this.update});
  final AppUpdate update;

  @override
  State<_UpdateDialogBody> createState() => _UpdateDialogBodyState();
}

class _UpdateDialogBodyState extends State<_UpdateDialogBody> {
  _Phase _phase = _Phase.ready;
  int _received = 0;
  int? _total;
  String _error = '';
  File? _apk;
  bool _cancel = false;
  bool _busy = false;

  AppUpdate get _update => widget.update;

  Future<void> _downloadAndInstall() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _Phase.downloading;
      _received = 0;
      _total = null;
      _error = '';
      _cancel = false;
    });
    try {
      final file = await downloadUpdate(
        _update,
        onProgress: (r, t) {
          if (mounted) {
            setState(() {
              _received = r;
              _total = t;
            });
          }
        },
        isCancelled: () => _cancel,
      );
      if (!mounted) return;
      setState(() {
        _apk = file;
        _phase = _Phase.verifying;
      });
      final readiness = await checkInstallReadiness(file);
      if (!mounted) return;
      if (!readiness.ok) {
        setState(() {
          _phase = _Phase.error;
          _error = readiness.reason;
          _busy = false;
        });
        return;
      }
      setState(() => _phase = _Phase.openingInstaller);
      final res = await launchInstaller(file);
      if (!mounted) return;
      setState(() {
        _phase = res == 'needPermission'
            ? _Phase.needPermission
            : _Phase.installerOpened;
        _busy = false;
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      if (e.message == 'cancelled') {
        setState(() {
          _phase = _Phase.ready;
          _busy = false;
        });
        return;
      }
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Something went wrong. Try again.';
        _busy = false;
      });
    }
  }

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(
        Uri.parse(_update.apkUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('open apk link notice: $e');
    }
  }

  String _mb(int bytes) => (bytes / 1048576).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return AlertDialog(
      backgroundColor: c.cardBg,
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${_update.version} is ready.',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if (_update.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_update.notes.trim(),
                  style:
                      TextStyle(fontSize: 13, color: c.textSecondary)),
            ],
            const SizedBox(height: 12),
            _buildPhaseBody(c),
          ],
        ),
      ),
      actions: _buildActions(context, c),
    );
  }

  Widget _buildPhaseBody(AppColors c) {
    switch (_phase) {
      case _Phase.ready:
        return const Text('Downloads the APK in the app, verifies it, then opens '
            'the system installer. You confirm the install there.');
      case _Phase.downloading:
        final pct = _total != null && _total! > 0
            ? (_received / _total! * 100).toStringAsFixed(0)
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: pct == null ? null : _received / _total!,
            ),
            const SizedBox(height: 8),
            Text(
              pct == null
                  ? 'Downloaded ${_mb(_received)} MB…'
                  : 'Downloaded ${_mb(_received)} MB of ${_mb(_total!)} MB ($pct%)…',
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
          ],
        );
      case _Phase.verifying:
        return const Text('Checking the package before install…');
      case _Phase.openingInstaller:
        return const Text('Opening the system installer…');
      case _Phase.needPermission:
        return const Text('Android needs your permission first: allow '
            '"Install unknown apps" for Uniro, then come back and tap Install.');
      case _Phase.installerOpened:
        return const Text('Installer opened — confirm the install there. '
            'Your data is kept.');
      case _Phase.error:
        return Text(_error,
            style: TextStyle(fontSize: 13, color: c.textSecondary));
    }
  }

  List<Widget> _buildActions(BuildContext context, AppColors c) {
    switch (_phase) {
      case _Phase.ready:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              skipUpdateVersion(_update.tag);
              Navigator.pop(context);
            },
            child: const Text('Skip this version'),
          ),
          FilledButton(
            onPressed: _busy ? null : _downloadAndInstall,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Download'),
          ),
        ];
      case _Phase.downloading:
        return [
          TextButton(
            onPressed: () {
              _cancel = true;
            },
            child: const Text('Cancel'),
          ),
        ];
      case _Phase.verifying:
      case _Phase.openingInstaller:
        return const [SizedBox.shrink()];
      case _Phase.needPermission:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              await DeviceChannel.openInstallPermissionSettings();
              // Re-run verify + install after the user grants permission.
              if (mounted) _downloadAndInstallReuse();
            },
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open settings'),
          ),
        ];
      case _Phase.installerOpened:
        return [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ];
      case _Phase.error:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openInBrowser();
            },
            child: const Text('Browser instead'),
          ),
          FilledButton(
            onPressed: _busy ? null : _downloadAndInstall,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ];
    }
  }

  /// Reuses the already-downloaded APK: verify + install without
  /// re-downloading (used after granting install permission).
  Future<void> _downloadAndInstallReuse() async {
    final file = _apk;
    if (file == null) {
      await _downloadAndInstall();
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _Phase.verifying;
      _error = '';
    });
    try {
      final readiness = await checkInstallReadiness(file);
      if (!mounted) return;
      if (!readiness.ok) {
        setState(() {
          _phase = _Phase.error;
          _error = readiness.reason;
          _busy = false;
        });
        return;
      }
      setState(() => _phase = _Phase.openingInstaller);
      final res = await launchInstaller(file);
      if (!mounted) return;
      setState(() {
        _phase = res == 'needPermission'
            ? _Phase.needPermission
            : _Phase.installerOpened;
        _busy = false;
      });
    } on UpdateException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
        _busy = false;
      });
    }
  }
}
