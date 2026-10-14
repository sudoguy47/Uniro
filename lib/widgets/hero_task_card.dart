import 'package:flutter/material.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import '../domain/task_utils.dart';

class HeroTaskCard extends StatelessWidget {
  const HeroTaskCard({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final u = getUrgency(task);
    final bgColor = cardBgColor(u, c);
    final typeLabel = task.type.name.toUpperCase();
    // Fixed-height card in a fixed-height PageView (note: the carousel
    // uses viewportFraction 0.88, so measure INSIDE the padding — an
    // outer LayoutBuilder would see the wider page item).
    // At very large text scales the description drops to one line, and a
    // whole-card scale-down guard absorbs the rest. Identical pixels at
    // normal sizes (scale 1). Inner rows use explicit widths, never
    // Expanded, so the outer FittedBox always sees bounded content.
    final descLines =
        MediaQuery.textScalerOf(context).scale(13) > 20 ? 1 : 2;

    return Container(
      width: double.infinity,
      height: 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, cons) {
          final cw = cons.maxWidth;
          final badgeW = cw * 0.36;
          final pillW = cw * 0.38;
          final titleW = cw - 8 - badgeW;
          final dateW = cw - 28 - 4 - 8 - pillW;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: cw,
              height: 102,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 34,
                    child: Row(
                      children: [
                        SizedBox(
                          width: titleW,
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: badgeW,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                typeLabel,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 26,
                      child: Text(
                        task.description!,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.0),
                        maxLines: descLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        SizedBox(
                          width: dateW,
                          child: Text(
                            task.dueDate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: pillW,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                urgencyLabel(u),
                                maxLines: 1,
                                style: TextStyle(
                                  color: urgencyBorderColor(u, c),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  height: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
