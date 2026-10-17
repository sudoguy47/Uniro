import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/haptics.dart';
import '../domain/sample_data.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/update_dialog.dart';
import '../models/settings.dart';
import '../services/diagnostics.dart';
import '../services/device_channel.dart';
import '../services/error_log.dart';
import '../services/update_service.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';
import '../widgets/battery_guide.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/support_links.dart';
import '../widgets/ui_kit.dart';
import 'courses_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (image != null) {
        final app = context.read<AppState>();
        app.updateSettings(app.settings.copyWith(avatarUri: image.path));
      }
    } on PlatformException catch (e) {
      debugPrint('avatar picker notice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the photo picker.")),
      );
    } catch (e) {
      debugPrint('avatar picker notice: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the photo picker.")),
      );
    }
  }

  void _editNameDialog(BuildContext context, UserSettings settings) {
    final controller = TextEditingController(text: settings.name);
    final c = Theme.of(context).extension<AppColors>()!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: Text('Edit Name', style: TextStyle(color: c.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: c.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                context
                    .read<AppState>()
                    .updateSettings(settings.copyWith(name: newName));
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final s = context.select((AppState app) => app.settings);

    return Scaffold(
      backgroundColor: c.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          UserAvatar(
                            avatarUri: s.avatarUri,
                            name: s.name,
                            size: 80,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: c.navActiveBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.camera_alt,
                                  size: 14, color: c.navActiveText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _editNameDialog(context, s),
                      child: SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: c.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.edit_outlined,
                                  size: 16, color: c.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stored on this device',
                      style: TextStyle(fontSize: 13, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reminders Settings Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure default notification timing for tasks.',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Assignment & CT',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        StepperControl(
                          value: s.assignmentReminderDays,
                          onChanged: (v) {
                            context.read<AppState>().updateSettings(
                                s.copyWith(assignmentReminderDays: v));
                          },
                        ),
                      ],
                    ),
                    Divider(height: 32, color: c.borderLight),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Exam, Viva & Project',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        StepperControl(
                          value: s.examReminderDays,
                          onChanged: (v) {
                            context.read<AppState>().updateSettings(
                                s.copyWith(examReminderDays: v));
                          },
                        ),
                      ],
                    ),
                    Divider(height: 32, color: c.borderLight),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Notifications Enabled',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                'Receive device reminders',
                                style: TextStyle(
                                    fontSize: 13, color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TinySwitch(
                          value: s.notificationsEnabled,
                          onChanged: (enabled) {
                            final appState = context.read<AppState>();
                            appState.updateSettings(
                                s.copyWith(notificationsEnabled: enabled));
                            if (!enabled) {
                              NotificationService.instance.cancelAll();
                            } else {
                              // Explicit user action: prompt for permission,
                              // then (re)arm everything if granted.
                              final routine =
                                  context.read<RoutineState>();
                              NotificationService.instance
                                  .requestPermissions()
                                  .then((granted) {
                                if (granted) {
                                  NotificationService.instance.rearmAll(
                                    tasks: appState.tasks,
                                    courses: routine.courses,
                                    slots: routine.slots,
                                    name: appState.settings.name,
                                    enabled: true,
                                  );
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Divider(height: 24, color: c.borderLight),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gallery & Storage Access',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: c.textPrimary,
                                ),
                              ),
                              Text(
                                'Profile photo & avatar picker',
                                style: TextStyle(
                                    fontSize: 13, color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _pickAvatar,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: c.cardBgRaised,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: c.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.photo_library_outlined,
                                        size: 16, color: c.accent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Choose Photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: c.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const _GalleryPermissionTile(),
                    const Divider(height: 16),
                    const BatteryGuideCard(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Courses Card
              _CoursesRow(),
              const SizedBox(height: 16),

              // App updates (GitHub Releases, fully offline-safe).
              const _UpdateCard(),
              const SizedBox(height: 16),

              // Example data: load the tour bundle anytime, hide it again.
              const _ExamplesCard(),
              const SizedBox(height: 16),

              // Theme Settings Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: AppThemeMode.values.map((mode) {
                        final active = s.theme == mode;
                        final label =
                            mode.name[0].toUpperCase() + mode.name.substring(1);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              PremiumHaptics.select();
                              context
                                  .read<AppState>()
                                  .updateSettings(s.copyWith(theme: mode));
                            },
                            child: AnimatedContainer(
                              duration: AppTheme.fast,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 40,
                              decoration: BoxDecoration(
                                color: active ? c.accentLight : c.inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: active ? c.accent : c.border,
                                  width: active ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: active ? c.accent : c.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Help: diagnostics for testers + local log clearing.
              const _HelpCard(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

/// App updates via GitHub Releases: installed version, manual check,
/// "up to date" confirmation, and the same update dialog as startup.
class _UpdateCard extends StatefulWidget {
  const _UpdateCard();

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
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
      final update = await checkForUpdate();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You are up to date.')));
      } else {
        await showUpdateDialog(context, update);
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

/// Profile > Help: copy-paste diagnostics for testers, plus clearing the
/// local error log. Everything stays on-device; nothing is uploaded.
class _HelpCard extends StatefulWidget {
  const _HelpCard();

  @override
  State<_HelpCard> createState() => _HelpCardState();
}

class _HelpCardState extends State<_HelpCard> {
  bool _busy = false;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't build diagnostics.")),
        );
        return;
      }
      try {
        await Clipboard.setData(ClipboardData(text: text));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't copy to clipboard.")),
        );
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics copied! Opening Telegram…'),
          duration: Duration(seconds: 3),
        ),
      );
      // Automatically pop up / open Telegram profile so the user can send diagnostics
      await openTelegramSupport();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearLogs() async {
    await ErrorLog.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error log cleared.')),
    );
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
          Text(
            'Help',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: c.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Something broken? Copy diagnostics and send them to support.',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _copyDiagnostics,
                  child: Text(_busy ? 'Copying…' : 'Copy diagnostics'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: _clearLogs,
                  child: const Text('Clear logs'),
                ),
              ),
            ],
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

/// Profile > Notifications > gallery permission status + request.
/// Sits beside the notification toggle so photo access is managed in the
/// same place. Refreshes on resume (user may grant in system settings).
class _GalleryPermissionTile extends StatefulWidget {
  const _GalleryPermissionTile();

  @override
  State<_GalleryPermissionTile> createState() => _GalleryPermissionTileState();
}

class _GalleryPermissionTileState extends State<_GalleryPermissionTile>
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s == 'granted'
              ? 'Gallery access allowed.'
              : s == 'permanentlyDenied'
                  ? 'Gallery blocked — enable it in app settings.'
                  : "Couldn't get gallery access."),
          duration: const Duration(seconds: 4),
        ),
      );
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

/// Profile > Example data: load the tour bundle on demand, or hide it
/// again. Toggles its label based on whether samples are present.
class _ExamplesCard extends StatefulWidget {
  const _ExamplesCard();

  @override
  State<_ExamplesCard> createState() => _ExamplesCardState();
}

class _ExamplesCardState extends State<_ExamplesCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      final routine = context.read<RoutineState>();
      final notes = context.read<NotesState>();
      if (hasExampleData(app, routine, notes)) {
        PremiumHaptics.confirm();
        await hideExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Example data hidden.')),
        );
      } else {
        PremiumHaptics.confirm();
        await seedExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Example data loaded.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final showing = hasExampleData(
      context.watch<AppState>(),
      context.watch<RoutineState>(),
      context.watch<NotesState>(),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;
          final button = FilledButton(
            onPressed: _busy ? null : _toggle,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_busy
                ? 'Working…'
                : showing
                    ? 'Hide examples'
                    : 'Show examples'),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example data',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showing
                      ? 'Sample tasks, classes and notes are visible'
                      : 'Explore the app with sample content',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: button,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example data',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showing
                          ? 'Sample tasks, classes and notes are visible'
                          : 'Explore the app with sample content',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}

/// Profile > Courses navigation row (count + chevron).
class _CoursesRow extends StatelessWidget {  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final count = context.select((RoutineState r) => r.courses.length);
    return GestureDetector(
      onTap: () {
        PremiumHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CoursesScreen()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count course${count == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
