import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class EmptyAttendance extends StatelessWidget {
  const EmptyAttendance({
    super.key,
    required this.onAddCourse,
    required this.onLogClass,
  });

  final VoidCallback onAddCourse;
  final VoidCallback onLogClass;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fact_check_outlined, size: 56, color: c.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No attendance records yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your subjects in Routine first, or log manual attendance anytime classes take place.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onAddCourse,
                  icon: const Icon(Icons.school_outlined, size: 16),
                  label: const Text('Add Courses'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.textPrimary,
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onLogClass,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Log a Class'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
