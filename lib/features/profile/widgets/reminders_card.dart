import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/logger.dart';
import '../../../services/notification_service.dart';
import '../../../state/app_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/battery_guide.dart';
import '../../../widgets/ui_kit.dart';
import 'gallery_permission_tile.dart';

class RemindersCard extends StatelessWidget {
  const RemindersCard({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (!context.mounted) return;
      if (image != null) {
        final app = context.read<AppState>();
        app.updateSettings(app.settings.copyWith(avatarUri: image.path));
      }
    } on PlatformException catch (e) {
      AppLog.w('avatar picker notice', e);
      if (!context.mounted) return;
      AppNotification.error(context, "Couldn't open the photo picker.");
    } catch (e) {
      AppLog.w('avatar picker notice', e);
      if (!context.mounted) return;
      AppNotification.error(context, "Couldn't open the photo picker.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final s = context.select((AppState app) => app.settings);

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
                    final routine = context.read<RoutineState>();
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
                    onTap: () => _pickAvatar(context),
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
          const GalleryPermissionTile(),
          const Divider(height: 16),
          const BatteryGuideCard(),
        ],
      ),
    );
  }
}
