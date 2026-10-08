import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/notes_state.dart';
import '../theme/app_colors.dart';
import '../screens/dashboard_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/done_screen.dart';
import '../screens/profile_screen.dart';

enum AppRoute { dashboard, calendar, notes, done, profile }

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
      if (mounted) {
        context.read<NotesState>().flush();
      }
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
              const NotesScreen(),
              const DoneScreen(),
              const ProfileScreen(),
            ],
          ),

          // ── Simple Docked Navigation Bar ──────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              offset: isNewTaskOpen ? const Offset(0, 1.2) : Offset.zero,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _SimpleBottomNavBar(
                current: _route,
                onTap: _navigate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleBottomNavBar extends StatelessWidget {
  const _SimpleBottomNavBar({
    required this.current,
    required this.onTap,
  });

  final AppRoute current;
  final ValueChanged<AppRoute> onTap;

  static const double _barContentHeight = 58.0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(
          top: BorderSide(
            color: c.border.withValues(alpha: 0.65),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        height: _barContentHeight,
        child: Row(
          children: AppRoute.values.map((route) {
            final isActive = route == current;
            final activeColor = c.accent;
            final inactiveColor = c.navInactive;

            return Expanded(
              child: InkResponse(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTap(route);
                },
                containedInkWell: true,
                highlightShape: BoxShape.rectangle,
                splashColor: c.accent.withValues(alpha: 0.12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isActive ? _fillIcon(route) : _outlineIcon(route),
                      size: 24,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _label(route),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? activeColor : inactiveColor,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _fillIcon(AppRoute r) => switch (r) {
        AppRoute.dashboard => Icons.grid_view_rounded,
        AppRoute.calendar => Icons.calendar_month_rounded,
        AppRoute.notes => Icons.description,
        AppRoute.done => Icons.check_circle_rounded,
        AppRoute.profile => Icons.person_rounded,
      };

  IconData _outlineIcon(AppRoute r) => switch (r) {
        AppRoute.dashboard => Icons.grid_view_outlined,
        AppRoute.calendar => Icons.calendar_month_outlined,
        AppRoute.notes => Icons.description_outlined,
        AppRoute.done => Icons.check_circle_outline_rounded,
        AppRoute.profile => Icons.person_outline_rounded,
      };

  String _label(AppRoute r) => switch (r) {
        AppRoute.dashboard => 'Dashboard',
        AppRoute.calendar => 'Calendar',
        AppRoute.notes => 'Notes',
        AppRoute.done => 'Done',
        AppRoute.profile => 'Profile',
      };
}
