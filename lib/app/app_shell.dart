import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../screens/dashboard_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/done_screen.dart';
import '../screens/profile_screen.dart';

enum AppRoute { dashboard, calendar, done, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppRoute _route = AppRoute.dashboard;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _route.index);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      app.persistNow();
    }
  }

  void _navigate(AppRoute route) {
    if (route == _route) return;
    setState(() {
      _route = route;
    });
    _pageController.jumpToPage(route.index);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final isNewTaskOpen = context.select((AppState s) => s.isNewTaskOpen);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          // ── Scrollable Pages ───────────────────────────────────────────
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              DashboardScreen(
                onNavigateToProfile: () => _navigate(AppRoute.profile),
              ),
              const CalendarScreen(),
              const DoneScreen(),
              const ProfileScreen(),
            ],
          ),

          // ── Truly Floating Navigation Bar ──────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            left: 20,
            right: 20,
            bottom: isNewTaskOpen ? -120 : (16 + bottomInset),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isNewTaskOpen ? 0.0 : 1.0,
              child: _BottomBar(current: _route, onTap: _navigate),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onTap});
  final AppRoute current;
  final void Function(AppRoute) onTap;

  static const double _dockHeight = 64.0;
  static const double _pillHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idx = AppRoute.values.indexOf(current);

    final borderColor =
        isDark ? const Color(0x22FFFFFF) : const Color(0x14000000);

    return Container(
      height: _dockHeight,
      decoration: BoxDecoration(
        color: c.cardBg.withValues(alpha: isDark ? 0.94 : 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 1,
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final totalWidth = constraints.maxWidth;
          final slotWidth = totalWidth / AppRoute.values.length;
          final pillWidth = math.min(slotWidth - 8.0, 72.0);
          final slotX = (slotWidth * idx) + (slotWidth - pillWidth) / 2;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Active sliding pill indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: slotX,
                top: (_dockHeight - _pillHeight) / 2,
                width: pillWidth,
                height: _pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFFF5F2EB)
                        : const Color(0xFF1E1B18),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Navigation tab items
              Row(
                children: AppRoute.values.map((route) {
                  final isActive = route == current;
                  final activeFg =
                      isDark ? const Color(0xFF1E1B18) : Colors.white;
                  const inactiveFg = Color(0xFF9E9589);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTap(route);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        height: _dockHeight,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TweenAnimationBuilder<Color?>(
                              duration: const Duration(milliseconds: 200),
                              tween: ColorTween(
                                begin: inactiveFg,
                                end: isActive ? activeFg : inactiveFg,
                              ),
                              builder: (_, color, __) => Icon(
                                isActive
                                    ? _fillIcon(route)
                                    : _outlineIcon(route),
                                size: 21,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive ? activeFg : inactiveFg,
                              ),
                              child: Text(
                                _label(route),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _fillIcon(AppRoute r) => switch (r) {
        AppRoute.dashboard => Icons.grid_view_rounded,
        AppRoute.calendar => Icons.calendar_month_rounded,
        AppRoute.done => Icons.check_circle_rounded,
        AppRoute.profile => Icons.person_rounded,
      };

  IconData _outlineIcon(AppRoute r) => switch (r) {
        AppRoute.dashboard => Icons.grid_view_outlined,
        AppRoute.calendar => Icons.calendar_month_outlined,
        AppRoute.done => Icons.check_circle_outline_rounded,
        AppRoute.profile => Icons.person_outline_rounded,
      };

  String _label(AppRoute r) => switch (r) {
        AppRoute.dashboard => 'Dashboard',
        AppRoute.calendar => 'Calendar',
        AppRoute.done => 'Done',
        AppRoute.profile => 'Profile',
      };
}
