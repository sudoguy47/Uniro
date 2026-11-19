import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';

class FocusBreakOffer extends StatelessWidget {
  const FocusBreakOffer({super.key, required this.st});

  final FocusState st;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Focus complete! Take a ${st.breakMin}-min break?',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    PremiumHaptics.select();
                    st.dismissBreakOffer();
                  },
                  child: Text('Skip',
                      style: TextStyle(color: c.textSecondary)),
                ),
                FilledButton(
                  onPressed: () {
                    PremiumHaptics.tap();
                    st.startBreak();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start break'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
