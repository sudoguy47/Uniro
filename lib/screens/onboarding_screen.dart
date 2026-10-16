import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app/app_shell.dart';
import '../domain/haptics.dart';
import '../services/local_store.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/onboarding_mascots.dart';
import '../widgets/uniro_logo.dart';

/// Native Uniro onboarding matching the brand mocks:
/// orange grad → blue calendar → green name → purple reminders.
/// Mascots are animated CustomPainters (bob + blink + swing) — no assets,
/// no new dependencies, 60/120fps on a single small repaint layer.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  int _currentPage = 0;
  bool _notificationsEnabled = false;

  static const _slideColors = [
    Color(0xFFD97E36), // grad
    Color(0xFF3E6FA8), // calendar
    Color(0xFF4C7A5B), // name
    Color(0xFF8B5E9E), // reminders
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _requestNotifications() async {
    PremiumHaptics.tap();
    final granted = await NotificationService.instance.requestPermissions();
    if (mounted) setState(() => _notificationsEnabled = granted);
    if (granted) PremiumHaptics.confirm();
  }

  Future<void> _finishOnboarding() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final app = context.read<AppState>();
    final name = _nameController.text.trim();

    app.updateSettings(
      app.settings.copyWith(
        name: name.isNotEmpty ? name : 'Student',
        notificationsEnabled: _notificationsEnabled,
      ),
    );

    LocalStore.instance.setOnboardingDone(true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, anim, secAnim) => AppShell(
          key: AppShell.shellKey,
        ),
        transitionsBuilder: (context, anim, secAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _next() {
    // Hide the keyboard first so it never lingers over the next slide,
    // then give the press its tick.
    FocusManager.instance.primaryFocus?.unfocus();
    PremiumHaptics.tap();
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _slideColors[_currentPage],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Brand
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const UniroLogo(size: 28),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Uniro',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Slides
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (page) {
                    // Swiped slides must also drop the keyboard (the name
                    // field keeps focus otherwise and covers the next slide).
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _currentPage = page);
                    SystemChrome.setSystemUIOverlayStyle(
                      const SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.light,
                        statusBarBrightness: Brightness.dark,
                      ),
                    );
                  },
                  children: [
                    const _MascotSlide(
                      mascot: GradMascot(),
                      title: 'GET YOUR\nCAMPUS TASKS\nDONE.',
                      sub: 'Stay on top of every deadline,\nstress-free.',
                    ),
                    const _MascotSlide(
                      mascot: CalendarMascot(),
                      title: 'NEVER MISS\nA DEADLINE\nAGAIN.',
                      sub: 'Visual calendar keeps every\ndue date in one place.',
                    ),
                    _NameSlide(
                      controller: _nameController,
                      onSubmitted: _next,
                    ),
                    _ReminderSlide(
                      enabled: _notificationsEnabled,
                      onEnable: _requestNotifications,
                    ),
                  ],
                ),
              ),

              // Dots
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 6),
                child: Row(
                  children: List.generate(4, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 7),
                      width: active ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),

              // Bottom bar: Next / Let's Start + arrow, right-aligned.
              // The action group shrink-fits so "Let's Start" can never
              // push past 320dp at large text scales.
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 28, 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _next,
                            behavior: HitTestBehavior.opaque,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == 3 ? "Let's Start" : 'Next',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.18),
                                    border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.65),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slides 1–2: mascot in a lighter circle + headline + sub.
class _MascotSlide extends StatelessWidget {
  const _MascotSlide({
    required this.mascot,
    required this.title,
    required this.sub,
  });

  final Widget mascot;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      // Narrow phones wrap the 33px caps lines (designed at 390dp), so
      // drop to 29px under 360dp to keep the intended 3-line shape.
      final titleSize = cons.maxWidth < 360 ? 29.0 : 33.0;
      return Column(
        children: [
          const SizedBox(height: 8),
          // Mascot stage: lighter circle backdrop. Shrinks (never grows) on
          // short screens so the copy below can never be pushed off.
          Expanded(
            flex: 5,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  alignment: Alignment.center,
                  child: SizedBox(width: 190, height: 205, child: mascot),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleSize,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 15.5,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Slide 3: name input with floating doodles (no mascot circle, per mock).
class _NameSlide extends StatelessWidget {
  const _NameSlide({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Floating doodles at the edges, like the mock
        const Positioned(
          top: 6,
          left: 18,
          child: Opacity(
            opacity: 0.55,
            child: DoodleFloater(
              phase: 0,
              child: PencilDoodle(),
            ),
          ),
        ),
        const Positioned(
          top: 150,
          left: 34,
          child: Opacity(
            opacity: 0.5,
            child: DoodleFloater(
              phase: 2.1,
              periodMs: 3800,
              child: MiniCapDoodle(),
            ),
          ),
        ),
        const Positioned(
          bottom: 40,
          right: 26,
          child: Opacity(
            opacity: 0.55,
            child: DoodleFloater(
              phase: 4.2,
              periodMs: 2900,
              child: BooksDoodle(),
            ),
          ),
        ),
        // Copy + input
        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 28),
                const Text(
                  "WHAT'S\nYOUR\nNAME?",
                  style: TextStyle(
                    fontSize: 33,
                    height: 1.04,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "We'll personalise your experience.",
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmitted(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your name...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.18),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Slide 4: bell mascot + enable-reminders CTA.
class _ReminderSlide extends StatelessWidget {
  const _ReminderSlide({required this.enabled, required this.onEnable});

  final bool enabled;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final titleSize = cons.maxWidth < 360 ? 29.0 : 33.0;
      return Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 5,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  width: 270,
                  height: 270,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  alignment: Alignment.center,
                  child: const SizedBox(
                      width: 190, height: 205, child: BellMascot()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 6,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GET REMINDERS\nBEFORE IT\'S\nTOO LATE.',
                        style: TextStyle(
                          fontSize: titleSize,
                          height: 1.04,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Smart alerts keep you ahead.',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 14),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: onEnable,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.65),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  enabled
                                      ? Icons.check_circle_rounded
                                      : Icons.notifications_outlined,
                                  size: 20,
                                  color: enabled
                                      ? Colors.white
                                      : const Color(0xFF8B5E9E),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  enabled
                                      ? 'Reminders On'
                                      : 'Enable Reminders',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: enabled
                                        ? Colors.white
                                        : const Color(0xFF8B5E9E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
