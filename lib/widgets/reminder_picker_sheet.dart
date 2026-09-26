import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../theme/app_colors.dart';
import 'ui_kit.dart';

class ReminderPickerSheet extends StatefulWidget {
  const ReminderPickerSheet({
    super.key,
    required this.onSelect,
    required this.onClose,
  });

  final ValueChanged<Reminder> onSelect;
  final VoidCallback onClose;

  @override
  State<ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<ReminderPickerSheet> {
  ReminderType _selectedType = ReminderType.oneDay;
  int _customDays = 3;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;

    String labelForType(ReminderType t) => switch (t) {
          ReminderType.atTime => 'At time of event',
          ReminderType.oneHour => '1 hour before',
          ReminderType.oneDay => '1 day before',
          ReminderType.threeDays => '3 days before',
          ReminderType.oneWeek => '1 week before',
          ReminderType.custom => 'Custom (days before)',
        };

    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: widget.onClose,
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add Reminder',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: c.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onClose,
                            child: Icon(Icons.close, color: c.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: ReminderType.values.map((t) {
                          return RadioListItem(
                            label: labelForType(t),
                            selected: _selectedType == t,
                            onTap: () => setState(() => _selectedType = t),
                          );
                        }).toList(),
                      ),
                      if (_selectedType == ReminderType.custom) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Days before due date',
                              style: TextStyle(
                                fontSize: 14,
                                color: c.textSecondary,
                              ),
                            ),
                            StepperControl(
                              value: _customDays,
                              min: 1,
                              max: 30,
                              onChanged: (v) => setState(() => _customDays = v),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Add Reminder',
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final reminder = Reminder(
                            type: _selectedType,
                            customDays: _selectedType == ReminderType.custom
                                ? _customDays
                                : null,
                          );
                          widget.onSelect(reminder);
                          widget.onClose();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
