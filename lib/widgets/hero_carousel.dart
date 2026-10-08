import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'hero_task_card.dart';

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.tasks});
  final List<Task> tasks;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  Timer? _timer;
  Timer? _pauseTimer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startAutoScroll();
      }
    });
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.tasks.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return; // CRITICAL
      if (!_pageCtrl.hasClients) return;
      final nextIndex = (_currentPage + 1) % widget.tasks.length;
      _pageCtrl.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    // Pause auto-scroll on manual swipe and restart after 2.5 seconds
    _timer?.cancel();
    _pauseTimer?.cancel();
    if (widget.tasks.length > 1) {
      _pauseTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _startAutoScroll();
      });
    }
  }

  @override
  void dispose() {
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: HeroTaskCard(task: task),
              );
            },
          ),
        ),
        if (widget.tasks.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.tasks.length, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: AppTheme.fast,
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
      ],
    );
  }
}
