import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';
import 'device_channel.dart';
import 'error_log.dart';
import 'local_store.dart';

/// Builds the paste-ready diagnostics block for Profile > Help >
/// "Copy diagnostics". Never throws; unknown values render as "unknown".
Future<String> buildDiagnosticsText({
  required AppState app,
  required RoutineState routine,
  required NotesState notes,
  required BuildContext context,
}) async {
  String locale = 'unknown';
  String scale = 'unknown';
  try {
    locale = View.of(context).platformDispatcher.locale.toString();
    scale = MediaQuery.textScalerOf(context).toString();
  } catch (_) {}

  String version = 'unknown';
  String buildNo = '';
  try {
    final info = await PackageInfo.fromPlatform();
    version = info.version;
    buildNo = info.buildNumber;
  } catch (_) {}

  String api = 'unknown';
  String maker = 'unknown';
  String model = 'unknown';
  try {
    final di = await DeviceChannel.getDeviceInfo();
    if (di != null) {
      api = '${di['apiLevel'] ?? 'unknown'}';
      maker = '${di['manufacturer'] ?? 'unknown'}';
      model = '${di['model'] ?? 'unknown'}';
    }
  } catch (_) {}

  String tzId = 'unknown';
  try {
    tzId = (LocalStore.instance.load('tz_id') as String?) ??
        await DeviceChannel.getTimeZoneId() ??
        'unknown';
  } catch (_) {}

  String notif = 'unknown';
  try {
    final v = await DeviceChannel.areNotificationsEnabled();
    if (v != null) notif = v ? 'enabled' : 'disabled';
  } catch (_) {}

  String exact = 'unknown';
  try {
    final v = await DeviceChannel.canScheduleExactAlarms();
    if (v != null) exact = v ? 'allowed' : 'denied';
  } catch (_) {}

  String battery = 'unknown';
  try {
    final v = await DeviceChannel.isIgnoringBatteryOptimizations();
    if (v != null) {
      battery = v ? 'ignored (unrestricted)' : 'enforced';
    }
  } catch (_) {}

  String vibrator = 'unknown';
  try {
    final v = await DeviceChannel.hasVibrator();
    if (v != null) vibrator = v ? 'present' : 'absent';
  } catch (_) {}

  String touchHaptics = 'unknown';
  try {
    final v = await DeviceChannel.isTouchHapticsEnabled();
    if (v != null) touchHaptics = v ? 'on' : 'off';
  } catch (_) {}

  String tick = 'unknown';
  try {
    final v = await DeviceChannel.supportsSelectionTick();
    if (v != null) tick = v ? 'supported' : 'fallback to tap';
  } catch (_) {}

  int pending = 0;
  try {
    pending = app.tasks.where((t) => t.status.name == 'pending').length;
  } catch (_) {}
  final buf = StringBuffer()
    ..writeln('Uniro diagnostics')
    ..writeln('App: $version+$buildNo')
    ..writeln('Android API: $api')
    ..writeln('Device: $maker $model')
    ..writeln('Locale: $locale')
    ..writeln('Timezone: $tzId')
    ..writeln('Text scale: $scale')
    ..writeln('Notifications: $notif')
    ..writeln('Exact alarms: $exact')
    ..writeln('Battery optimization: $battery')
    ..writeln('Vibrator: $vibrator')
    ..writeln('Touch haptics: $touchHaptics')
    ..writeln('Selection tick: $tick')
    ..writeln(
        'Tasks: ${app.tasks.length} (pending $pending), '
        'Classes: ${routine.slots.length}, Notes: ${notes.allNotes.length}')
    ..writeln('Errors (last ${ErrorLog.entries.length}):');
  if (ErrorLog.entries.isEmpty) {
    buf.writeln('(none)');
  } else {
    for (final e in ErrorLog.entries) {
      buf.writeln('[${e['t'] ?? '?'}] (${e['ctx'] ?? 'app'}) ${e['msg'] ?? ''}');
      final st = (e['stack'] ?? '').trim();
      if (st.isNotEmpty) {
        final lines = st.split('\n').take(4).join('\n');
        buf.writeln('  $lines');
      }
    }
  }
  return buf.toString();
}
