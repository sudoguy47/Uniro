# 03. main.dart & AppShell (GymMane Exact Pattern)

> GymMane-এর সবচেয়ে গুরুত্বপূর্ণ দুটো ফাইল।
> এখানে **exact same code structure** follow করতে হবে।

---

## main.dart (GymMane main.dart)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'services/local_store.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  // ① Flutter binding init
  WidgetsFlutterBinding.ensureInitialized();

  // ② GymMane: edge-to-edge BEFORE widget tree builds
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:                    Colors.transparent,
    systemNavigationBarColor:          Colors.transparent,
    systemNavigationBarDividerColor:   Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced:   false,
  ));

  // ③ Portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ④ GymMane: await Store.instance.init() — disk cache load
  await LocalStore.instance.init();

  // ⑤ GymMane: fit.loadFromStore() — hydrate all state into RAM
  app.loadFromStore();

  // ⑥ Notifications init
  await NotificationService.instance.init();

  // ⑦ Date formatting
  await initializeDateFormatting();

  // ⑧ runApp — first frame = real UI (no skeleton flash)
  runApp(
    ChangeNotifierProvider.value(
      value: app,
      child: const CampusTrackerApp(),
    ),
  );

  // ⑨ GymMane: addPostFrameCallback — secondary work AFTER first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // Re-schedule any pending notification reminders
    NotificationService.instance.rescheduleAll(app.tasks);
  });
}
```

---

## app/app.dart

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_shell.dart';

class CampusTrackerApp extends StatelessWidget {
  const CampusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final isDark = s.settings.theme == ThemeMode.dark ||
        (s.settings.theme == ThemeMode.system &&
         MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final colors = isDark ? AppColors.dark : AppColors.light;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(colors, Brightness.light),
      darkTheme: AppTheme.build(AppColors.dark, Brightness.dark),
      themeMode: s.settings.theme,
      home: const AppShell(),
    );
  }
}
```

---

## app/app_shell.dart (GymMane app_shell.dart — most critical)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../screens/dashboard_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/done_screen.dart';
import '../screens/profile_screen.dart';

enum AppRoute { dashboard, calendar, done, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  AppRoute _route     = AppRoute.dashboard;
  AppRoute _prevRoute = AppRoute.dashboard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // GymMane: didChangeAppLifecycleState — flush on background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      app.persistNow(); // Immediate disk write on app background
    }
  }

  void _navigate(AppRoute route) {
    if (route == _route) return;
    setState(() {
      _prevRoute = _route;
      _route = route;
    });
  }

  Widget _screen() {
    return switch (_route) {
      AppRoute.dashboard => const DashboardScreen(),
      AppRoute.calendar  => const CalendarScreen(),
      AppRoute.done      => const DoneScreen(),
      AppRoute.profile   => const ProfileScreen(),
    };
  }

  bool get _sideways => true; // always lateral animation
  int _routeIndex(AppRoute r) => AppRoute.values.indexOf(r);
  int get _dir => _routeIndex(_route) > _routeIndex(_prevRoute) ? 1 : -1;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Column(
        children: [
          // ── GymMane AnimatedSwitcher: double-buffered screen transitions ──
          Expanded(
            child: AnimatedSwitcher(
              duration: AppTheme.screen,  // 260ms
              // Outgoing: starts fading at 60% of timeline
              switchOutCurve: AppTheme.switchOut, // Interval(0.6, 1.0)
              // Incoming: starts appearing at 30% of timeline
              switchInCurve:  AppTheme.switchIn,  // Interval(0.3, 1.0)
              transitionBuilder: (child, animation) {
                final incoming =
                    (child.key as ValueKey?)?.value == _route;
                final offset = incoming
                    ? Offset(0.08 * _dir, 0)
                    : Offset(-0.08 * _dir, 0);
                final slide = Tween<Offset>(
                  begin: incoming ? offset : Offset.zero,
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ));
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              // GymMane layoutBuilder: hold outgoing in Stack
              layoutBuilder: (current, previous) => Stack(
                children: [
                  ...previous.map((p) => Positioned.fill(child: p)),
                  if (current != null) Positioned.fill(child: current),
                ],
              ),
              child: KeyedSubtree(
                key: ValueKey(_route),
                child: _screen(),
              ),
            ),
          ),
          // ── Custom Bottom Bar ──
          _BottomBar(current: _route, onTap: _navigate),
        ],
      ),
    );
  }
}

// ── GymMane _NavBar equivalent ─────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.current, required this.onTap});
  final AppRoute current;
  final void Function(AppRoute) onTap;

  static const _iw = 80.0;  // pill width
  static const _ih = 48.0;  // pill height

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final idx = AppRoute.values.indexOf(current);

    return Container(
      decoration: BoxDecoration(
        color: c.navBg,
        border: Border(top: BorderSide(color: c.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(builder: (ctx, constraints) {
            final w = constraints.maxWidth;
            final slotW = w / 4;

            // GymMane: algebraic slot math — zero layout queries
            double slotX(int i) => i * slotW + (slotW - _iw) / 2;

            return Stack(
              alignment: Alignment.center,
              children: [
                // GymMane AnimatedPositioned pill — 340ms easeOutCubic
                AnimatedPositioned(
                  duration: AppTheme.navGlide, // 340ms
                  curve: AppTheme.easeOutCubic,
                  left: slotX(idx),
                  top: (64 - _ih) / 2,
                  width: _iw,
                  height: _ih,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.navActiveBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // Tab items
                Row(
                  children: AppRoute.values.asMap().entries.map((e) {
                    final isActive = e.value == current;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onTap(e.value);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // GymMane TweenAnimationBuilder for icon color
                            TweenAnimationBuilder<double>(
                              duration: AppTheme.fast, // 200ms
                              tween: Tween(end: isActive ? 1.0 : 0.0),
                              builder: (_, v, __) {
                                final color = Color.lerp(
                                  c.navInactive, c.navActiveText, v)!;
                                return Icon(
                                  isActive
                                    ? _fillIcon(e.value)
                                    : _outlineIcon(e.value),
                                  color: color, size: 22,
                                );
                              },
                            ),
                            const SizedBox(height: 3),
                            TweenAnimationBuilder<double>(
                              duration: AppTheme.fast,
                              tween: Tween(end: isActive ? 1.0 : 0.0),
                              builder: (_, v, __) => Text(
                                _label(e.value),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color.lerp(
                                    c.navInactive, c.navActiveText, v),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  IconData _fillIcon(AppRoute r) => switch (r) {
    AppRoute.dashboard => Icons.grid_view_rounded,
    AppRoute.calendar  => Icons.calendar_month_rounded,
    AppRoute.done      => Icons.check_circle_rounded,
    AppRoute.profile   => Icons.person_rounded,
  };

  IconData _outlineIcon(AppRoute r) => switch (r) {
    AppRoute.dashboard => Icons.grid_view_outlined,
    AppRoute.calendar  => Icons.calendar_month_outlined,
    AppRoute.done      => Icons.check_circle_outline_rounded,
    AppRoute.profile   => Icons.person_outline_rounded,
  };

  String _label(AppRoute r) => switch (r) {
    AppRoute.dashboard => 'Dashboard',
    AppRoute.calendar  => 'Calendar',
    AppRoute.done      => 'Done',
    AppRoute.profile   => 'Profile',
  };
}
```
