import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../theme/app_colors.dart';

class TargetPickerSheet extends StatelessWidget {
  const TargetPickerSheet({
    super.key,
    required this.currentTarget,
    required this.onSaveTarget,
  });

  final int currentTarget;
  final ValueChanged<int> onSaveTarget;

  static Future<void> show({
    required BuildContext context,
    required int currentTarget,
    required ValueChanged<int> onSaveTarget,
  }) async {
    PremiumHaptics.select();
    final c = Theme.of(context).extension<AppColors>()!;
    var selectedTarget = currentTarget;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: c.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Attendance Target',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Set minimum required attendance percentage to receive timely bunk and shortfall warnings.',
                    style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '$selectedTarget%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: c.accent,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  SliderTheme(
                    data: SliderTheme.of(ctx).copyWith(
                      activeTrackColor: c.accent,
                      inactiveTrackColor: c.inputBg,
                      thumbColor: c.accent,
                      overlayColor: c.accent.withValues(alpha: 0.15),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: selectedTarget.toDouble(),
                      min: 50,
                      max: 95,
                      divisions: 9,
                      label: '$selectedTarget%',
                      onChanged: (v) {
                        setSheetState(() => selectedTarget = v.round());
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [60, 75, 80, 85].map((target) {
                      final active = selectedTarget == target;
                      return ChoiceChip(
                        label: Text('$target%'),
                        selected: active,
                        onSelected: (_) {
                          setSheetState(() => selectedTarget = target);
                        },
                        selectedColor: c.accent.withValues(alpha: 0.15),
                        backgroundColor: c.inputBg,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? c.accent : c.textSecondary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: active ? c.accent : c.border,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        PremiumHaptics.confirm();
                        onSaveTarget(selectedTarget);
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Save Target',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
