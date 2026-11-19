import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/sample_data.dart';
import '../../../domain/haptics.dart';
import '../../../state/app_state.dart';
import '../../../state/notes_state.dart';
import '../../../state/routine_state.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_notification.dart';

/// Profile > Example data: load the tour bundle on demand, or hide it
/// again. Toggles its label based on whether samples are present.
class ExamplesCard extends StatefulWidget {
  const ExamplesCard({super.key});

  @override
  State<ExamplesCard> createState() => _ExamplesCardState();
}

class _ExamplesCardState extends State<ExamplesCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      final routine = context.read<RoutineState>();
      final notes = context.read<NotesState>();
      if (hasExampleData(app, routine, notes)) {
        PremiumHaptics.confirm();
        await hideExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        AppNotification.info(context, 'Example data hidden.');
      } else {
        PremiumHaptics.confirm();
        await seedExampleData(app: app, routine: routine, notes: notes);
        if (!mounted) return;
        AppNotification.success(context, 'Example data loaded.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final showing = hasExampleData(
      context.watch<AppState>(),
      context.watch<RoutineState>(),
      context.watch<NotesState>(),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 340;
          final button = FilledButton(
            onPressed: _busy ? null : _toggle,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(_busy
                ? 'Working…'
                : showing
                    ? 'Hide examples'
                    : 'Show examples'),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example data',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  showing
                      ? 'Sample tasks, classes and notes are visible'
                      : 'Explore the app with sample content',
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: button,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Example data',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showing
                          ? 'Sample tasks, classes and notes are visible'
                          : 'Explore the app with sample content',
                      style: TextStyle(fontSize: 13, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}
