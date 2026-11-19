import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/task.dart';
import '../../../state/app_state.dart';
import '../../../widgets/ui_kit.dart';

/// Filter Chips Section - Listens ONLY to activeFilter & specifies prototypeItem for ListView
class FilterChipsSection extends StatelessWidget {
  const FilterChipsSection({super.key});

  static const List<TaskType?> _filterTypes = [
    null,
    ...TaskType.values,
  ];

  static const _chipPadding = EdgeInsets.only(right: 8);

  @override
  Widget build(BuildContext context) {
    final activeFilter = context.select((AppState s) => s.activeFilter);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _filterTypes.length,
          itemBuilder: (context, index) {
            final type = _filterTypes[index];
            final label = type == null
                ? 'All'
                : type == TaskType.ct
                    ? 'CT'
                    : type.name[0].toUpperCase() + type.name.substring(1);
            final active = activeFilter == type;

            return Padding(
              padding: _chipPadding,
              child: AppFilterChip(
                label: label,
                active: active,
                onTap: () => context.read<AppState>().setFilter(type),
              ),
            );
          },
        ),
      ),
    );
  }
}
