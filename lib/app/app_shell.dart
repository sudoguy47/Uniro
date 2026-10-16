import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/haptics.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/focus_state.dart';
import '../state/notes_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import '../screens/dashboard_screen.dart';
import '../screens/routine_screen.dart';
import '../screens/focus_screen.dart';
import '../screens/notes/notes_screen.dart';
import '../screens/profile_screen.dart';

/// Named tab identifiers (no magic indexes). There is no persisted tab
/// anywhere in the app (route lives in memory only), so no old-index
/// migration was needed when Calendar/Done left the bar.
enum AppTab { dashboard, routine, focus, notes, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialTab = AppTab.dashboard});
  final AppTab initialTab;

  /// Global access for notification taps / drawer / deep links.
  static final GlobalKey _shellKey = GlobalKey();

  static GlobalKey get shellKey => _shellKey;

  static void openTab(AppTab tab) =>
      (_shellKey.currentState as _AppShellState?)?.openTab(tab);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppTab _tab = AppTab.dashboard;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = widget.initialTab;
    _pageController = PageController(initialPage: _tab.index);
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
    if (state == AppLifecycleState.resumed && mounted) {
      // Timezone / clock may have changed while away: refresh only when
      // the native flag or zone id says so. Fire-and-forget, never throws.
      try {
        final appState = context.read<AppState>();
        RoutineState? routine;
        try {
          routine = context.read<RoutineState>();
        } catch (_) {
          routine = null;
        }
        if (routine != null) {
          NotificationService.instance.checkAndRescheduleIfNeeded(
            tasks: appState.tasks,
            courses: routine.courses,
            slots: routine.slots,
            name: appState.settings.name,
            enabled: appState.settings.notificationsEnabled,
          );
        }
        // The user may have toggled system touch feedback or changed
        // devices settings while away: re-prime the haptic cache.
        HapticsCapabilities.refresh();
      } catch (_) {}
    }
  }

  void openTab(AppTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _pageController.jumpToPage(tab.index);
  }

  void _navigate(AppTab tab) => openTab(tab);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final isNewTaskOpen = context.select((AppState s) => s.isNewTaskOpen);
    // Immersive focus run: hide the bottom nav while the timer ticks so
    // the tab owns the whole screen. Pausing brings it back; it hides
    // again on resume. Restored automatically when the run ends.
    final focusRunning =
        context.select((FocusState f) => f.running && !f.paused);

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
                onNavigateToProfile: () => _navigate(AppTab.profile),
                onNavigateToRoutine: () => _navigate(AppTab.routine),
              ),
              const RoutineScreen(),
              const FocusScreen(),
              const NotesScreen(),
              const ProfileScreen(),
            ],
          ),

          // ── Simple Docked Navigation Bar (hidden while focus ticks) ──
          if (!focusRunning)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedSlide(
                offset: isNewTaskOpen ? const Offset(0, 1.2) : Offset.zero,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: RepaintBoundary(
                  child: _BottomNavBar(
                    current: _tab,
                    onTap: _navigate,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.current,
    required this.onTap,
  });

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  static const double _barContentHeight = 68.0;

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
          children: AppTab.values.map((tab) {
            final isActive = tab == current;
            final inactiveColor = c.navInactive;

            return Expanded(
              child: Semantics(
                button: true,
                label: _label(tab),
                selected: isActive,
                child: _NavItem(
                  active: isActive,
                  icon: Icon(
                    isActive ? _fillIcon(tab) : _outlineIcon(tab),
                    size: 27,
                    color: isActive ? c.accent : inactiveColor,
                  ),
                  label: FittedBox(
                    // Shrink-to-fit instead of ellipsis: full labels stay
                    // readable at 320dp / text scale 1.3, never overflow.
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _label(tab),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive ? c.accent : inactiveColor,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  onTap: () {
                    // Navbar stays whisper-light: selection click only.
                    PremiumHaptics.select();
                    onTap(tab);
                  },
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _fillIcon(AppTab t) => switch (t) {
        AppTab.dashboard => Icons.grid_view_rounded,
        AppTab.routine => Icons.calendar_month_rounded,
        AppTab.focus => Icons.timer_rounded,
        AppTab.notes => Icons.description,
        AppTab.profile => Icons.person_rounded,
      };

  IconData _outlineIcon(AppTab t) => switch (t) {
        AppTab.dashboard => Icons.grid_view_outlined,
        AppTab.routine => Icons.calendar_month_outlined,
        AppTab.focus => Icons.timer_outlined,
        AppTab.notes => Icons.description_outlined,
        AppTab.profile => Icons.person_outline_rounded,
      };

  String _label(AppTab t) => switch (t) {
        AppTab.dashboard => 'Dashboard',
        AppTab.routine => 'Routine',
        AppTab.focus => 'Focus',
        AppTab.notes => 'Notes',
        AppTab.profile => 'Profile',
      };
}

/// One nav item: icon scale-pops on activation, label fades in.
class _NavItem extends StatefulWidget {  const _NavItem({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final Widget icon;
  final Widget label;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _NavItem old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: widget.onTap,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      splashColor: Theme.of(context)
          .extension<AppColors>()!
          .accent
          .withValues(alpha: 0.12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(scale: _scale, child: widget.icon),
            const SizedBox(height: 5),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.active ? 1.0 : 0.55,
              child: widget.label,
            ),
          ],
        ),
      ),
    );
  }
}
