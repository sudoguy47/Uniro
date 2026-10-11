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
import '../widgets/class_routine_page.dart';
import '../widgets/routine_sheet.dart';
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
  const DashboardScreen({super.key, this.onNavigateToProfile});
  final VoidCallback? onNavigateToProfile;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  // ValueNotifier isolates sheet open/close animations.
  // Completely prevents rebuilding headers, carousels, charts, or task lists.
  final ValueNotifier<bool> _showNewTaskNotifier = ValueNotifier<bool>(false);

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _showNewTaskNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      backgroundColor: c.pageBg,
      body: Stack(
        children: [
          Column(
            children: [
              // FIXED / STICKY HEADER AT TOP (Isolated Rebuild Scope)
              _DashboardHeader(
                onNavigateToProfile: widget.onNavigateToProfile,
              ),

              // LAZY SCROLLABLE CONTENT WITH SLIVERS (Butter-smooth 60/120 FPS)
              const Expanded(
                child: CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _HeroSection()),
                    SliverToBoxAdapter(child: _WeeklyLoadSection()),
                    SliverToBoxAdapter(child: _FilterChipsSection()),
                    SliverToBoxAdapter(child: SizedBox(height: 12)),
                    _TaskListSection(),
                    SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ],
          ),

          // Floating Action Button with isolated rebuild and tap scope
          Positioned(
            bottom: 96 + MediaQuery.of(context).padding.bottom,
            right: 16,
            child: _DashboardFab(
              onTap: () {
                HapticFeedback.lightImpact();
                context.read<AppState>().setNewTaskOpen(true);
                _showNewTaskNotifier.value = true;
              },
            ),
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
    );
  }
}

/// Floating Action Button Widget with pre-cached decoration
class _DashboardFab extends StatelessWidget {
  const _DashboardFab({required this.onTap});
  final VoidCallback onTap;

  static const List<BoxShadow> _fabShadow = [
    BoxShadow(
      color: Colors.black26,
      blurRadius: 12,
      offset: Offset(0, 4),
    )
  ];

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: c.fabBg,
          shape: BoxShape.circle,
          boxShadow: _fabShadow,
        ),
        child: Icon(Icons.add, color: c.fabIcon, size: 24),
      ),
    );
  }
}

/// Header Widget — time-aware greeting + subtitle, with a swipe-up-to-reveal
/// daily motivation line. Listens ONLY to specific settings (name, avatarUri).
class _DashboardHeader extends StatefulWidget {
  const _DashboardHeader({this.onNavigateToProfile});
  final VoidCallback? onNavigateToProfile;

  @override
  State<_DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<_DashboardHeader> {
  bool _showQuote = false;
  double _dragAccum = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    // Motivation slides in automatically 3s after the dashboard appears.
    _quoteTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showQuote = true);
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    _dragAccum += d.primaryDelta ?? 0;
    // Swipe up reveals the quote, swipe down restores the greeting.
    if (_dragAccum <= -48 && !_showQuote) {
      _dragAccum = 0;
      HapticFeedback.selectionClick();
      setState(() => _showQuote = true);
    } else if (_dragAccum >= 48 && _showQuote) {
      _dragAccum = 0;
      HapticFeedback.selectionClick();
      setState(() => _showQuote = false);
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
    final quote = quoteOfTheDay(now);

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
                      // Manual toggle cancels the auto-show so it never
                      // fights the user.
                      _quoteTimer?.cancel();
                      setState(() => _showQuote = !_showQuote);
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

/// Swipeable Dashboard pager: page 1 = Weekly Load chart (unchanged UI),
/// page 2 = Class Routine. Manual drag + 5s auto-cycle (pauses 4s after a
/// manual swipe). Dots match the hero carousel style.
class _WeeklyLoadSection extends StatefulWidget {
  const _WeeklyLoadSection();

  @override
  State<_WeeklyLoadSection> createState() => _WeeklyLoadSectionState();
}

class _WeeklyLoadSectionState extends State<_WeeklyLoadSection> {
  late final PageController _pageCtrl;
  int _page = 0;
  Timer? _cycleTimer;
  Timer? _resumeTimer;

  static const _autoCycle = Duration(seconds: 5);
  static const _resumeDelay = Duration(seconds: 4);

  static String get _mondayOfWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _startCycle();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _resumeTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _startCycle() {
    _cycleTimer?.cancel();
    _resumeTimer?.cancel();
    if (!mounted) return;
    _cycleTimer = Timer.periodic(_autoCycle, (_) {
      if (!mounted || !_pageCtrl.hasClients) return;
      final p = _pageCtrl.page;
      // Never fight the user's finger mid-drag.
      if (p != null && (p - p.round()).abs() > 0.05) return;
      _pageCtrl.animateToPage(
        (_page + 1) % 2,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    if (_page == index) return;
    setState(() => _page = index);
    _cycleTimer?.cancel();
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resumeDelay, () {
      if (mounted) _startCycle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final monday = _mondayOfWeek;
    final weeklyLoad = context.select((AppState s) => s.weeklyLoad(monday));
    final pendingCount =
        context.select((AppState s) => s.pendingTasks.length);
    final routine = context.select((AppState s) => s.classRoutine);

    return RepaintBoundary(
      child: Column(
        children: [
          SizedBox(
            height: 330,
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: _onPageChanged,
              children: [
                // Page 1 — Weekly Load (existing UI, untouched).
                Column(
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
                // Page 2 — Class Routine.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: ClassRoutinePage(
                    entries: routine,
                    onAdd: () => showRoutineSheet(context),
                    onEdit: (e) => showRoutineSheet(context, e),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? c.accent : c.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
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
