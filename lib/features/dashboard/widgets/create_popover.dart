import 'package:flutter/material.dart';
import '../../../domain/haptics.dart';
import '../../../theme/app_colors.dart';

/// "+" popover: Create task / Add class routine. 180ms scale+fade with
/// 25ms stagger (120ms plain fade on reduce-motion). Tap outside or Back
/// closes it.
class CreatePopover extends StatefulWidget {
  const CreatePopover({
    super.key,
    required this.onCreateTask,
    required this.onAddClass,
  });

  final VoidCallback onCreateTask;
  final VoidCallback onAddClass;

  @override
  State<CreatePopover> createState() => _CreatePopoverState();
}

class _CreatePopoverState extends State<CreatePopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        _ctrl.duration = const Duration(milliseconds: 120);
      }
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scale = reduce
        ? const AlwaysStoppedAnimation<double>(1.0)
        : CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    return ScaleTransition(
      scale: scale,
      alignment: Alignment.topRight,
      child: FadeTransition(
        opacity: _ctrl,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: c.cardBg,
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _popItem(
                  context,
                  c,
                  delay: 0,
                  icon: Icons.add_task_outlined,
                  label: 'Create task',
                  onTap: widget.onCreateTask,
                ),
                _popItem(
                  context,
                  c,
                  delay: 1,
                  icon: Icons.calendar_month_outlined,
                  label: 'Add class routine',
                  onTap: widget.onAddClass,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _popItem(
    BuildContext context,
    AppColors c, {
    required int delay,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        PremiumHaptics.select();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (reduce) {
      return row;
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = (_ctrl.value * 2 - delay * 0.25).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: row,
    );
  }
}
