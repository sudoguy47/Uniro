import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../theme/app_colors.dart';

/// Compact Active | Completed segmented toggle.
class DashboardViewToggle extends StatelessWidget {
  const DashboardViewToggle({
    super.key,
    required this.completed,
    required this.onChanged,
  });

  final bool completed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    Widget seg(String label, bool active, String value) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if ((value == 'completed') == completed) return;
            PremiumHaptics.select();
            onChanged(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            decoration: BoxDecoration(
              color: active ? c.navActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? c.navActiveText : c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            seg('Active', !completed, 'active'),
            seg('Completed', completed, 'completed'),
          ],
        ),
      ),
    );
  }
}
