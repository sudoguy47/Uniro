import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';

// ══════════════════════════════════════════════════════════════
// PrimaryButton — GymMane PrimaryButton
// ══════════════════════════════════════════════════════════════
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact(); // GymMane haptic
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(
                  widget.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// TinySwitch — GymMane TinySwitch (140ms micro duration)
// ══════════════════════════════════════════════════════════════
class TinySwitch extends StatelessWidget {
  const TinySwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: AppTheme.micro, // 140ms — GymMane pattern
        curve: Curves.easeOutCubic,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? c.toggleActive : c.toggleInactive,
          borderRadius: BorderRadius.circular(999),
          border:
              Border.all(color: value ? c.toggleActive : c.toggleInactive),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FilterChip — Dashboard filter pills
// ══════════════════════════════════════════════════════════════
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppTheme.fast, // 200ms
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? c.navActiveBg : c.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? Colors.transparent : c.border),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: active ? c.navActiveText : c.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// StepperControl — Profile reminder days
// ══════════════════════════════════════════════════════════════
class StepperControl extends StatefulWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 30,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  State<StepperControl> createState() => _StepperControlState();
}

class _StepperControlState extends State<StepperControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: AppTheme.micro, // 140ms
      lowerBound: 1.0,
      upperBound: 1.2,
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _change(int delta) {
    final next = widget.value + delta;
    if (next < widget.min || next > widget.max) return;
    HapticFeedback.selectionClick();
    // GymMane: number bounces on change
    _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleBtn(icon: Icons.remove, onTap: () => _change(-1), c: c),
        const SizedBox(width: 8),
        ScaleTransition(
          scale: _scaleCtrl,
          child: SizedBox(
            width: 32,
            child: Text(
              '${widget.value}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CircleBtn(icon: Icons.add, onTap: () => _change(1), c: c),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap, required this.c});
  final IconData icon;
  final VoidCallback onTap;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: c.border),
          color: c.cardBg,
        ),
        child: Icon(icon, size: 16, color: c.textPrimary),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PrioritySelector — New Task modal
// ══════════════════════════════════════════════════════════════
class PrioritySelector extends StatelessWidget {
  const PrioritySelector(
      {super.key, required this.value, required this.onChange});
  final TaskPriority value;
  final ValueChanged<TaskPriority> onChange;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Row(
      children: TaskPriority.values.map((p) {
        final active = p == value;
        final label = p.name[0].toUpperCase() + p.name.substring(1);
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChange(p);
            },
            child: AnimatedContainer(
              duration: AppTheme.fast,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 44,
              decoration: BoxDecoration(
                color: active ? c.accentLight : c.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active ? c.accent : c.border,
                  width: active ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active ? c.accent : c.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RadioListItem — Reminder Picker Sheet
// ══════════════════════════════════════════════════════════════
class RadioListItem extends StatelessWidget {
  const RadioListItem({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppTheme.micro, // 140ms
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? c.accent : c.border, width: 2),
              ),
              child: selected
                  ? Center(
                      child: AnimatedContainer(
                      duration: AppTheme.micro,
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: c.accent),
                    ))
                  : null,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
