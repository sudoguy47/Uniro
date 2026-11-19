import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';

const focusPresets = [25, 45, 60];

class FocusPresetsRow extends StatelessWidget {
  const FocusPresetsRow({
    super.key,
    required this.st,
    required this.locked,
    required this.onOpenCustomize,
  });

  final FocusState st;
  final bool locked;
  final VoidCallback onOpenCustomize;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    Widget chip(String label, bool on, VoidCallback? onTap) {
      return GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                PremiumHaptics.select();
                onTap();
              },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: on
                ? c.accent.withValues(alpha: 0.16)
                : c.cardBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: on ? c.accent : c.border, width: on ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: on ? c.accent : c.textSecondary)),
        ),
      );
    }

    final row = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final p in focusPresets) ...[
            chip('$p min', st.focusMin == p,
                locked ? null : () => st.setFocusMinutes(p)),
            const SizedBox(width: 8),
          ],
          chip('Customize', false,
              locked ? null : onOpenCustomize),
        ],
      ),
    );
    if (locked) return Opacity(opacity: 0.55, child: row);
    return row;
  }
}
