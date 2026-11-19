import 'package:flutter/material.dart';
import '../../../domain/focus_logic.dart';
import '../../../domain/haptics.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';
import 'focus_button.dart';

class FocusControls extends StatelessWidget {
  const FocusControls({
    super.key,
    required this.st,
    required this.onStart,
    required this.onRestart,
    required this.onEnd,
  });

  final FocusState st;
  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final idle = st.phase == FocusPhase.idle && !st.active;
    final canEnd = st.active;
    final centerLabel = !st.running
        ? 'Start focus'
        : st.paused
            ? 'Resume'
            : 'Pause';
    final centerIcon = !st.running
        ? Icons.play_arrow_rounded
        : st.paused
            ? Icons.play_arrow_rounded
            : Icons.pause_rounded;

    VoidCallback? restartTap;
    if (idle && !st.pendingBreak) {
      restartTap = null;
    } else if (idle) {
      restartTap = () {
        PremiumHaptics.tap();
        st.restart();
      };
    } else {
      restartTap = onRestart;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: FocusBtn(
              icon: Icons.refresh_rounded,
              label: 'Restart',
              outlinedColor: c.textPrimary,
              borderColor: c.border,
              onTap: restartTap,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FocusBtn(
              icon: centerIcon,
              iconSize: 20,
              label: centerLabel,
              fill: c.accent,
              outlinedColor: Colors.white,
              onTap: () {
                if (!st.running) {
                  onStart();
                } else if (st.paused) {
                  PremiumHaptics.tap();
                  st.resume();
                } else {
                  PremiumHaptics.tap();
                  st.pause();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FocusBtn(
              icon: Icons.stop_rounded,
              label: 'End',
              outlinedColor: c.overdue,
              borderColor: c.overdue.withValues(alpha: 0.5),
              onTap: !canEnd ? null : onEnd,
            ),
          ),
        ],
      ),
    );
  }
}
