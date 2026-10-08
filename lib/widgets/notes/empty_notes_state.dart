import 'package:flutter/material.dart';

class EmptyNotesState extends StatelessWidget {
  const EmptyNotesState({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomPaint(
              size: const Size(120, 120),
              painter: _NotebookIllustrationPainter(
                primaryColor: cs.primary,
                surfaceColor: cs.surfaceContainerHighest,
                outlineColor: cs.outlineVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing here yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to write your first note.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotebookIllustrationPainter extends CustomPainter {
  final Color primaryColor;
  final Color surfaceColor;
  final Color outlineColor;

  _NotebookIllustrationPainter({
    required this.primaryColor,
    required this.surfaceColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Back shadow / accent page
    final backPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final backRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.12, w * 0.64, h * 0.76),
      const Radius.circular(16),
    );
    canvas.drawRRect(backRRect, backPaint);

    // Main notebook page
    final pagePaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    final pageRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.64, h * 0.76),
      const Radius.circular(16),
    );
    canvas.drawRRect(pageRRect, pagePaint);

    // Page border
    final borderPaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(pageRRect, borderPaint);

    // Spine stripe
    final spinePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    final spinePath = Path();
    spinePath.addRRect(RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.16, h * 0.16, w * 0.10, h * 0.76),
      topLeft: const Radius.circular(16),
      bottomLeft: const Radius.circular(16),
    ));
    canvas.drawPath(spinePath, spinePaint);

    // Decorative ruled lines on the page
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final lineXStart = w * 0.34;
    final lineXEndShort = w * 0.58;
    final lineXEndLong = w * 0.70;

    canvas.drawLine(
      Offset(lineXStart, h * 0.32),
      Offset(lineXEndLong, h * 0.32),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineXStart, h * 0.44),
      Offset(lineXEndShort, h * 0.44),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineXStart, h * 0.56),
      Offset(lineXEndLong, h * 0.56),
      linePaint,
    );
    canvas.drawLine(
      Offset(lineXStart, h * 0.68),
      Offset(lineXEndShort + 8, h * 0.68),
      linePaint,
    );

    // Bookmark ribbon
    final ribbonPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    final ribbonPath = Path()
      ..moveTo(w * 0.62, h * 0.16)
      ..lineTo(w * 0.62, h * 0.34)
      ..lineTo(w * 0.66, h * 0.30)
      ..lineTo(w * 0.70, h * 0.34)
      ..lineTo(w * 0.70, h * 0.16)
      ..close();
    canvas.drawPath(ribbonPath, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant _NotebookIllustrationPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.surfaceColor != surfaceColor ||
      oldDelegate.outlineColor != outlineColor;
}
