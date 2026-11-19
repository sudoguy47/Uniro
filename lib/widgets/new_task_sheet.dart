import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../models/course.dart';
import '../state/app_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import 'battery_guide.dart';
import 'ui_kit.dart';
import 'reminder_picker_sheet.dart';

/// Ultra-responsive, one-handed New Task Bottom Sheet.
///
/// Features:
/// 1. Snappy 220ms entrance animation with zero lag.
/// 2. FIXED bottom action bar ('Save Task') always within thumb reach.
/// 3. Supports pre-filled `initialDate` when opened from Calendar.
/// 4. Intuitive type, date, time, and reminder selectors for smooth student workflows.
class NewTaskSheet extends StatefulWidget {
  const NewTaskSheet({
    super.key,
    required this.onClose,
    this.initialDate,
    this.initialType,
  });

  final VoidCallback onClose;
  final DateTime? initialDate;
  final TaskType? initialType;

  @override
  State<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends State<NewTaskSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _customCategoryCtrl = TextEditingController();
  final _customCategoryFocusNode = FocusNode();

  late TaskType _type;
  String? _courseId;
  late DateTime _dueDate;
  TimeOfDay? _dueTime;
  bool _hasTime = false;
  TaskPriority _priority = TaskPriority.medium;
  final List<Reminder> _reminders = [];

  bool _showReminderPicker = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TaskType.assignment;
    _dueDate = widget.initialDate ?? DateTime.now();

    // Fast 220ms animation eliminates perceived open lag
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOut,
    );
    _slideCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().setNewTaskOpen(true);
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _customCategoryCtrl.dispose();
    _customCategoryFocusNode.dispose();
    super.dispose();
  }

  void _close() async {
    await _slideCtrl.reverse();
    if (mounted) {
      context.read<AppState>().setNewTaskOpen(false);
    }
    widget.onClose();
  }

  void _saveTask() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final dateStr = DateFormat('yyyy-MM-dd').format(_dueDate);
    final timeStr = _hasTime && _dueTime != null
        ? '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final customCategoryText = _customCategoryCtrl.text.trim();
    final task = Task(
      title: title,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      type: _type,
      customCategory: _type == TaskType.custom
          ? (customCategoryText.isNotEmpty ? customCategoryText : 'Custom')
          : null,
      dueDate: dateStr,
      dueTime: timeStr,
      hasTime: _hasTime,
      priority: _priority,
      reminders: _reminders,
      courseId: _courseId,
    );

    context.read<AppState>().addTask(task);
    PremiumHaptics.confirm();
    if (_reminders.isNotEmpty) {
      BatteryHint.noteReminderCreated();
    }
    _close();
  }

  String _formatType(TaskType t) => switch (t) {
        TaskType.assignment => 'Assignment',
        TaskType.exam => 'Exam / Final',
        TaskType.ct => 'Class Test (CT)',
        TaskType.viva => 'Viva Voce',
        TaskType.presentation => 'Presentation',
        TaskType.lab => 'Lab / Class',
        TaskType.project => 'Project',
        TaskType.other => 'Other / Lecture',
        TaskType.custom => 'Custom',
      };

  IconData _iconForType(TaskType t) => switch (t) {
        TaskType.assignment => Icons.assignment_outlined,
        TaskType.exam => Icons.quiz_outlined,
        TaskType.ct => Icons.school_outlined,
        TaskType.viva => Icons.record_voice_over_outlined,
        TaskType.presentation => Icons.co_present_outlined,
        TaskType.lab => Icons.science_outlined,
        TaskType.project => Icons.architecture_outlined,
        TaskType.other => Icons.event_note_outlined,
        TaskType.custom => Icons.tune_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Stack(
        children: [
        // Smooth Fading Backdrop
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: _close,
            child: Container(color: Colors.black54),
          ),
        ),

        // Sliding Bottom Sheet Container
        SlideTransition(
          position: _slideAnim,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: screenHeight * 0.88,
              ),
              decoration: BoxDecoration(
                color: c.cardBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  )
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Drag Handle & Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: c.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'New Task',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: c.textPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _close,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: c.cardBgRaised,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close,
                                    size: 18, color: c.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // 2. Scrollable Form Content (One-Handed Flow)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('TITLE', c),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _titleCtrl,
                            autofocus: false,
                            textCapitalization: TextCapitalization.sentences,
                            style: TextStyle(color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'e.g. Algorithms Class Test',
                              hintStyle: TextStyle(color: c.textTertiary),
                              filled: true,
                              fillColor: c.inputBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.accent, width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.borderLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('DESCRIPTION', c),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _descCtrl,
                            minLines: 2,
                            maxLines: 3,
                            style: TextStyle(color: c.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Optional notes, syllabus, room number...',
                              hintStyle: TextStyle(color: c.textTertiary),
                              filled: true,
                              fillColor: c.inputBg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.accent, width: 1.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: c.borderLight),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          _label('CATEGORY / TYPE', c),
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: () async {
                              final selected =
                                  await showModalBottomSheet<TaskType>(
                                context: context,
                                backgroundColor: c.cardBg,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                ),
                                builder: (ctx) => SafeArea(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight:
                                          MediaQuery.of(ctx).size.height * 0.72,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 4,
                                          margin: const EdgeInsets.only(top: 12),
                                          decoration: BoxDecoration(
                                            color: c.border,
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            'Select Task Type',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: c.textPrimary,
                                            ),
                                          ),
                                        ),
                                        // Scrollable: 9 types no longer fit on
                                        // small screens — previously the last
                                        // rows were clipped off-screen.
                                        Flexible(
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: TaskType.values.length,
                                            itemBuilder: (ctx, i) {
                                              final t = TaskType.values[i];
                                              final isCurrent = t == _type;
                                              final isCustom = t == TaskType.custom;
                                              final customText = _customCategoryCtrl.text.trim();
                                              return ListTile(
                                                leading: Icon(
                                                    _iconForType(t),
                                                    color: isCurrent
                                                        ? c.accent
                                                        : c.textSecondary),
                                                title: Text(
                                                  isCustom && customText.isNotEmpty
                                                      ? 'Custom ($customText)'
                                                      : _formatType(t),
                                                  style: TextStyle(
                                                    fontWeight: isCurrent
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: isCurrent
                                                        ? c.accent
                                                        : c.textPrimary,
                                                  ),
                                                ),
                                                trailing: isCurrent
                                                    ? Icon(Icons.check,
                                                        color: c.accent)
                                                    : null,
                                                onTap: () =>
                                                    Navigator.pop(ctx, t),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              if (selected != null) {
                                setState(() => _type = selected);
                                if (selected == TaskType.custom) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) {
                                      _customCategoryFocusNode.requestFocus();
                                    }
                                  });
                                }
                              }
                            },
                            child: Container(
                              height: 48,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: c.inputBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: c.borderLight),
                              ),
                              child: Row(
                                children: [
                                  Icon(_iconForType(_type),
                                      size: 18, color: c.accent),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _type == TaskType.custom &&
                                              _customCategoryCtrl.text.trim().isNotEmpty
                                          ? _customCategoryCtrl.text.trim()
                                          : _formatType(_type),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: c.textPrimary),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down,
                                      color: c.textSecondary),
                                ],
                              ),
                            ),
                          ),
                          if (_type == TaskType.custom) ...[
                            const SizedBox(height: 12),
                            _label('CUSTOM CATEGORY NAME', c),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _customCategoryCtrl,
                              focusNode: _customCategoryFocusNode,
                              textCapitalization: TextCapitalization.words,
                              style: TextStyle(fontSize: 14, color: c.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'e.g. Weekly CT, Personal Work, Shopping...',
                                hintStyle: TextStyle(
                                    color: c.textTertiary, fontSize: 13),
                                filled: true,
                                fillColor: c.inputBg,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: c.borderLight),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: c.accent, width: 1.5),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: c.borderLight),
                                ),
                                suffixIcon: _customCategoryCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.clear,
                                            size: 16, color: c.textTertiary),
                                        onPressed: () {
                                          _customCategoryCtrl.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 8),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final suggestion in const [
                                    'Weekly CT',
                                    'Personal Work',
                                    'Outdoor Activities',
                                    'Travel Plans',
                                    'Shopping',
                                    'Other Personal',
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ActionChip(
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        backgroundColor: _customCategoryCtrl
                                                    .text
                                                    .trim()
                                                    .toLowerCase() ==
                                                suggestion.toLowerCase()
                                            ? c.accent.withValues(alpha: 0.2)
                                            : c.cardBgRaised,
                                        side: BorderSide(
                                          color: _customCategoryCtrl.text
                                                      .trim()
                                                      .toLowerCase() ==
                                                  suggestion.toLowerCase()
                                              ? c.accent
                                              : c.border,
                                        ),
                                        label: Text(
                                          suggestion,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _customCategoryCtrl.text
                                                        .trim()
                                                        .toLowerCase() ==
                                                    suggestion.toLowerCase()
                                                ? c.accent
                                                : c.textSecondary,
                                          ),
                                        ),
                                        onPressed: () {
                                          PremiumHaptics.tap();
                                          _customCategoryCtrl.text = suggestion;
                                          _customCategoryCtrl.selection =
                                              TextSelection.fromPosition(
                                            TextPosition(
                                                offset: suggestion.length),
                                          );
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          _label('COURSE (OPTIONAL)', c),
                          const SizedBox(height: 6),
                          _CourseField(
                            courseId: _courseId,
                            onChanged: (v) =>
                                setState(() => _courseId = v),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('DUE DATE', c),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () async {
                                        final now = DateTime.now();
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: _dueDate,
                                          firstDate: now.subtract(
                                              const Duration(days: 365)),
                                          lastDate: now
                                              .add(const Duration(days: 730)),
                                        );
                                        if (picked != null) {
                                          setState(() => _dueDate = picked);
                                        }
                                      },
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: c.inputBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: c.borderLight),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 16,
                                                color: c.textSecondary),
                                            const SizedBox(width: 8),
                                            Text(
                                              DateFormat('MMM d, yyyy')
                                                  .format(_dueDate),
                                              style: TextStyle(
                                                  color: c.textPrimary,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('DUE TIME', c),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: _hasTime
                                          ? () async {
                                              final time = await showTimePicker(
                                                context: context,
                                                initialTime: _dueTime ??
                                                    TimeOfDay.now(),
                                              );
                                              if (time != null) {
                                                setState(
                                                    () => _dueTime = time);
                                              }
                                            }
                                          : null,
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: c.inputBg,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border:
                                              Border.all(color: c.borderLight),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                size: 16,
                                                color: c.textSecondary),
                                            const SizedBox(width: 8),
                                            Text(
                                              _hasTime && _dueTime != null
                                                  ? _dueTime!.format(context)
                                                  : 'No time',
                                              style: TextStyle(
                                                  color: _hasTime
                                                      ? c.textPrimary
                                                      : c.textTertiary,
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Set specific reminder time',
                                style: TextStyle(
                                    fontSize: 14, color: c.textSecondary),
                              ),
                              TinySwitch(
                                value: _hasTime,
                                onChanged: (v) => setState(() {
                                  _hasTime = v;
                                  if (v && _dueTime == null) {
                                    _dueTime =
                                        const TimeOfDay(hour: 9, minute: 0);
                                  }
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _label('PRIORITY', c),
                          const SizedBox(height: 8),
                          PrioritySelector(
                            value: _priority,
                            onChange: (p) => setState(() => _priority = p),
                          ),
                          const SizedBox(height: 14),

                          _label('NOTIFICATIONS & REMINDERS', c),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._reminders.map((r) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: c.accentLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: c.accent),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.notifications_active,
                                            size: 14, color: c.accent),
                                        const SizedBox(width: 6),
                                        Text(
                                          r.type.name,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: c.accent),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _reminders.remove(r)),
                                          child: Icon(Icons.close,
                                              size: 14, color: c.accent),
                                        ),
                                      ],
                                    ),
                                  )),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showReminderPicker = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: c.accent,
                                        style: BorderStyle.solid),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add,
                                          size: 14, color: c.accent),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Add Reminder',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: c.accent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3. Static save footer — always in thumb reach, never
                  // overlaps the form (primary CTA, no glow).
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(height: 1, color: c.borderLight),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: TextButton(
                              onPressed: _saveTask,
                              style: TextButton.styleFrom(
                                backgroundColor: c.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Save Task',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_showReminderPicker)
          ReminderPickerSheet(
            onSelect: (r) => setState(() => _reminders.add(r)),
            onClose: () => setState(() => _showReminderPicker = false),
          ),
      ],
      ),
    );
  }

  Widget _label(String text, AppColors c) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: c.textTertiary,
      ),
    );
  }
}

/// Optional course link row for the task form. "None" clears the link.
class _CourseField extends StatelessWidget {
  const _CourseField({required this.courseId, required this.onChanged});
  final String? courseId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final courses = context.select((RoutineState r) => r.courses);
    Course? selected;
    for (final course in courses) {
      if (course.id == courseId) selected = course;
    }

    return GestureDetector(
      onTap: () async {
        PremiumHaptics.select();
        final picked = await showModalBottomSheet<String?>(
          context: context,
          backgroundColor: c.cardBg,
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Link Course (optional)',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          title: const Text('None'),
                          trailing: courseId == null
                              ? Icon(Icons.check, color: c.accent)
                              : null,
                          // '' sentinel = explicit clear (backdrop
                          // dismiss yields null and keeps the value).
                          onTap: () => Navigator.pop(ctx, ''),
                        ),
                        ...courses.map((course) {
                          final isCurrent = course.id == courseId;
                          return ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: course.colorTag != null
                                    ? Color(course.colorTag!)
                                    : c.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              (course.code ?? '').isNotEmpty
                                  ? '${course.code} · ${course.name}'
                                  : course.name,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCurrent
                                    ? c.accent
                                    : c.textPrimary,
                              ),
                            ),
                            trailing: isCurrent
                                ? Icon(Icons.check, color: c.accent)
                                : null,
                            onTap: () =>
                                Navigator.pop(ctx, course.id),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        // Null return = tapped None OR dismissed. Dismiss should keep the
        // current value, so only clear when explicitly picking None… but
        // Navigator.pop(ctx) with no arg also yields null. Distinguish by
        // using a sentinel: None pops with '' (empty = clear).
        if (picked != null) {
          onChanged(picked.isEmpty ? null : picked);
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.borderLight),
        ),
        child: Row(
          children: [
            Icon(Icons.school_outlined, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected == null
                    ? 'None'
                    : ((selected.code ?? '').isNotEmpty
                        ? '${selected.code} · ${selected.name}'
                        : selected.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: c.textPrimary),
              ),
            ),
            const Spacer(),
            Icon(Icons.keyboard_arrow_down, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
