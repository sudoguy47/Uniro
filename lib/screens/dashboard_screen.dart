import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../models/task.dart';
import '../widgets/task_card.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/ui_kit.dart';
import '../domain/greetings.dart';
import '../domain/quotes.dart';
import '../domain/task_utils.dart';
import '../widgets/class_form_sheet.dart';
import '../widgets/next_class_card.dart';
import '../screens/done_screen.dart';
import '../widgets/new_task_sheet.dart';

/// Highly optimized Dashboard Screen.
///
/// Performance Optimizations:
/// 1. Layout calculation overhead eliminated via `SliverFixedExtentList` using `TaskCard.totalItemExtent`.
/// 2. Prototype item specified on horizontal chip list to eliminate dynamic layout measurement.
/// 3. Granular state selectors (`context.select`) strictly scope rebuilds so scrolling
///    and state changes re-render only the affected subtrees instead of the entire screen.
/// 4. ValueListenableBuilder isolates NewTaskSheet and FAB animations from the scrollable tree.
/// 5. RepaintBoundaries isolate GPU compositing layers across dashboard sections.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen(
      {super.key, this.onNavigateToProfile, this.onNavigateToRoutine});
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToRoutine;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  // ValueNotifier isolates sheet open/close animations.
  // Completely prevents rebuilding headers, carousels, charts, or task lists.
  final ValueNotifier<bool> _showNewTaskNotifier = ValueNotifier<bool>(false);
  final GlobalKey _plusKey = GlobalKey();
  OverlayEntry? _plusOverlay;
  bool _plusOpen = false;
  bool _completedSeen = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.read<AppState>().settings.dashboardView == 'completed') {
      _completedSeen = true;
    }
  }

  @override
  void dispose() {
    _plusOverlay?.remove();
    _showNewTaskNotifier.dispose();
    super.dispose();
  }

  void _openNewTask() {
    HapticFeedback.lightImpact();
    context.read<AppState>().setNewTaskOpen(true);
    _showNewTaskNotifier.value = true;
  }

  void _togglePlus() {
    if (_plusOpen) {
      _closePlus();
      return;
    }
    final box =
        _plusKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final pos = box.localToGlobal(Offset.zero);
    HapticFeedback.selectionClick();
    setState(() => _plusOpen = true);
    _plusOverlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closePlus,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            top: pos.dy + box.size.height + 8,
            right: 16,
            child: _CreatePopover(
              onCreateTask: () {
                _closePlus();
                _openNewTask();
              },
              onAddClass: () {
                _closePlus();
                showClassFormSheet(context);
              },
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_plusOverlay!);
  }

  void _closePlus() {
    _plusOverlay?.remove();
    _plusOverlay = null;
    if (mounted) setState(() => _plusOpen = false);
  }

  void _setView(String view) {
    final app = context.read<AppState>();
    if (view == 'completed') setState(() => _completedSeen = true);
    app.updateSettings(app.settings.copyWith(dashboardView: view));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;
    final completed =
        context.select((AppState s) => s.settings.dashboardView) ==
            'completed';

    return PopScope(
      canPop: !_plusOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _plusOpen) _closePlus();
      },
      child: Scaffold(
        backgroundColor: c.pageBg,
        body: Stack(
          children: [
            Column(
              children: [
                // FIXED / STICKY HEADER AT TOP (Isolated Rebuild Scope)
                _DashboardHeader(
                  onNavigateToProfile: widget.onNavigateToProfile,
                  onPlus: _togglePlus,
                  plusKey: _plusKey,
                  plusOpen: _plusOpen,
                ),

                // Feed: Active scrolls with the toggle after the weekly
                // chart; Completed shows toggle + done list.
                Expanded(
                  child: completed
                      ? Column(
                          children: [
                            _ViewToggle(
                              completed: completed,
                              onChanged: _setView,
                            ),
                            Expanded(
                              child: _completedSeen
                                  ? const DoneScreen()
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        )
                      : CustomScrollView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: NextClassCard(
                                onTap: () =>
                                    widget.onNavigateToRoutine?.call(),
                              ),
                            ),
                            const SliverToBoxAdapter(child: _HeroSection()),
                            const SliverToBoxAdapter(
                                child: _WeeklyLoadSection()),
                            SliverToBoxAdapter(
                              child: _ViewToggle(
                                completed: completed,
                                onChanged: _setView,
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: _FilterChipsSection()),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 12)),
                            const _TaskListSection(),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 100)),
                          ],
                        ),
                ),
              ],
            ),

            // ValueListenableBuilder isolates NewTaskSheet rebuilds from the dashboard tree
            ValueListenableBuilder<bool>(
              valueListenable: _showNewTaskNotifier,
              builder: (context, show, child) {
                if (!show) return const SizedBox.shrink();
                return NewTaskSheet(
                  onClose: () {
                    context.read<AppState>().setNewTaskOpen(false);
                    _showNewTaskNotifier.value = false;
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// "+" popover: Create task / Add class routine. 180ms scale+fade with
/// 25ms stagger (120ms plain fade on reduce-motion). Tap outside or Back
/// closes it.
class _CreatePopover extends StatefulWidget {
  const _CreatePopover({
    required this.onCreateTask,
    required this.onAddClass,
  });

  final VoidCallback onCreateTask;
  final VoidCallback onAddClass;

  @override
  State<_CreatePopover> createState() => _CreatePopoverState();
}

class _CreatePopoverState extends State<_CreatePopover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    final reduce = MediaQuery.disableAnimationsOf(context);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: reduce ? 120 : 180),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scale = reduce
        ? const AlwaysStoppedAnimation<double>(1.0)
        : CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    return ScaleTransition(
      scale: scale,
      alignment: Alignment.topRight,
      child: FadeTransition(
        opacity: _ctrl,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: c.cardBg,
          child: Container(
            width: 220,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _popItem(
                  context,
                  c,
                  delay: 0,
                  icon: Icons.add_task_outlined,
                  label: 'Create task',
                  onTap: widget.onCreateTask,
                ),
                _popItem(
                  context,
                  c,
                  delay: 1,
                  icon: Icons.calendar_month_outlined,
                  label: 'Add class routine',
                  onTap: widget.onAddClass,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _popItem(
    BuildContext context,
    AppColors c, {
    required int delay,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget row = InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c.accent),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
    if (reduce) {
      return row;
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final t = (_ctrl.value * 2 - delay * 0.25).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
      child: row,
    );
  }
}

/// Compact Active | Completed segmented toggle.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.completed, required this.onChanged});
  final bool completed;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    Widget seg(String label, bool active, String value) {
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if ((value == 'completed') == completed) return;
            HapticFeedback.selectionClick();
            onChanged(value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 36,
            decoration: BoxDecoration(
              color: active ? c.navActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? c.navActiveText : c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            seg('Active', !completed, 'active'),
            seg('Completed', completed, 'completed'),
          ],
        ),
      ),
    );
  }
}

/// Header Widget — time-aware greeting + subtitle, with a swipe-up-to-reveal
/// daily motivation line. Listens ONLY to specific settings (name, avatarUri).
class _DashboardHeader extends StatefulWidget {
  const _DashboardHeader({
    this.onNavigateToProfile,
    this.onPlus,
    this.plusKey,
    this.plusOpen = false,
  });
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onPlus;
  final GlobalKey? plusKey;
  final bool plusOpen;

  @override
  State<_DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<_DashboardHeader> {
  bool _showQuote = false;
  double _dragAccum = 0;
  Timer? _cycleTimer;
  Timer? _slotTimer;
  int _slot = -1;

  @override
  void initState() {
    super.initState();
    _slot = quoteSlotIndex(DateTime.now());
    // Greeting ⇄ quote alternate automatically every 4 seconds.
    _restartCycle();
    // A new quote every 10 minutes: refresh when the slot rolls over.
    _slotTimer =
        Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      final s = quoteSlotIndex(DateTime.now());
      if (s != _slot) setState(() => _slot = s);
    });
  }

  void _restartCycle() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _showQuote = !_showQuote);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _slotTimer?.cancel();
    super.dispose();
  }

  void _manualToggle() {
    HapticFeedback.selectionClick();
    setState(() => _showQuote = !_showQuote);
    _restartCycle();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    _dragAccum += d.primaryDelta ?? 0;
    // Swipe up reveals the quote, swipe down restores the greeting.
    if (_dragAccum <= -48 && !_showQuote) {
      _dragAccum = 0;
      _manualToggle();
    } else if (_dragAccum >= 48 && _showQuote) {
      _dragAccum = 0;
      _manualToggle();
    }
  }

  void _onVerticalDragEnd(DragEndDetails _) => _dragAccum = 0;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    // Fine-grained selectors isolate rebuilds from unrelated settings changes
    final name = context.select((AppState s) => s.settings.name);
    final avatarUri = context.select((AppState s) => s.settings.avatarUri);
    final now = DateTime.now();
    // First name only — full names ("Sreyas Chowhan") overflow one line
    // and get clipped with "...".
    final firstName = name.split(' ').firstWhere(
          (w) => w.trim().isNotEmpty,
          orElse: () => name,
        );
    final greetingHead = greetingHeadline(now);
    final greetingEmoji = greetingEmojiFor(now);
    final quote = quoteForSlot(now);

    return RepaintBoundary(
      child: Container(
        color: c.pageBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    onTap: () {
                      // Manual toggle restarts the 4s auto-cycle so it
                      // never fights the user.
                      _manualToggle();
                    },
                    behavior: HitTestBehavior.opaque,
                    // Fixed height: greeting ⇄ quote swaps never push the
                    // content below up/down.
                    child: SizedBox(
                      height: 66,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _showQuote
                            ? Column(
                                key: const ValueKey('quote'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'DAILY FUEL',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: c.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '\u201C$quote\u201D',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ],
                              )
                            // Two-line greeting: time-based head on line 1,
                            // student name on line 2.
                            : Align(
                                key: const ValueKey('greeting'),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      greetingHead,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$firstName!$greetingEmoji',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        color: c.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onNavigateToProfile?.call();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: UserAvatar(
                    avatarUri: avatarUri,
                    name: name,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 10),
                // "+" quick-create button (44px accent circle).
                GestureDetector(
                  key: widget.plusKey,
                  onTap: widget.onPlus,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AnimatedRotation(
                      turns: widget.plusOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero Carousel Section - Listens ONLY to memoized heroTasks
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final hero = context.select((AppState s) => s.heroTasks);
    if (hero.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: HeroCarousel(tasks: hero),
      ),
    );
  }
}

/// Weekly Load Section — single chart, weeks beginning on the week-start
/// setting. Routine lives in its own tab now.
class _WeeklyLoadSection extends StatelessWidget {
  const _WeeklyLoadSection();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final weekStart =
        context.select((AppState s) => s.settings.weekStartDay);
    final monday = weekStartString(DateTime.now(), weekStart);
    final weeklyLoad = context.select((AppState s) => s.weeklyLoad(monday));
    final pendingCount =
        context.select((AppState s) => s.pendingTasks.length);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly load',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  '$pendingCount due this week',
                  style: TextStyle(
                    fontSize: 13,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WeeklyBarChart(
              weekStart: monday,
              load: weeklyLoad,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter Chips Section - Listens ONLY to activeFilter & specifies prototypeItem for ListView
class _FilterChipsSection extends StatelessWidget {
  const _FilterChipsSection();

  static const List<TaskType?> _filterTypes = [
    null,
    ...TaskType.values,
  ];

  static const _chipPadding = EdgeInsets.only(right: 8);

  @override
  Widget build(BuildContext context) {
    final activeFilter = context.select((AppState s) => s.activeFilter);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filterTypes.length,
          itemBuilder: (context, index) {
            final type = _filterTypes[index];
            final label = type == null
                ? 'All'
                : type.name[0].toUpperCase() + type.name.substring(1);
            final active = activeFilter == type;

            return Padding(
              padding: _chipPadding,
              child: AppFilterChip(
                label: label,
                active: active,
                onTap: () => context.read<AppState>().setFilter(type),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Task List Section - Uses SliverFixedExtentList for O(1) layout calculations
class _TaskListSection extends StatelessWidget {
  const _TaskListSection();

  @override
  Widget build(BuildContext context) {
    final pendingTasks = context.select((AppState s) => s.pendingTasks);

    if (pendingTasks.isEmpty) {
      final c = Theme.of(context).extension<AppColors>()!;
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'No pending tasks',
              style: TextStyle(
                fontSize: 14,
                color: c.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Specifying itemExtent eliminates dynamic layout measurement during vertical fling scrolls
      sliver: SliverFixedExtentList.builder(
        itemExtent: TaskCard.totalItemExtent,
        itemCount: pendingTasks.length,
        itemBuilder: (context, index) {
          final t = pendingTasks[index];
          return TaskCard(
            key: ValueKey(t.id),
            task: t,
            onComplete: () =>
                context.read<AppState>().completeTask(t.id),
          );
        },
      ),
    );
  }
}
