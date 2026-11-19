import 'package:flutter/material.dart';

/// Entrance: fade + 12px slide-up, 30ms stagger. Skipped on reduce-motion.
class RoutineEntrance extends StatefulWidget {
  const RoutineEntrance({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<RoutineEntrance> createState() => _RoutineEntranceState();
}

class _RoutineEntranceState extends State<RoutineEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final noAnim =
        MediaQueryData.fromView(View.of(context)).disableAnimations;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.13), // ≈12px on a ~90px card
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (noAnim) {
      _ctrl.value = 1;
    } else {
      Future.delayed(Duration(milliseconds: widget.index * 30), () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}
