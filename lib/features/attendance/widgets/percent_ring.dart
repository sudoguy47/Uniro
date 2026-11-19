import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class PercentRing extends StatelessWidget {
  const PercentRing({
    super.key,
    required this.percent,
    required this.color,
    required this.size,
  });

  final double percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              strokeWidth: 8,
              backgroundColor: c.inputBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
