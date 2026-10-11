import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/settings.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../widgets/ui_kit.dart';

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
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (image != null && mounted) {
      final app = context.read<AppState>();
      app.updateSettings(app.settings.copyWith(avatarUri: image.path));
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
                              NotificationService.instance
                                  .requestPermissions()
                                  .then((granted) {
                                if (granted) {
                                  NotificationService.instance
                                      .rescheduleAll(appState.tasks);
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
                              HapticFeedback.selectionClick();
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
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
