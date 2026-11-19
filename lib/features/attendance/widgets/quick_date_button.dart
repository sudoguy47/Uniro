import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class QuickDateButton extends StatelessWidget {
  const QuickDateButton({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? colors.accent : colors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? colors.accent : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
