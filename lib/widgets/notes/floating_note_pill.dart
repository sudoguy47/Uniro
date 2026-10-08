import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingNotePill extends StatelessWidget {
  const FloatingNotePill({
    super.key,
    required this.onNewNote,
    required this.onNewChecklist,
  });

  final VoidCallback onNewNote;
  final VoidCallback onNewChecklist;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                HapticFeedback.lightImpact();
                onNewNote();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add_rounded, color: cs.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'New Note',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: cs.onPrimary.withValues(alpha: 0.3),
            ),
            IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.check_box_outlined,
                size: 22,
                color: cs.onPrimary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                onNewChecklist();
              },
              tooltip: 'New Checklist',
            ),
          ],
        ),
      ),
    );
  }
}
