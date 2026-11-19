import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';
import '../logic/focus_link_helpers.dart';

class FocusCourseSelector extends StatelessWidget {
  const FocusCourseSelector({
    super.key,
    required this.st,
    required this.locked,
    required this.onOpenCourseSheet,
  });

  final FocusState st;
  final bool locked;
  final VoidCallback onOpenCourseSheet;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final label = FocusLinkHelpers.linkLabel(context, st.linkKind, st.linkId);
    Widget row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(FocusLinkHelpers.linkIcon(st.linkKind), color: c.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary)),
          ),
          Icon(Icons.expand_more_rounded, color: c.textSecondary),
        ],
      ),
    );
    if (locked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Opacity(opacity: 0.55, child: IgnorePointer(child: row)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          PremiumHaptics.select();
          onOpenCourseSheet();
        },
        child: row,
      ),
    );
  }
}
