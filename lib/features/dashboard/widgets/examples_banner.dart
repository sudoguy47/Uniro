import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/haptics.dart';
import '../../../domain/sample_data.dart';
import '../../../state/app_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';

/// Banner shown while example content is present, with the
/// "Hide examples" escape hatch. Disappears on its own once the last
/// sample item is gone (selectors rebuild it away).
class ExamplesBanner extends StatelessWidget {
  const ExamplesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final has =
        context.select((AppState s) => s.tasks.any((t) => t.isSample)) ||
            context
                .select((RoutineState r) => r.courses.any((c) => c.isSample)) ||
            context.select((NotesState n) => n.allNotes.any((x) => x.isSample));
    if (!has) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final c = Theme.of(context).extension<AppColors>()!;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "You're viewing example data",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  PremiumHaptics.confirm();
                  try {
                    await hideExampleData(
                      app: context.read<AppState>(),
                      routine: context.read<RoutineState>(),
                      notes: context.read<NotesState>(),
                    );
                  } catch (_) {}
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Text(
                    'Hide examples',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
