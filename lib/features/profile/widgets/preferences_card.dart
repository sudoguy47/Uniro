import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/haptics.dart';
import '../../../models/settings.dart';
import '../../../services/notification_service.dart';
import '../../../state/app_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/battery_guide.dart';
import '../../../widgets/ui_kit.dart';

/// Grouped preferences: theme, notifications master switch, reminder
/// lead times, and the battery guide. Typographic rows only — no
/// colored icon tiles; controls sit on the trailing edge.
class PreferencesCard extends StatelessWidget {
  const PreferencesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final s = context.select((AppState app) => app.settings);

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Theme
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'App Theme',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.theme.name[0].toUpperCase() + s.theme.name.substring(1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
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
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: AppTheme.fast,
                            curve: Curves.easeOutCubic,
                            height: 32,
                            decoration: BoxDecoration(
                              color: active ? c.navActiveBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              label,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: active ? c.navActiveText : c.textSecondary,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

          // Notifications master switch
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        s.notificationsEnabled
                            ? 'Device alerts & reminders'
                            : 'All reminders are off',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
          ),

          // Reminder lead times (only while notifications are on)
          if (s.notificationsEnabled) ...[
            Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),
            _ReminderRow(
              title: 'Assignment & CT',
              value: s.assignmentReminderDays,
              onChanged: (v) {
                context
                    .read<AppState>()
                    .updateSettings(s.copyWith(assignmentReminderDays: v));
              },
            ),
            Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),
            _ReminderRow(
              title: 'Exam, Viva & Project',
              value: s.examReminderDays,
              onChanged: (v) {
                context
                    .read<AppState>()
                    .updateSettings(s.copyWith(examReminderDays: v));
              },
            ),
            Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

            // Reliable alarms
            InkWell(
              onTap: () {
                PremiumHaptics.tap();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: c.cardBg,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: c.borderLight,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const BatteryGuideCard(),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reliable alarms & battery guide',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 18, color: c.textTertiary),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact reminder lead-time row: label left, stepper right.
class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StepperControl(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
