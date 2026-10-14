import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated onboarding mascots, drawn with CustomPainter (zero assets,
/// zero new dependencies — keeps the APK diet from the size pass).
///
/// Each mascot runs ONE repeating controller (gentle bob) + a blink timer.
/// Painters take explicit (bob/blink/time) values so frames repaint only
/// the small mascot layer (wrapped in RepaintBoundary by callers).

// ── Shared animation driver ─────────────────────────────────────────────

/// Drives bob + blink + loop-time for a mascot painter.
class MascotStage extends StatefulWidget {
  const MascotStage({super.key, required this.builder});

  /// [bob] = vertical pixels (-6..6), [blink] = 0..1, [t] = loop 0..1.
  final Widget Function(BuildContext context, double bob, double blink, double t)
      builder;

  @override
  State<MascotStage> createState() => _MascotStageState();
}

class _MascotStageState extends State<MascotStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _blinkTimer;
  Timer? _blinkOffTimer;
  double _blink = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    // Natural blink every ~3.4s, lids closed for 150ms.
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 3400), (_) {
      if (!mounted) return;
      setState(() => _blink = 1);
      _blinkOffTimer?.cancel();
      _blinkOffTimer = Timer(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _blink = 0);
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _blinkOffTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final bob = math.sin(t * math.pi * 2) * 6.0;
        return widget.builder(context, bob, _blink, t);
      },
    );
  }
}

// ── Slide 1: graduate face ──────────────────────────────────────────────

class GradMascot extends StatelessWidget {
  const GradMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MascotStage(
        builder: (context, bob, blink, t) => Transform.translate(
          offset: Offset(0, bob),
          child: CustomPaint(
            size: const Size(200, 215),
            painter: _GradPainter(
              blink: blink,
              tasselSwing: math.sin(t * math.pi * 2) * 0.28,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradPainter extends CustomPainter {
  _GradPainter({required this.blink, required this.tasselSwing});
  final double blink;
  final double tasselSwing;

  @override
  void paint(Canvas canvas, Size size) {
    // Face
    final facePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(100, 118), 75, facePaint);

    // Grad cap board
    final capPaint = Paint()..color = const Color(0xFF1B1B1B);
    canvas.drawRRect(
      RRect.fromLTRBR(25, 30, 175, 56, const Radius.circular(13)),
      capPaint,
    );

    // Tassel: swings gently from the board's right edge
    const anchor = Offset(163, 50);
    final angle = 1.25 + tasselSwing; // ~70° ± swing
    const len = 36.0;
    final end = anchor + Offset(math.cos(angle) * len, math.sin(angle) * len);
    canvas.drawLine(
      anchor,
      end,
      Paint()
        ..color = const Color(0xFF1B1B1B)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(end, 5.5, Paint()..color = const Color(0xFFE07B2E));

    // Eyes (lids close on blink)
    final eyeH = (15 * (1 - blink * 0.92)).clamp(1.2, 15.0);
    final eyePaint = Paint()..color = const Color(0xFF1B1B1B);
    for (final cx in [72.0, 128.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 110), width: 24, height: eyeH * 2),
        eyePaint,
      );
      if (blink < 0.5) {
        canvas.drawCircle(Offset(cx - 4, 105), 4.2, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx + 3, 112), 1.6, Paint()..color = Colors.white);
      }
    }

    // Brows
    final browPaint = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(62, 86), const Offset(80, 82), browPaint);
    canvas.drawLine(const Offset(138, 86), const Offset(120, 82), browPaint);

    // Smile
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(100, 132), radius: 21),
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      Paint()
        ..color = const Color(0xFF1B1B1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Blush
    final blush = Paint()..color = const Color(0xFFF3C39B).withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: const Offset(48, 132), width: 20, height: 13), blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(152, 132), width: 20, height: 13), blush);
  }

  @override
  bool shouldRepaint(covariant _GradPainter old) =>
      old.blink != blink || old.tasselSwing != tasselSwing;
}

// ── Slide 2: calendar ───────────────────────────────────────────────────

class CalendarMascot extends StatelessWidget {
  const CalendarMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MascotStage(
        builder: (context, bob, blink, t) => Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: math.sin(t * math.pi * 2) * 0.02,
            child: CustomPaint(
              size: const Size(200, 215),
              painter: _CalendarPainter(blink: blink),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarPainter extends CustomPainter {
  _CalendarPainter({required this.blink});
  final double blink;

  static const _dot = Color(0xFFAEBDCE);
  static const _ink = Color(0xFF1B1B1B);

  @override
  void paint(Canvas canvas, Size size) {
    // Body
    canvas.drawRRect(
      RRect.fromLTRBR(28, 54, 172, 180, const Radius.circular(16)),
      Paint()..color = Colors.white,
    );
    // Header band
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(28, 54, 144, 42),
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
      ),
      Paint()..color = const Color(0xFFD9E7F5),
    );

    // Binder tabs (double as eyes — squash on blink)
    final tabH = (34 * (1 - blink * 0.75)).clamp(8.0, 34.0);
    for (final cx in [70.0, 130.0]) {
      canvas.drawRRect(
        RRect.fromLTRBR(cx - 12, 50 - tabH / 2, cx + 12, 50 + tabH / 2,
            const Radius.circular(10)),
        Paint()..color = _ink,
      );
      if (blink < 0.5) {
        canvas.drawCircle(Offset(cx - 1, 50 - 3), 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(Offset(cx + 2, 52), 2.2, Paint()..color = _ink);
      }
    }

    // Smile on the header band
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(100, 82), radius: 15),
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Date dots: 5 cols × 3 rows, one orange + one green highlight
    const xs = [58.0, 79.0, 100.0, 121.0, 142.0];
    const ys = [114.0, 136.0, 158.0];
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 5; c++) {
        final color = (r == 0 && c == 2)
            ? const Color(0xFFE07B2E)
            : (r == 1 && c == 1)
                ? const Color(0xFF5E8F6A)
                : _dot;
        canvas.drawCircle(Offset(xs[c], ys[r]), 5, Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CalendarPainter old) => old.blink != blink;
}

// ── Slide 4: reminder bell ──────────────────────────────────────────────

class BellMascot extends StatelessWidget {
  const BellMascot({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MascotStage(
        builder: (context, bob, blink, t) => Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: math.sin(t * math.pi * 2) * 0.09,
            alignment: Alignment.topCenter,
            child: CustomPaint(
              size: const Size(200, 215),
              painter: _BellPainter(blink: blink),
            ),
          ),
        ),
      ),
    );
  }
}

class _BellPainter extends CustomPainter {
  _BellPainter({required this.blink});
  final double blink;

  static const _ink = Color(0xFF1B1B1B);

  @override
  void paint(Canvas canvas, Size size) {
    // Dome
    final dome = Path()
      ..moveTo(58, 140)
      ..cubicTo(58, 92, 76, 62, 100, 62)
      ..cubicTo(124, 62, 142, 92, 142, 140)
      ..close();
    canvas.drawPath(dome, Paint()..color = Colors.white);
    // Skirt band
    canvas.drawRRect(
      RRect.fromLTRBR(50, 132, 150, 154, const Radius.circular(11)),
      Paint()..color = const Color(0xFFD9C7EC),
    );
    // Clapper
    canvas.drawCircle(const Offset(100, 168), 12, Paint()..color = const Color(0xFFE07B2E));
    // Top knob
    canvas.drawCircle(const Offset(100, 56), 9, Paint()..color = _ink);

    // Eyes
    final eyeH = (14 * (1 - blink * 0.92)).clamp(1.2, 14.0);
    for (final cx in [78.0, 122.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 106), width: 22, height: eyeH * 2),
        Paint()..color = _ink,
      );
      if (blink < 0.5) {
        canvas.drawCircle(Offset(cx - 3.5, 102), 3.8, Paint()..color = Colors.white);
      }
    }
    // Smile
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(100, 120), radius: 15),
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BellPainter old) => old.blink != blink;
}

// ── Slide 3: floating doodles ───────────────────────────────────────────

/// Slowly drifting decoration (pencil / cap / books on the name slide).
class DoodleFloater extends StatefulWidget {
  const DoodleFloater({
    super.key,
    required this.child,
    this.amplitude = 7,
    this.periodMs = 3200,
    this.phase = 0,
  });

  final Widget child;
  final double amplitude;
  final int periodMs;
  final double phase;

  @override
  State<DoodleFloater> createState() => _DoodleFloaterState();
}

class _DoodleFloaterState extends State<DoodleFloater>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.periodMs),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * math.pi * 2 + widget.phase;
        return Transform.translate(
          offset: Offset(math.cos(t) * 3, math.sin(t) * widget.amplitude),
          child: Transform.rotate(
            angle: math.sin(t) * 0.08,
            child: widget.child,
          ),
        );
      },
    );
  }
}

class PencilDoodle extends StatelessWidget {
  const PencilDoodle({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 64),
      painter: _PencilPainter(),
    );
  }
}

class _PencilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(32, 32);
    canvas.rotate(-0.6);
    canvas.translate(-32, -32);
    // Body
    canvas.drawRRect(
      RRect.fromLTRBR(8, 22, 46, 42, const Radius.circular(6)),
      Paint()..color = const Color(0xFFB9A44A),
    );
    // Ferrule + eraser
    canvas.drawRect(
      const Rect.fromLTWH(2, 22, 8, 20),
      Paint()..color = const Color(0xFFD8D2C4),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(-6, 24, 4, 40, const Radius.circular(4)),
      Paint()..color = const Color(0xFFE08E8E),
    );
    // Wood tip + lead
    final tip = Path()
      ..moveTo(46, 22)
      ..lineTo(60, 32)
      ..lineTo(46, 42)
      ..close();
    canvas.drawPath(tip, Paint()..color = const Color(0xFFE8C895));
    canvas.drawCircle(const Offset(57, 32), 3, Paint()..color = const Color(0xFF3A3A3A));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class MiniCapDoodle extends StatelessWidget {
  const MiniCapDoodle({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(56, 48),
      painter: _MiniCapPainter(),
    );
  }
}

class _MiniCapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF2E4A3A);
    // Board
    canvas.save();
    canvas.translate(28, 16);
    canvas.rotate(0.08);
    final board = Path()
      ..moveTo(-24, 0)
      ..lineTo(0, -10)
      ..lineTo(24, 0)
      ..lineTo(0, 10)
      ..close();
    canvas.drawPath(board, paint);
    canvas.restore();
    // Skull cap
    canvas.drawRRect(
      RRect.fromLTRBR(16, 20, 40, 38, const Radius.circular(6)),
      paint,
    );
    // Tassel
    canvas.drawLine(
      const Offset(46, 16),
      const Offset(50, 34),
      Paint()
        ..color = paint.color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(50, 36), 3.5, Paint()..color = const Color(0xFFE0B64F));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class BooksDoodle extends StatelessWidget {
  const BooksDoodle({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(72, 62),
      painter: _BooksPainter(),
    );
  }
}

class _BooksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const colors = [Color(0xFF7FB08A), Color(0xFF4E8A6B), Color(0xFFE07B2E)];
    for (var i = 0; i < 3; i++) {
      final y = 44.0 - i * 15.0;
      canvas.drawRRect(
        RRect.fromLTRBR(6 + (i == 1 ? 5 : 0), y, 66 - (i == 2 ? 6 : 0), y + 14,
            const Radius.circular(4)),
        Paint()..color = colors[i],
      );
      canvas.drawLine(
        Offset(12, y + 7),
        Offset(58, y + 7),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
