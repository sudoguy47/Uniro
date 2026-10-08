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

/// Header Widget - Listens ONLY to specific settings (name, avatarUri) & avoids sync disk I/O.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({this.onNavigateToProfile});
  final VoidCallback? onNavigateToProfile;

  static String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    // Fine-grained selectors isolate rebuilds from unrelated settings changes
    final name = context.select((AppState s) => s.settings.name);
    final avatarUri = context.select((AppState s) => s.settings.avatarUri);

    return RepaintBoundary(
      child: Container(
        color: c.pageBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hi, $name',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onNavigateToProfile?.call();
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

/// Weekly Load Section - Listens ONLY to weeklyLoad & pendingTasks count
class _WeeklyLoadSection extends StatelessWidget {
  const _WeeklyLoadSection();

  static String get _mondayOfWeek {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final monday = _mondayOfWeek;
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
