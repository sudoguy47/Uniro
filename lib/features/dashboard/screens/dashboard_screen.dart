import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/responsive.dart';
import '../../../domain/haptics.dart';
import '../../../domain/sample_data.dart';
import '../../../screens/done_screen.dart';
import '../../../services/local_store.dart';
import '../../../state/app_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/class_form_sheet.dart';
import '../../../widgets/new_task_sheet.dart';
import '../../../widgets/next_class_card.dart';
import '../widgets/create_popover.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/examples_banner.dart';
import '../widgets/filter_chips_section.dart';
import '../widgets/hero_section.dart';
import '../widgets/task_list_section.dart';
import '../widgets/view_toggle.dart';
import '../widgets/weekly_load_section.dart';
import '../../../features/onboarding/tour_guide.dart';

/// Highly optimized Dashboard Screen.
///
/// Performance Optimizations:
/// 1. Layout calculation overhead eliminated via granular list builders.
/// 2. Granular state selectors (`context.select`) strictly scope rebuilds so scrolling
///    and state changes re-render only the affected subtrees instead of the entire screen.
/// 3. ValueListenableBuilder isolates NewTaskSheet and FAB animations from the scrollable tree.
/// 4. RepaintBoundaries isolate GPU compositing layers across dashboard sections.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onNavigateToProfile,
    this.onNavigateToRoutine,
  });

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
  // Use TourGuideKeys.plusButton so the tour guide can spotlight the + button.
  final GlobalKey _plusKey = TourGuideKeys.plusButton;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferExamples());
  }

  /// First-run empty state: when nothing exists anywhere yet, offer the
  /// example bundle once. Never nags again after the first answer.
  Future<void> _maybeOfferExamples() async {
    if (!mounted) return;
    try {
      final app = context.read<AppState>();
      final routine = context.read<RoutineState>();
      final notes = context.read<NotesState>();
      if (app.tasks.isNotEmpty ||
          routine.courses.isNotEmpty ||
          notes.allNotes.isNotEmpty) {
        return;
      }
      if (LocalStore.instance.load('examples_offered') == true) return;
      LocalStore.instance.save('examples_offered', true);
      if (!mounted) return;
      final use = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          final c = Theme.of(dialogCtx).extension<AppColors>()!;
          return AlertDialog(
            backgroundColor: c.cardBg,
            title: const Text('Explore with examples?'),
            content: Text(
              'See Uniro filled with sample tasks, classes and notes. '
              'You can hide them anytime.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Start empty'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Use examples'),
              ),
            ],
          );
        },
      );
      if (use == true && mounted) {
        PremiumHaptics.confirm();
        await seedExampleData(app: app, routine: routine, notes: notes);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _plusOverlay?.remove();
    _showNewTaskNotifier.dispose();
    super.dispose();
  }

  void _openNewTask() {
    PremiumHaptics.tap();
    context.read<AppState>().setNewTaskOpen(true);
    _showNewTaskNotifier.value = true;
  }

  void _togglePlus() {
    if (_plusOpen) {
      _closePlus();
      return;
    }
    final box = _plusKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final pos = box.localToGlobal(Offset.zero);
    PremiumHaptics.select();
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
            child: CreatePopover(
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
        context.select((AppState s) => s.settings.dashboardView) == 'completed';

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
                DashboardHeader(
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
                            DashboardViewToggle(
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
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: NextClassCard(
                                onTap: () => widget.onNavigateToRoutine?.call(),
                              ),
                            ),
                            const ExamplesBanner(),
                            const SliverToBoxAdapter(
                                child: DashboardHeroSection()),
                            SliverToBoxAdapter(
                              child: WeeklyLoadSection(
                                onNavigateToRoutine: widget.onNavigateToRoutine,
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: DashboardViewToggle(
                                completed: completed,
                                onChanged: _setView,
                              ),
                            ),
                            const SliverToBoxAdapter(
                                child: FilterChipsSection()),
                            const SliverToBoxAdapter(
                                child: SizedBox(height: 12)),
                            const TaskListSection(),
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: AppInsets.bottomNavClearance(context),
                              ),
                            ),
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
