import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../theme/app_colors.dart';

/// Attended / Missed toggle button used in the class action sheet.
class AttendanceMarkButton extends StatelessWidget {
  const AttendanceMarkButton({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: () {
        PremiumHaptics.tap();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? c.navActiveBg : c.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? c.navActiveBg : c.border,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: active ? c.navActiveText : c.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? c.navActiveText : c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
