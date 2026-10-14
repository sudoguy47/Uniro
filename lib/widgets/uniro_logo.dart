import 'package:flutter/material.dart';

class UniroLogoPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;

  UniroLogoPainter({
    this.primaryColor = const Color(0xFF142A3B),
    this.accentColor = const Color(0xFF55D6BE),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 512.0;

    final Paint primaryPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final Paint accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.save();
    canvas.scale(scale, scale);

    // 1. Lower dynamic U body
    final Path uPath = Path()
      ..moveTo(120, 220)
      ..cubicTo(120, 330, 180, 392, 270, 392)
      ..cubicTo(330, 392, 380, 365, 410, 320)
      ..lineTo(362, 284)
      ..cubicTo(340, 314, 308, 332, 270, 332)
      ..cubicTo(216, 332, 178, 290, 178, 220)
      ..lineTo(178, 180)
      ..lineTo(120, 180)
      ..close();

    canvas.drawPath(uPath, primaryPaint);

    // 2. Rising terminal arrow / apex
    final Path arrowPath = Path()
      ..moveTo(390, 100)
      ..lineTo(460, 200)
      ..lineTo(340, 165)
      ..close();

    final Path connectorPath = Path()
      ..moveTo(330, 290)
      ..lineTo(390, 120)
      ..lineTo(430, 190)
      ..lineTo(374, 340)
      ..close();

    canvas.drawPath(connectorPath, accentPaint);
    canvas.drawPath(arrowPath, accentPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UniroLogo extends StatelessWidget {
  final double size;
  final Color? primaryColor;
  final Color? accentColor;

  const UniroLogo({
    super.key,
    this.size = 64.0,
    this.primaryColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: UniroLogoPainter(
          primaryColor: primaryColor ?? const Color(0xFF142A3B),
          accentColor: accentColor ?? const Color(0xFF55D6BE),
        ),
      ),
    );
  }
}
