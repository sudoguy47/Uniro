import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'hero_task_card.dart';

/// Auto-scrolling hero carousel, tuned to never drop frames:
///
/// - 4s interval (was 2s) + 450ms animation (was 600ms): the old timing kept
///   a second animation queued while the first was still settling.
/// - Timers pause when the app backgrounds and when the task list shrinks
///   to 1 item; `didUpdateWidget` restarts cleanly instead of leaking.
/// - Each page wrapped in a RepaintBoundary so auto-scroll repaints only
///   the carousel layer, never the dashboard header/chart/list.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.tasks});
  final List<Task> tasks;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel>
    with WidgetsBindingObserver {
  late PageController _pageCtrl;
  int _currentPage = 0;
  Timer? _timer;
  Timer? _pauseTimer;
  bool _appPaused = false;

  static const _autoScrollInterval = Duration(seconds: 4);
  static const _resumeDelay = Duration(seconds: 3);
  static const _pageAnimDuration = Duration(milliseconds: 450);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoScroll();
    });
  }

  @override
  void didUpdateWidget(covariant HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tasks, widget.tasks)) {
      _currentPage = _currentPage.clamp(0, widget.tasks.length - 1);
      // Identity changed (filter/completion) — restart cleanly, no overlap.
      _startAutoScroll();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appPaused = state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached;
    if (_appPaused) {
      _timer?.cancel();
      _pauseTimer?.cancel();
    } else if (mounted) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _pauseTimer?.cancel();
    if (_appPaused || widget.tasks.length <= 1) return;
    _timer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || _appPaused) return;
      if (!_pageCtrl.hasClients) return;
      final page = _pageCtrl.page;
      // Skip if user is mid-drag — never fight the finger.
      if (page != null && (page - page.round()).abs() > 0.05) return;
      final nextIndex = (_currentPage + 1) % widget.tasks.length;
      _pageCtrl.animateToPage(
        nextIndex,
        duration: _pageAnimDuration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    if (_currentPage == index) return;
    setState(() => _currentPage = index);
    // Pause auto-scroll on manual swipe, resume after idle delay.
    _timer?.cancel();
    _pauseTimer?.cancel();
    if (widget.tasks.length > 1 && !_appPaused) {
      _pauseTimer = Timer(_resumeDelay, () {
        if (!mounted) return;
        _startAutoScroll();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pauseTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    return Column(
      children: [
        SizedBox(
          height: 130,
          child: PageView.builder(
            controller: _pageCtrl,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.tasks.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final task = widget.tasks[index];
              return RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: HeroTaskCard(task: task),
                ),
              );
            },
          ),
        ),
        if (widget.tasks.length > 1) ...[
          const SizedBox(height: 12),
          _DotsIndicator(
            count: widget.tasks.length,
            current: _currentPage,
            activeColor: c.accent,
            inactiveColor: c.border,
          ),
        ],
      ],
    );
  }
}

/// Dots row isolated so page changes repaint only this small subtree.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int count;
  final int current;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final active = index == current;
          return AnimatedContainer(
            duration: AppTheme.fast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? activeColor : inactiveColor,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
