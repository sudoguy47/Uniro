import 'package:flutter/material.dart';
import '../../../core/responsive.dart';
import '../../../theme/app_colors.dart';
import '../widgets/about_card.dart';
import '../widgets/backup_card.dart';
import '../widgets/preferences_card.dart';
import '../widgets/profile_header_card.dart';

/// Settings & profile tab — compact, typographic, everything local to the
/// device. Sections are quiet caps labels; rows carry no colored icon
/// tiles, so the eye reads one grouped list per concern.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Widget _buildSectionHeader(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: c.textTertiary,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings & Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your account, preferences and data.',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textTertiary,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 12),

              // Identity
              const ProfileHeaderCard(),
              const SizedBox(height: 16),

              // Preferences Section (Theme, Notifications, Reminders Lead Time)
              _buildSectionHeader(c, 'Preferences'),
              const PreferencesCard(),
              const SizedBox(height: 16),

              // Data & Backup Section (Export, Import, Example Data)
              _buildSectionHeader(c, 'Data & Backup'),
              const BackupCard(),
              const SizedBox(height: 16),

              // About & Support Section (Courses, App Updates, Developer Help)
              _buildSectionHeader(c, 'About & Support'),
              const AboutCard(),
              const SizedBox(height: 18),

              // Credit footer
              Center(
                child: Container(
                  width: 48,
                  height: 1,
                  color: c.borderLight,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Made with ❤️ by Sreyas',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.textTertiary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              SizedBox(height: AppInsets.bottomNavClearance(context)),
            ],
          ),
        ),
      ),
    );
  }
}
