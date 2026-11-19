import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/haptics.dart';
import '../../../models/settings.dart';
import '../../../state/app_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';

class ThemeSettingsCard extends StatelessWidget {
  const ThemeSettingsCard({super.key});

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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
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
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
