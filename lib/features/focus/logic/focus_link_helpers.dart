import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/focus_logic.dart';
import '../../../state/app_state.dart';
import '../../../state/routine_state.dart';

class FocusLinkHelpers {
  FocusLinkHelpers._();

  static IconData linkIcon(String kind) => switch (kind) {
        'course' => Icons.school_outlined,
        'task' => Icons.assignment_outlined,
        'class' => Icons.class_outlined,
        _ => Icons.block_rounded,
      };

  /// Live display label for a link target, with snapshot-safe fallbacks.
  static String linkLabel(
    BuildContext context,
    String kind,
    String? id, {
    RoutineState? routineState,
    AppState? appState,
  }) {
    final routine = routineState ?? context.read<RoutineState>();
    switch (kind) {
      case 'course':
        final c = id == null ? null : routine.courseById(id);
        if (c == null) return 'Removed course';
        final code = c.code ?? '';
        return code.isNotEmpty ? '$code · ${c.name}' : c.name;
      case 'task':
        try {
          final app = appState ?? context.read<AppState>();
          return app.tasks.firstWhere((e) => e.id == id).title;
        } catch (_) {
          return 'Removed task';
        }
      case 'class':
        for (final s in routine.slots) {
          if (s.id == id) {
            final course = routine.courseById(s.courseId);
            final code = course?.code ?? '';
            final base = course == null
                ? 'Removed course'
                : (code.isNotEmpty ? '$code · ${course.name}' : course.name);
            return '$base · ${weekdayShort(s.weekday)} '
                '${slotClock(s.startMinutes)}';
          }
        }
        return 'Removed class';
      default:
        return 'Free focus';
    }
  }
}
