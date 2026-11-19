import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/haptics.dart';
import '../../../state/focus_state.dart';
import '../../../theme/app_colors.dart';

/// Focus/break duration editor (minutes only).
class FocusCustomizeSheet extends StatefulWidget {
  const FocusCustomizeSheet({super.key});

  @override
  State<FocusCustomizeSheet> createState() => _FocusCustomizeSheetState();
}

class _FocusCustomizeSheetState extends State<FocusCustomizeSheet> {
  late int _focus;
  late int _breakM;

  @override
  void initState() {
    super.initState();
    final st = context.read<FocusState>();
    _focus = st.focusMin;
    _breakM = st.breakMin;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final st = context.read<FocusState>();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Custom durations',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _stepRow(c, 'Focus', '$_focus min', _focus, 5, 120,
                (v) => setState(() => _focus = v)),
            _stepRow(c, 'Break', '$_breakM min', _breakM, 1, 30,
                (v) => setState(() => _breakM = v)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () {
                  PremiumHaptics.tap();
                  st.setDurations(focus: _focus, breakM: _breakM);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Save',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(AppColors c, String label, String value, int v,
      int min, int max, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                Text(value,
                    style: TextStyle(
                        fontSize: 13, color: c.textSecondary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            onPressed: () {
              PremiumHaptics.select();
              onChanged((v - 1).clamp(min, max));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () {
              PremiumHaptics.select();
              onChanged((v + 1).clamp(min, max));
            },
          ),
        ],
      ),
    );
  }
}
