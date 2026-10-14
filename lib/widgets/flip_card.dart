import 'package:flutter/material.dart';

/// Fixed black split-flap styling for the Focus clock cards.
/// Only these cards use fixed colors; everything else follows the app theme.
const _cardTop = Color(0xFF17171B);
const _cardBottom = Color(0xFF101013);
const _digit = Color(0xFFF5F3EC);

/// Wide split-flap card showing a two-digit string (e.g. "25").
///
/// The pair is laid out ONCE at full card size, then only the top or bottom
/// half of that same layout is shown through clipping, so halves align
/// exactly at the divider with no gap, overlap, or double-draw.
///
/// Flip: old top rotates 0 -> -90deg around its bottom edge (150ms easeIn),
/// then new bottom rotates 90 -> 0deg around its top edge (190ms easeOut).
/// Total ~340ms. Each half layer has its own [RepaintBoundary] and the
/// digit [Text] is built once per value change, never per animation frame.
/// With [animated] false (reduce motion) changes are 120ms cross-fades.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.value,
    this.radius = 28,
    this.animated = true,
  });

  /// Two-digit string. Updates only when the pair changes.
  final ValueNotifier<String> value;
  final double radius;
  final bool animated;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  static const _totalMs = 340;
  static const _firstMs = 150;

  late final AnimationController _ctrl;
  late final Animation<double> _firstHalf;
  late final Animation<double> _secondHalf;

  String _displayed = '00';
  String _old = '00';
  String _new = '00';
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _displayed = _old = _new = widget.value.value;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );
    _firstHalf = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0, _firstMs / _totalMs, curve: Curves.easeIn),
    );
    _secondHalf = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(_firstMs / _totalMs, 1, curve: Curves.easeOut),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _displayed = _new;
          _animating = false;
        });
      }
    });
    widget.value.addListener(_onValue);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      oldWidget.value.removeListener(_onValue);
      _new = widget.value.value;
      _displayed = _old = _new;
      _animating = false;
      widget.value.addListener(_onValue);
    }
  }

  @override
  void dispose() {
    widget.value.removeListener(_onValue);
    _ctrl.dispose();
    super.dispose();
  }

  void _onValue() {
    final v = widget.value.value;
    if (v == _new && !_animating) return;
    if (!widget.animated) {
      setState(() {
        _displayed = _old = _new = v;
        _animating = false;
      });
      return;
    }
    setState(() {
      _old = _displayed;
      _new = v;
      _animating = true;
    });
    _ctrl.forward(from: 0);
  }

  /// Full-card digit layout. FittedBox(contain) inside padding so the pair
  /// can never clip; the identical layout feeds both halves.
  Widget _fullLayout(String pair, double w, double h) {
    return SizedBox(
      width: w,
      height: h,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.08,
          vertical: h * 0.08,
        ),
        child: FittedBox(
          fit: BoxFit.contain,
          child: Text(
            pair,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -2,
              color: _digit,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  /// One clipped half of the full layout. [OverflowBox] keeps the full
  /// w×h constraints so the half-height box never re-lays-out the text.
  Widget _half({
    required bool top,
    required Widget full,
    required double w,
    required double h,
  }) {
    return ClipRect(
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: OverflowBox(
          minWidth: w,
          maxWidth: w,
          minHeight: h,
          maxHeight: h,
          alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
          child: full,
        ),
      ),
    );
  }

  Widget _rotating({
    required bool top,
    required Widget halfWidget,
    required double angle,
    required double shade,
  }) {
    return Transform(
      alignment: top ? Alignment.bottomCenter : Alignment.topCenter,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(angle),
      child: Stack(
        fit: StackFit.expand,
        children: [
          halfWidget,
          if (shade > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: shade),
                      Colors.black.withValues(alpha: shade * 0.4),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final h = cons.maxHeight;
      if (w <= 0 || h <= 0 || !w.isFinite || !h.isFinite) {
        return const SizedBox.expand();
      }

      Widget face;
      if (!widget.animated) {
        final full = _fullLayout(_displayed, w, h);
        face = AnimatedSwitcher(
          duration: const Duration(milliseconds: 120),
          child: Container(
            key: ValueKey<String>(_displayed),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  height: h / 2,
                  width: w,
                  child: RepaintBoundary(
                      child: _half(top: true, full: full, w: w, h: h)),
                ),
                Positioned(
                  top: h / 2,
                  height: h / 2,
                  width: w,
                  child: RepaintBoundary(
                      child: _half(top: false, full: full, w: w, h: h)),
                ),
              ],
            ),
          ),
        );
      } else if (!_animating) {
        final full = _fullLayout(_displayed, w, h);
        face = Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              height: h / 2,
              width: w,
              child: RepaintBoundary(
                  child: _half(top: true, full: full, w: w, h: h)),
            ),
            Positioned(
              top: h / 2,
              height: h / 2,
              width: w,
              child: RepaintBoundary(
                  child: _half(top: false, full: full, w: w, h: h)),
            ),
          ],
        );
      } else {
        final fullNew = _fullLayout(_new, w, h);
        final fullOld = _fullLayout(_old, w, h);
        face = AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            const split = _firstMs / _totalMs;
            final inFirst = _ctrl.value < split;
            final shade = inFirst
                ? 0.18 * _firstHalf.value
                : 0.18 * (1 - _secondHalf.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 0,
                  height: h / 2,
                  width: w,
                  child: RepaintBoundary(
                      child: _half(top: true, full: fullNew, w: w, h: h)),
                ),
                Positioned(
                  top: h / 2,
                  height: h / 2,
                  width: w,
                  child: RepaintBoundary(
                    child: _half(
                      top: false,
                      full: inFirst ? fullOld : fullNew,
                      w: w,
                      h: h,
                    ),
                  ),
                ),
                if (inFirst)
                  Positioned(
                    top: 0,
                    height: h / 2,
                    width: w,
                    child: RepaintBoundary(
                      child: _rotating(
                        top: true,
                        halfWidget:
                            _half(top: true, full: fullOld, w: w, h: h),
                        angle: -1.5707963 * _firstHalf.value,
                        shade: shade,
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: h / 2,
                    height: h / 2,
                    width: w,
                    child: RepaintBoundary(
                      child: _rotating(
                        top: false,
                        halfWidget:
                            _half(top: false, full: fullNew, w: w, h: h),
                        angle: 1.5707963 * (1 - _secondHalf.value),
                        shade: shade,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      }

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_cardTop, _cardBottom],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              face,
              // Thin divider across the exact middle.
              Positioned(
                top: h / 2 - 1,
                left: 0,
                right: 0,
                height: 2,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
