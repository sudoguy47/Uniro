// ignore_for_file: use_build_context_synchronously
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/local_store.dart';
import '../../theme/app_colors.dart';

// ─── Build number this tour is tied to ────────────────────────────────────────
const int _kTourBuildNumber = 2008;
const String _kTourKey = 'tour_seen_v1';

// ─── Global keys the shell / header attach to their real widgets ───────────────
class TourGuideKeys {
  TourGuideKeys._();

  static final GlobalKey navDashboard = GlobalKey(debugLabel: 'nav_dashboard');
  static final GlobalKey navRoutine = GlobalKey(debugLabel: 'nav_routine');
  static final GlobalKey navFocus = GlobalKey(debugLabel: 'nav_focus');
  static final GlobalKey navNotes = GlobalKey(debugLabel: 'nav_notes');
  static final GlobalKey navProfile = GlobalKey(debugLabel: 'nav_profile');
  static final GlobalKey plusButton = GlobalKey(debugLabel: 'plus_button');
}

// ─── Public entry points ───────────────────────────────────────────────────────

/// Returns true if the tour should be shown automatically (first launch or
/// after update to build 2008).
bool shouldShowTour() {
  final stored = LocalStore.instance.load(_kTourKey);
  if (stored == null) return true; // brand new user
  if (stored is num && stored < _kTourBuildNumber) return true; // update
  return false;
}

/// Mark the tour as seen for the current build number.
void markTourSeen() {
  LocalStore.instance.save(_kTourKey, _kTourBuildNumber);
}

/// Show the tour overlay imperatively. Safe to call from any BuildContext
/// that has a valid [Overlay].
Future<void> showTourGuide(BuildContext context) async {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TourGuideOverlay(
      onDone: () {
        markTourSeen();
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

// ─── Tour step data model ──────────────────────────────────────────────────────

enum _StepLayout { spotlight, fullCard }

class _TourStep {
  const _TourStep({
    required this.title,
    required this.description,
    required this.layout,
    this.targetKey,
    this.icon,
    this.tooltipSide = _TooltipSide.top,
  });

  final String title;
  final String description;
  final _StepLayout layout;
  final GlobalKey? targetKey;
  final IconData? icon;
  final _TooltipSide tooltipSide;
}

enum _TooltipSide { top, bottom }

final List<_TourStep> _tourSteps = [
  // 0 — Welcome (full card)
  const _TourStep(
    title: 'Welcome to Uniro 👋',
    description:
        'Your all-in-one academic companion. Here\'s a quick look at what you can do.',
    layout: _StepLayout.fullCard,
    icon: Icons.school_rounded,
  ),
  // 1 — Dashboard nav tab
  _TourStep(
    title: 'Dashboard',
    description:
        'Your home base. See today\'s tasks, upcoming deadlines, and your weekly load at a glance.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navDashboard,
    tooltipSide: _TooltipSide.top,
  ),
  // 2 — + FAB button
  _TourStep(
    title: '+ Quick Add',
    description:
        'Tap + to quickly add a task, note, or class. It\'s the fastest way to get things in.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.plusButton,
    tooltipSide: _TooltipSide.bottom,
  ),
  // 3 — Routine nav tab
  _TourStep(
    title: 'Class Routine',
    description:
        'Add your weekly schedule with room numbers, course codes, and time slots.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navRoutine,
    tooltipSide: _TooltipSide.top,
  ),
  // 4 — Focus nav tab
  _TourStep(
    title: 'Focus Timer',
    description:
        'Set a Pomodoro session for any course. Tracks your study time automatically.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navFocus,
    tooltipSide: _TooltipSide.top,
  ),
  // 5 — Notes nav tab
  _TourStep(
    title: 'Notes',
    description:
        'Jot down anything — lecture notes, reminders, ideas. Lock sensitive notes with biometrics.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navNotes,
    tooltipSide: _TooltipSide.top,
  ),
  // 6 — Attendance (full card, sub-feature)
  const _TourStep(
    title: 'Attendance Tracker',
    description:
        'Swipe into the Routine tab and tap any class to log attendance. Track your percentage per course.',
    layout: _StepLayout.fullCard,
    icon: Icons.fact_check_rounded,
  ),
  // 7 — Profile nav tab (last step)
  _TourStep(
    title: 'Settings & More',
    description:
        'Set your name, enable notifications, backup your data, and check for updates.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navProfile,
    tooltipSide: _TooltipSide.top,
  ),
];

// ─── Overlay widget ────────────────────────────────────────────────────────────

class _TourGuideOverlay extends StatefulWidget {
  const _TourGuideOverlay({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_TourGuideOverlay> createState() => _TourGuideOverlayState();
}

class _TourGuideOverlayState extends State<_TourGuideOverlay>
    with TickerProviderStateMixin {
  int _step = 0;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  // The spotlight rect (animated between steps)
  Rect? _spotRect;
  late AnimationController _spotCtrl;
  late Animation<Rect?> _spotAnim;
  Rect? _prevSpotRect;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _spotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Kick off with a post-frame callback so the UI has laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateSpotRect(animate: false);
        _fadeCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _spotCtrl.dispose();
    super.dispose();
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  Rect? _rectFor(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final size = box.size;
    final pos = box.localToGlobal(Offset.zero);
    const pad = 10.0;
    return Rect.fromLTWH(
      pos.dx - pad,
      pos.dy - pad,
      size.width + pad * 2,
      size.height + pad * 2,
    );
  }

  void _updateSpotRect({bool animate = true}) {
    final step = _tourSteps[_step];
    Rect? newRect;
    if (step.layout == _StepLayout.spotlight && step.targetKey != null) {
      newRect = _rectFor(step.targetKey!);
    }

    if (animate && _spotRect != null && newRect != null) {
      _prevSpotRect = _spotRect;
      _spotAnim = RectTween(begin: _prevSpotRect, end: newRect)
          .animate(CurvedAnimation(parent: _spotCtrl, curve: Curves.easeInOut));
      _spotCtrl.forward(from: 0);
    } else {
      _spotRect = newRect;
      _spotAnim = AlwaysStoppedAnimation(newRect);
    }
    setState(() {
      _spotRect = newRect;
    });
  }

  Future<void> _goTo(int index) async {
    if (index < 0 || index >= _tourSteps.length) return;
    // Fade out
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() => _step = index);
    _updateSpotRect(animate: true);
    // Fade in
    _fadeCtrl.forward();
  }

  void _next() {
    if (_step < _tourSteps.length - 1) {
      _goTo(_step + 1);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) _goTo(_step - 1);
  }

  void _skip() => _finish();

  void _finish() {
    _fadeCtrl.reverse().then((_) {
      widget.onDone();
    });
  }

  // ─── build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final step = _tourSteps[_step];
    final size = MediaQuery.sizeOf(context);
    final c = Theme.of(context).extension<AppColors>()!;

    return FadeTransition(
      opacity: _fade,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark overlay + spotlight cutout ──────────────────────────────────
          AnimatedBuilder(
            animation: _spotCtrl,
            builder: (_, __) {
              final animRect = _spotCtrl.isAnimating
                  ? _spotAnim.value
                  : _spotRect;
              return CustomPaint(
                size: size,
                painter: _OverlayPainter(spotRect: animRect),
              );
            },
          ),

          // ── Dismiss on tap outside ───────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // Allow tapping outside to advance (but not on spotlight area)
            },
          ),

          // ── Content ──────────────────────────────────────────────────────────
          if (step.layout == _StepLayout.fullCard)
            _FullCardStep(
              step: step,
              stepIndex: _step,
              totalSteps: _tourSteps.length,
              onNext: _next,
              onBack: _step > 0 ? _back : null,
              onSkip: _skip,
              isLast: _step == _tourSteps.length - 1,
              c: c,
            )
          else
            _SpotlightStep(
              step: step,
              stepIndex: _step,
              totalSteps: _tourSteps.length,
              spotRect: _spotRect,
              onNext: _next,
              onBack: _step > 0 ? _back : null,
              onSkip: _skip,
              isLast: _step == _tourSteps.length - 1,
              c: c,
            ),
        ],
      ),
    );
  }
}

// ─── Custom painter for overlay with spotlight cutout ─────────────────────────

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({this.spotRect});
  final Rect? spotRect;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    if (spotRect == null) {
      canvas.drawRect(
        fullRect,
        Paint()..color = Colors.black.withValues(alpha: 0.78),
      );
      return;
    }

    // Build path: full screen minus the spotlight cutout
    final radius = math.min(spotRect!.width, spotRect!.height) / 2;
    final rrect = RRect.fromRectAndRadius(spotRect!, Radius.circular(radius));

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.78),
    );

    // Soft glow ring around spotlight
    canvas.drawRRect(
      rrect.inflate(2),
      Paint()
        ..color = const Color(0xFFE59435).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.spotRect != spotRect;
}

// ─── Full-card step (Welcome, Attendance) ─────────────────────────────────────

class _FullCardStep extends StatelessWidget {
  const _FullCardStep({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
    required this.c,
    this.onBack,
  });

  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final bool isLast;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Skip button top-right
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: _SkipButton(onSkip: onSkip, c: c),
        ),

        // Center card
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE59435).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.icon ?? Icons.info_rounded,
                      size: 36,
                      color: const Color(0xFFE59435),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: c.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),

                  // Step dots
                  _StepDots(
                    current: stepIndex,
                    total: totalSteps,
                    c: c,
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      if (onBack != null) ...[
                        _NavButton(
                          label: '← Back',
                          onTap: onBack!,
                          filled: false,
                          c: c,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: _NavButton(
                          label: isLast ? 'Done ✓' : 'Start Tour →',
                          onTap: onNext,
                          filled: true,
                          c: c,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Spotlight step (tabs, + button) ──────────────────────────────────────────

class _SpotlightStep extends StatelessWidget {
  const _SpotlightStep({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.spotRect,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
    required this.c,
    this.onBack,
  });

  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect? spotRect;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final bool isLast;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Skip button top-right
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 16,
          child: _SkipButton(onSkip: onSkip, c: c),
        ),

        // Tooltip bubble, positioned relative to spotlight
        if (spotRect != null)
          _TooltipBubble(
            step: step,
            stepIndex: stepIndex,
            totalSteps: totalSteps,
            spotRect: spotRect!,
            onNext: onNext,
            onBack: onBack,
            onSkip: onSkip,
            isLast: isLast,
            c: c,
          )
        else
          // Fallback: center card if key not found
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: _BubbleCard(
                step: step,
                stepIndex: stepIndex,
                totalSteps: totalSteps,
                onNext: onNext,
                onBack: onBack,
                isLast: isLast,
                c: c,
              ),
            ),
          ),
      ],
    );
  }
}

class _TooltipBubble extends StatelessWidget {
  const _TooltipBubble({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.spotRect,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
    required this.c,
    this.onBack,
  });

  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final Rect spotRect;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback onSkip;
  final bool isLast;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final safePad = MediaQuery.paddingOf(context);
    const bubbleW = 280.0;
    const margin = 16.0;

    // Decide which side to place the bubble
    final side = step.tooltipSide;
    double left = spotRect.center.dx - bubbleW / 2;
    // Clamp horizontally
    left = left.clamp(margin, screenSize.width - bubbleW - margin);
    final arrowAlignX =
        (((spotRect.center.dx - left) / bubbleW) * 2 - 1).clamp(-0.85, 0.85);

    if (side == _TooltipSide.top) {
      // Bubble sits above the spotlight: position via bottom
      final bottom = screenSize.height - spotRect.top + 12;
      return Positioned(
        left: left,
        bottom: bottom.clamp(
          safePad.bottom + margin,
          screenSize.height - safePad.top - margin,
        ),
        width: bubbleW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BubbleCard(
              step: step,
              stepIndex: stepIndex,
              totalSteps: totalSteps,
              onNext: onNext,
              onBack: onBack,
              isLast: isLast,
              c: c,
            ),
            Align(
              alignment: Alignment(arrowAlignX, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Arrow(pointsUp: false, c: c),
              ),
            ),
          ],
        ),
      );
    } else {
      // Bubble sits below the spotlight: position via top
      final top = spotRect.bottom + 12;
      return Positioned(
        left: left,
        top: top.clamp(
          safePad.top + margin,
          screenSize.height - safePad.bottom - margin,
        ),
        width: bubbleW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment(arrowAlignX, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Arrow(pointsUp: true, c: c),
              ),
            ),
            _BubbleCard(
              step: step,
              stepIndex: stepIndex,
              totalSteps: totalSteps,
              onNext: onNext,
              onBack: onBack,
              isLast: isLast,
              c: c,
            ),
          ],
        ),
      );
    }
  }
}

class _BubbleCard extends StatelessWidget {
  const _BubbleCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.isLast,
    required this.c,
    this.onBack,
  });

  final _TourStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final bool isLast;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stepIndex + 1} / $totalSteps',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE59435),
                  letterSpacing: 0.5,
                ),
              ),
              _StepDots(current: stepIndex, total: totalSteps, c: c),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            step.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: -0.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            step.description,
            style: TextStyle(
              fontSize: 13,
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Buttons
          Row(
            children: [
              if (onBack != null) ...[
                _NavButton(
                  label: '←',
                  onTap: onBack!,
                  filled: false,
                  compact: true,
                  c: c,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _NavButton(
                  label: isLast ? 'Done ✓' : 'Next →',
                  onTap: onNext,
                  filled: true,
                  c: c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Arrow indicator ──────────────────────────────────────────────────────────

class _Arrow extends StatelessWidget {
  const _Arrow({required this.pointsUp, required this.c});
  final bool pointsUp;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 10),
      painter: _ArrowPainter(pointsUp: pointsUp, color: c.cardBg),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointsUp, required this.color});
  final bool pointsUp;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointsUp) {
      // Arrow pointing up = triangle with tip at top
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      // Arrow pointing down = triangle with tip at bottom
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) =>
      old.pointsUp != pointsUp || old.color != color;
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.current,
    required this.total,
    required this.c,
  });
  final int current;
  final int total;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE59435)
                : c.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.onTap,
    required this.filled,
    required this.c,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final AppColors c;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 40,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE59435),
            foregroundColor: const Color(0xFF1A1713),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        height: 40,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textSecondary,
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16),
            minimumSize: compact ? const Size(36, 40) : const Size(64, 40),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: compact ? 16 : 14,
            ),
          ),
        ),
      );
    }
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onSkip, required this.c});
  final VoidCallback onSkip;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSkip,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          'Skip',
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
