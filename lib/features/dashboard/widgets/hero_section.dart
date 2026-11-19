import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/app_state.dart';
import '../../../widgets/hero_carousel.dart';

/// Hero Carousel Section - Listens ONLY to memoized heroTasks
class DashboardHeroSection extends StatelessWidget {
  const DashboardHeroSection({super.key});

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
