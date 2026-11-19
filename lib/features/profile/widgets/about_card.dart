import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/haptics.dart';
import '../../../screens/courses_screen.dart';
import '../../../services/update_service.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';
import '../../../widgets/update_dialog.dart';
import '../../../features/onboarding/tour_guide.dart';
import 'support_sheet.dart';

/// Grouped About card: Courses management, Check for updates, and Developer Support.
class AboutCard extends StatefulWidget {
  const AboutCard({super.key});

  @override
  State<AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<AboutCard> {
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
    PremiumHaptics.tap();

    try {
      final update = await checkForUpdate(force: true);
      if (!mounted) return;
      if (update == null) {
        PremiumHaptics.confirm();
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
    final courseCount = context.select((RoutineState r) => r.courses.length);

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Manage Courses Row
          InkWell(
            onTap: () {
              PremiumHaptics.tap();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CoursesScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Courses',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '$courseCount course${courseCount == 1 ? '' : 's'} registered',
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
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

          // App Updates Row
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
                        'App Updates',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _version.isEmpty
                            ? 'Check for releases'
                            : 'Installed v$_version',
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
                TextButton(
                  onPressed: _checking ? null : _manualCheck,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: c.textSecondary,
                  ),
                  child: Text(
                    _checking ? 'Checking…' : 'Check',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

          // Help & Diagnostics Row
          InkWell(
            onTap: () {
              PremiumHaptics.tap();
              SupportSheet.show(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Help & Developer Support',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Error logs, diagnostics & support chat',
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
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, indent: 14, endIndent: 14, color: c.borderLight),

          // App Guide Row
          InkWell(
            onTap: () {
              PremiumHaptics.tap();
              showTourGuide(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'App Guide',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Take a tour of Uniro\'s features',
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
                  Icon(
                    Icons.play_circle_outline_rounded,
                    size: 20,
                    color: c.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
