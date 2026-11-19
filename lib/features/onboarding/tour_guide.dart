// ignore_for_file: use_build_context_synchronously
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_shell.dart';
import '../../domain/sample_data.dart';
import '../../services/local_store.dart';
import '../../state/app_state.dart';
import '../../state/notes_state.dart';
import '../../state/routine_state.dart';
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
  // Never auto-show during widget tests to avoid obscuring existing test surfaces
  if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
    return false;
  }
  final stored = LocalStore.instance.load(_kTourKey);
  if (stored == null) return true; // brand new user
  if (stored is num && stored < _kTourBuildNumber) return true; // update
  return false;
}

/// Mark the tour as seen for the current build number.
void markTourSeen() {
  LocalStore.instance.save(_kTourKey, _kTourBuildNumber);
}

/// Show the tour overlay imperatively.
/// Always navigates to Dashboard first so the tour is presented directly
/// on the main screen.
Future<void> showTourGuide(BuildContext context) async {
  // 1. Immediately switch to the Dashboard tab
  AppShell.openTab(AppTab.dashboard);

  // 2. Wait for page transition & widget layout to settle
  await Future<void>.delayed(const Duration(milliseconds: 260));
  if (!context.mounted) return;

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  // Track if sample examples were seeded during this tour
  var seededExamples = false;

  void cleanUp() {
    markTourSeen();
    if (seededExamples) {
      try {
        final app = context.read<AppState>();
        final routine = context.read<RoutineState>();
        final notes = context.read<NotesState>();
        hideExampleData(app: app, routine: routine, notes: notes);
      } catch (_) {}
    }
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => _TourGuideOverlay(
      onDone: cleanUp,
      onSeedExamples: () {
        seededExamples = true;
        try {
          final app = context.read<AppState>();
          final routine = context.read<RoutineState>();
          final notes = context.read<NotesState>();
          seedExampleData(app: app, routine: routine, notes: notes);
        } catch (_) {}
      },
    ),
  );

  overlay.insert(entry);
}

// ─── Tour step data model ──────────────────────────────────────────────────────

enum _StepLayout { spotlight, fullCard, interactiveDemo }

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
        'Your private, offline academic companion. Let\'s take a quick tour through the key features to help you get the most out of your campus life.',
    layout: _StepLayout.fullCard,
    icon: Icons.school_rounded,
  ),
  // 1 — Dashboard nav tab
  _TourStep(
    title: 'Dashboard',
    description:
        'Your daily headquarters. See upcoming tasks, active deadlines, and your weekly academic workload at a glance.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navDashboard,
    tooltipSide: _TooltipSide.top,
  ),
  // 2 — + FAB button
  _TourStep(
    title: '+ Quick Add',
    description:
        'Tap + anytime to add a task, note, or new class schedule. It\'s the fastest way to capture anything academic.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.plusButton,
    tooltipSide: _TooltipSide.bottom,
  ),
  // 3 — Routine nav tab
  _TourStep(
    title: 'Class Routine',
    description:
        'Keep your weekly timetable organized with room numbers, course codes, and smart class alarms.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navRoutine,
    tooltipSide: _TooltipSide.top,
  ),
  // 4 — Focus nav tab
  _TourStep(
    title: 'Focus Timer',
    description:
        'Stay locked in with a distraction-free Pomodoro timer linked to your specific university courses.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navFocus,
    tooltipSide: _TooltipSide.top,
  ),
  // 5 — Notes nav tab
  _TourStep(
    title: 'Notes & Ideas',
    description:
        'Jot down lecture notes, assignments, and quick thoughts. Lock sensitive notes with biometric or PIN security.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navNotes,
    tooltipSide: _TooltipSide.top,
  ),
  // 6 — Attendance (full card, sub-feature)
  const _TourStep(
    title: 'Attendance Tracker',
    description:
        'Tap any class card to log attendance in one tap. Set target goals (e.g. 75%) and get smart alerts on safe bunk limits.',
    layout: _StepLayout.fullCard,
    icon: Icons.fact_check_rounded,
  ),
  // 7 — Profile nav tab
  _TourStep(
    title: 'Settings & Profile',
    description:
        'Customize notifications, create local encrypted backups, choose themes, or replay this guide anytime.',
    layout: _StepLayout.spotlight,
    targetKey: TourGuideKeys.navProfile,
    tooltipSide: _TooltipSide.top,
  ),
  // 8 — Interactive Demo: Adding Tasks & Routines
  const _TourStep(
    title: 'How to Add Tasks & Routines',
    description:
        'See how quick it is to add your academic items with real examples.',
    layout: _StepLayout.interactiveDemo,
    icon: Icons.add_circle_outline_rounded,
  ),
  // 9 — Completion card
  const _TourStep(
    title: 'You\'re All Set! 🚀',
    description:
        'You\'re ready to take control of your semester. Need a refresher later? Just open Profile → App Guide.',
    layout: _StepLayout.fullCard,
    icon: Icons.check_circle_rounded,
  ),
];

// ─── Overlay widget ────────────────────────────────────────────────────────────

class _TourGuideOverlay extends StatefulWidget {
  const _TourGuideOverlay({
    required this.onDone,
    required this.onSeedExamples,
  });

  final VoidCallback onDone;
  final VoidCallback onSeedExamples;

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
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _spotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    // Kick off with a post-frame callback so the UI has laid out first
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
    const pad = 8.0;
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
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() => _step = index);
    _updateSpotRect(animate: true);
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

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: TextStyle(
          decoration: TextDecoration.none,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          color: c.textPrimary,
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Dark overlay with clean spotlight cutout (NO harsh yellow border) ──
              AnimatedBuilder(
                animation: _spotCtrl,
                builder: (_, __) {
                  final animRect =
                      _spotCtrl.isAnimating ? _spotAnim.value : _spotRect;
                  return CustomPaint(
                    size: size,
                    painter: _OverlayPainter(spotRect: animRect),
                  );
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
              else if (step.layout == _StepLayout.interactiveDemo)
                _InteractiveDemoStep(
                  stepIndex: _step,
                  totalSteps: _tourSteps.length,
                  onNext: _next,
                  onBack: _back,
                  onSkip: _skip,
                  onSeedExamples: widget.onSeedExamples,
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
        ),
      ),
    );
  }
}

// ─── Custom painter: Clean cutout without yellow border ────────────────────────

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({this.spotRect});
  final Rect? spotRect;

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;

    if (spotRect == null) {
      canvas.drawRect(
        fullRect,
        Paint()..color = Colors.black.withValues(alpha: 0.76),
      );
      return;
    }

    // Build path: full screen minus the smooth spotlight cutout
    final radius = math.min(spotRect!.width, spotRect!.height) / 2;
    final rrect = RRect.fromRectAndRadius(spotRect!, Radius.circular(radius));

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.76),
    );

    // Subtle soft edge highlight (translucent white, NOT yellow)
    canvas.drawRRect(
      rrect.inflate(1),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.spotRect != spotRect;
}

// ─── Full-card step (Welcome, Attendance, Done) ───────────────────────────────

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: Step counter, dots, and integrated Skip button
              Row(
                children: [
                  Text(
                    '${stepIndex + 1} / $totalSteps',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE59435),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StepDots(current: stepIndex, total: totalSteps, c: c),
                  const Spacer(),
                  if (!isLast)
                    GestureDetector(
                      onTap: onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // Icon
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFFE59435).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  step.icon ?? Icons.info_rounded,
                  size: 34,
                  color: const Color(0xFFE59435),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 14.5,
                  color: c.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
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
                      label: isLast ? 'Got It, Let\'s Go! 🚀' : 'Next Step →',
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
    );
  }
}

// ─── Spotlight step (Tabs, + Button) ──────────────────────────────────────────

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
    if (spotRect != null) {
      return _TooltipBubble(
        step: step,
        stepIndex: stepIndex,
        totalSteps: totalSteps,
        spotRect: spotRect!,
        onNext: onNext,
        onBack: onBack,
        onSkip: onSkip,
        isLast: isLast,
        c: c,
      );
    }

    // Fallback: centered bubble if key not measured
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: _BubbleCard(
          step: step,
          stepIndex: stepIndex,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
          onSkip: onSkip,
          isLast: isLast,
          c: c,
        ),
      ),
    );
  }
}

// ─── Tooltip bubble positioned relative to target spotlight ────────────────────

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
    const bubbleW = 290.0;
    const margin = 16.0;

    final side = step.tooltipSide;
    double left = spotRect.center.dx - bubbleW / 2;
    left = left.clamp(margin, screenSize.width - bubbleW - margin);

    // Calculate arrow alignment pointing at the spotlight center
    final arrowAlignX =
        (((spotRect.center.dx - left) / bubbleW) * 2 - 1).clamp(-0.82, 0.82);

    if (side == _TooltipSide.top) {
      // Bubble sits above the spotlight (e.g. bottom nav items)
      final bottom = screenSize.height - spotRect.top + 10;
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
              onSkip: onSkip,
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
      // Bubble sits below the spotlight (e.g. + button in header)
      final top = spotRect.bottom + 10;
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
              onSkip: onSkip,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: step count, dots, and clean integrated Skip button
          Row(
            children: [
              Text(
                '${stepIndex + 1} / $totalSteps',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE59435),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              _StepDots(current: stepIndex, total: totalSteps, c: c),
              const Spacer(),
              if (!isLast)
                GestureDetector(
                  onTap: onSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            step.title,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              letterSpacing: -0.2,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            step.description,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Navigation buttons
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

// ─── Interactive Step: How to Add Tasks & Class Routines ───────────────────────

class _InteractiveDemoStep extends StatefulWidget {
  const _InteractiveDemoStep({
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
    required this.onSeedExamples,
    required this.c,
  });

  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;
  final VoidCallback onSeedExamples;
  final AppColors c;

  @override
  State<_InteractiveDemoStep> createState() => _InteractiveDemoStepState();
}

class _InteractiveDemoStepState extends State<_InteractiveDemoStep> {
  // 0 = Task, 1 = Class Routine
  int _selectedTab = 0;
  bool _previewedLive = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header: Step counter + Skip
                Row(
                  children: [
                    Text(
                      '${widget.stepIndex + 1} / ${widget.totalSteps}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE59435),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StepDots(
                      current: widget.stepIndex,
                      total: widget.totalSteps,
                      c: c,
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: widget.onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Heading
                Text(
                  'How to Add Content ✍️',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select a feature below to see the quick 3-step process:',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Segmented Selector Tab (Task vs Routine)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabButton(
                          label: '📝 Create Task',
                          selected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                          c: c,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _TabButton(
                          label: '📅 Class Routine',
                          selected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                          c: c,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Process Content based on Selected Tab
                if (_selectedTab == 0)
                  _buildTaskProcess(c)
                else
                  _buildRoutineProcess(c),

                const SizedBox(height: 16),

                // Optional: Preview live on Dashboard button
                GestureDetector(
                  onTap: () {
                    if (!_previewedLive) {
                      widget.onSeedExamples();
                      setState(() => _previewedLive = true);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: _previewedLive
                          ? const Color(0xFF5A8A5A).withValues(alpha: 0.16)
                          : const Color(0xFFE59435).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _previewedLive
                            ? const Color(0xFF5A8A5A).withValues(alpha: 0.4)
                            : const Color(0xFFE59435).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _previewedLive
                              ? Icons.check_circle_outline_rounded
                              : Icons.visibility_outlined,
                          size: 18,
                          color: _previewedLive
                              ? const Color(0xFF5A8A5A)
                              : const Color(0xFFE59435),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _previewedLive
                              ? 'Live examples loaded on Dashboard (auto-cleans on exit)'
                              : 'Tap to see sample items live on Dashboard',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _previewedLive
                                  ? const Color(0xFF5A8A5A)
                                  : const Color(0xFFE59435),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation Buttons (Back & Next)
                Row(
                  children: [
                    _NavButton(
                      label: '← Back',
                      onTap: widget.onBack,
                      filled: false,
                      c: c,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _NavButton(
                        label: 'Next Step →',
                        onTap: widget.onNext,
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
    );
  }

  Widget _buildTaskProcess(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProcessStep(
          stepNumber: '1',
          text: 'Tap + in the top-right header and choose "Create task".',
          c: c,
        ),
        const SizedBox(height: 8),
        _ProcessStep(
          stepNumber: '2',
          text:
              'Enter subject name, select Category (Exam, Assignment, CT), and pick a Due Date.',
          c: c,
        ),
        const SizedBox(height: 8),
        _ProcessStep(
          stepNumber: '3',
          text:
              'Tap Save. Uniro alerts you on time and updates your Weekly Load chart.',
          c: c,
        ),
        const SizedBox(height: 12),

        // Real visual example preview card
        Text(
          'REAL EXAMPLE:',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: c.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.pageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF5A8A5A).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 20,
                  color: Color(0xFF5A8A5A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discrete Mathematics',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Class Test (CT) • Due Nov 26 • Upcoming',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.border, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineProcess(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProcessStep(
          stepNumber: '1',
          text:
              'Tap + in the header and choose "Add class routine".',
          c: c,
        ),
        const SizedBox(height: 8),
        _ProcessStep(
          stepNumber: '2',
          text:
              'Enter Course Name, Code (e.g. CSE 101), Room number, and Day & Time.',
          c: c,
        ),
        const SizedBox(height: 8),
        _ProcessStep(
          stepNumber: '3',
          text:
              'Tap Save. Uniro sends alarms before class & enables 1-tap attendance.',
          c: c,
        ),
        const SizedBox(height: 12),

        // Real visual example routine slot
        Text(
          'REAL EXAMPLE:',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: c.textTertiary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.pageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Data Structures & Algorithms',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE59435).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CSE 101',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE59435),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Room 402 • 10:00 AM – 11:30 AM (Monday)',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _AttendanceDemoChip(label: '✓ Present', isPresent: true, c: c),
                  const SizedBox(width: 8),
                  _AttendanceDemoChip(label: '✗ Absent', isPresent: false, c: c),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.stepNumber,
    required this.text,
    required this.c,
  });

  final String stepNumber;
  final String text;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFE59435).withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            stepNumber,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE59435),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5,
              color: c.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c.textPrimary : c.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _AttendanceDemoChip extends StatelessWidget {
  const _AttendanceDemoChip({
    required this.label,
    required this.isPresent,
    required this.c,
  });

  final String label;
  final bool isPresent;
  final AppColors c;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPresent
            ? const Color(0xFF5A8A5A).withValues(alpha: 0.16)
            : const Color(0xFFD94F3D).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF5A8A5A).withValues(alpha: 0.35)
              : const Color(0xFFD94F3D).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isPresent ? const Color(0xFF5A8A5A) : const Color(0xFFD94F3D),
        ),
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
      size: const Size(18, 9),
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
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
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

// ─── Shared Dots & Buttons ────────────────────────────────────────────────────

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
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: active ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFE59435)
                : c.textSecondary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2.5),
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
              fontSize: 13.5,
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
              fontSize: compact ? 15 : 13.5,
            ),
          ),
        ),
      );
    }
  }
}
