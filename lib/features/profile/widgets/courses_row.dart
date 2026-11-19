import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/haptics.dart';
import '../../../screens/courses_screen.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';

/// Profile > Courses navigation row (count + chevron).
class CoursesRow extends StatelessWidget {
  const CoursesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final count = context.select((RoutineState r) => r.courses.length);
    return GestureDetector(
      onTap: () {
        PremiumHaptics.tap();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CoursesScreen()),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Courses',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count course${count == 1 ? '' : 's'}',
                    style:
                        TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
