import 'package:flutter/material.dart';

/// Focus control button with fixed height and a scale-down label row:
/// at 320dp / large text the content shrinks instead of overflowing.
class FocusBtn extends StatelessWidget {
  const FocusBtn({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.fill,
    this.outlinedColor,
    this.borderColor,
    this.iconSize = 18,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? fill;
  final Color? outlinedColor;
  final Color? borderColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = (outlinedColor ?? Colors.white).withValues(alpha: enabled ? 1.0 : 0.4);

    Widget content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );

    if (fill != null) {
      return SizedBox(
        height: 48,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: fill,
            disabledBackgroundColor: fill!.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: content,
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: (borderColor ?? Colors.transparent)
                .withValues(alpha: enabled ? 1.0 : 0.3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: content,
      ),
    );
  }
}
