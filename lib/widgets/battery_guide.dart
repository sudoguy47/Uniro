import 'package:flutter/material.dart';
import '../domain/haptics.dart';

import '../app/app_shell.dart';
import '../services/device_channel.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Manufacturer-specific first line for the battery guide. [maker] is
/// Build.MANUFACTURER (lowercased before matching).
String batteryFirstLine(String maker) {
  final m = maker.toLowerCase();
  if (m.contains('realme')) {
    return 'Realme: Settings → Battery → App battery management → Uniro → Allow background activity.';
  }
  if (m.contains('oppo') || m.contains('oneplus')) {
    return 'Oppo / OnePlus: Settings → Battery → App battery management → Uniro → Allow background activity.';
  }
  if (m.contains('xiaomi') ||
      m.contains('redmi') ||
      m.contains('poco')) {
    return 'Xiaomi / MIUI / HyperOS: Settings → Battery → App battery saver → Uniro → No restrictions, and turn on Autostart.';
  }
  if (m.contains('vivo') || m.contains('iqoo')) {
    return 'Vivo: Settings → Battery → Background power consumption → Uniro → Allow, and enable Autostart.';
  }
  if (m.contains('samsung')) {
    return 'Samsung: Settings → Battery → Background usage limits → Never auto sleeping apps → add Uniro.';
  }
  if (m.contains('huawei') || m.contains('honor')) {
    return 'Huawei: Settings → Battery → App launch → Uniro → Manage manually → allow all.';
  }
  return 'Your phone may kill background apps: allow Uniro to run in the background.';
}

/// One-time hint bookkeeping. Shown once after the first reminder/class
/// creation, never on first launch, never again after dismissal.
class BatteryHint {
  static const _dismissedKey = 'battery_hint_dismissed';

  static bool get isDismissed =>
      LocalStore.instance.load(_dismissedKey) == true;

  static void markDismissed() {
    try {
      LocalStore.instance.save(_dismissedKey, true);
    } catch (_) {}
  }

  /// Call right after a task-with-reminder or class-with-reminder is saved.
  /// Shows a dismissible hint once; records dismissal immediately so it
  /// never repeats. Never throws.
  static void noteReminderCreated() {
    try {
      if (isDismissed) return;
      markDismissed();
      // Capture the messenger synchronously; the delayed show below must
      // not touch BuildContext across the async gap.
      ScaffoldMessengerState? messenger;
      try {
        final ctx = AppShell.shellKey.currentContext;
        if (ctx != null) messenger = ScaffoldMessenger.maybeOf(ctx);
      } catch (_) {}
      final captured = messenger;
      if (captured == null) return;
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        try {
          captured.showSnackBar(
            SnackBar(
              content: const Text(
                  'Reminders not arriving? See battery tips in Profile.'),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'View tips',
                onPressed: () => AppShell.openTab(AppTab.profile),
              ),
            ),
          );
        } catch (_) {}
      });
    } catch (_) {}
  }
}

/// Expandable "Reminders not arriving?" guide for Profile > Notifications.
/// Shows live status, a 3-step fix list, settings buttons, and a 1-minute
/// test reminder. Never throws.
class BatteryGuideCard extends StatefulWidget {
  const BatteryGuideCard({super.key});

  @override
  State<BatteryGuideCard> createState() => _BatteryGuideCardState();
}

class _BatteryGuideCardState extends State<BatteryGuideCard> {
  bool _open = false;
  bool? _notif;
  bool? _exact;
  bool? _battery;
  String _maker = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final di = await DeviceChannel.getDeviceInfo();
      final n = await DeviceChannel.areNotificationsEnabled();
      final e = await DeviceChannel.canScheduleExactAlarms();
      final b = await DeviceChannel.isIgnoringBatteryOptimizations();
      if (!mounted) return;
      setState(() {
        _maker = '${di?['manufacturer'] ?? ''}';
        _notif = n;
        _exact = e;
        _battery = b;
      });
    } catch (_) {}
  }

  Future<void> _testReminder() async {
    if (_testing) return;
    setState(() => _testing = true);
    try {
      final ok = await NotificationService.instance.scheduleTestReminder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Test reminder set — lock the screen and wait 1 minute.'
              : "Couldn't schedule the test reminder."),
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  String _statusText(String label, bool? v, String on, String off) {
    if (v == null) return '$label: unknown';
    return '$label: ${v ? on : off}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            PremiumHaptics.select();
            setState(() => _open = !_open);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Reminders not arriving?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          Text(
            _statusText('Notifications', _notif, 'on', 'off'),
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          Text(
            _statusText('Exact alarms', _exact, 'allowed', 'not allowed'),
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          Text(
            _statusText('Battery restriction', _battery, 'off (good)',
                'on (may block reminders)'),
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            batteryFirstLine(_maker),
            style: TextStyle(fontSize: 13, color: c.textPrimary),
          ),
          const SizedBox(height: 4),
          Text('1. Set battery usage to Unrestricted / No restrictions.',
              style: TextStyle(fontSize: 13, color: c.textPrimary)),
          Text('2. Allow Autostart / background activity for Uniro.',
              style: TextStyle(fontSize: 13, color: c.textPrimary)),
          Text('3. Lock Uniro in the recents screen if your phone offers it.',
              style: TextStyle(fontSize: 13, color: c.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    DeviceChannel.openBatteryOptimizationSettings();
                  },
                  child: const Text('Open battery settings'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    DeviceChannel.openAppSettings();
                  },
                  child: const Text('Open app settings'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _testing ? null : _testReminder,
              child: Text(
                  _testing ? 'Setting…' : 'Test reminder in 1 minute'),
            ),
          ),
        ],
      ],
    );
  }
}
