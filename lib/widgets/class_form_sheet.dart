import 'package:flutter/material.dart';
import '../domain/haptics.dart';
import 'package:provider/provider.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../state/routine_state.dart';
import '../theme/app_colors.dart';
import 'battery_guide.dart';
import '../screens/routine_screen.dart' show courseWeekdayNames;

/// Opens the add/edit class bottom sheet.
/// [existing] == null → add mode (multi-day chips).
/// [initialWeekday] preselects a day in add mode (1–7).
Future<void> showClassFormSheet(
  BuildContext context, {
  ClassSlot? existing,
  int? initialWeekday,
}) {
  PremiumHaptics.tap();
  final c = Theme.of(context).extension<AppColors>()!;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.cardBg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: ClassFormSheet(existing: existing, initialWeekday: initialWeekday),
    ),
  );
}

class ClassFormSheet extends StatefulWidget {
  const ClassFormSheet({super.key, this.existing, this.initialWeekday});
  final ClassSlot? existing;
  final int? initialWeekday;

  @override
  State<ClassFormSheet> createState() => _ClassFormSheetState();
}

class _ClassFormSheetState extends State<ClassFormSheet> {
  bool get _isEdit => widget.existing != null;

  String? _courseId;
  bool _showNewCourse = false;
  final _cNameCtrl = TextEditingController();
  int? _cColor;

  Set<int> _days = {};
  late TimeOfDay _start;
  late TimeOfDay _end;
  bool _endTouched = false;
  final _roomCtrl = TextEditingController();
  int? _reminder = 15;

  static const _reminderOptions = <int?>[null, 5, 10, 15, 30];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _courseId = e.courseId;
      _days = {e.weekday};
      _start = TimeOfDay(hour: e.startMinutes ~/ 60, minute: e.startMinutes % 60);
      _end = TimeOfDay(hour: e.endMinutes ~/ 60, minute: e.endMinutes % 60);
      _endTouched = true;
      _roomCtrl.text = e.room ?? '';
      _reminder = e.reminderMinutesBefore;
    } else {
      _days = {widget.initialWeekday ?? DateTime.now().weekday};
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 20);
    }
  }

  @override
  void dispose() {
    _cNameCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  void _error(String msg) {
    PremiumHaptics.tap();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _start = picked;
          // Default the end to 1h 20m after start unless the user
          // already set a custom end that still fits.
          final auto = _plusMinutes(picked, 80);
          if (!_endTouched || _mins(_end) <= _mins(_start)) {
            _end = auto;
          }
        } else {
          _end = picked;
          _endTouched = true;
        }
      });
    }
  }

  /// [t] plus [minutes], wrapping past midnight.
  TimeOfDay _plusMinutes(TimeOfDay t, int minutes) {
    final total = (t.hour * 60 + t.minute + minutes) % (24 * 60);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  /// Creates the inline course (name + color only); null + error on
  /// invalid input.
  Course? _createInlineCourse() {
    final name = _cNameCtrl.text.trim();
    if (name.isEmpty) {
      _error('Please enter a course name (or pick an existing course).');
      return null;
    }
    return Course(
      name: name,
      colorTag: _cColor,
    );
  }

  /// First overlapping existing slot description, or null.
  String? _findOverlap(List<ClassSlot> all, int day, int s, int e) {
    final routine = context.read<RoutineState>();
    for (final o in all) {
      if (o.weekday != day) continue;
      if (_isEdit && o.id == widget.existing!.id) continue;
      if (!slotsOverlapMinutes(s, e, o.startMinutes, o.endMinutes)) continue;
      final oc = routine.courseById(o.courseId);
      final label = oc == null
          ? 'another class'
          : ((oc.code ?? '').isNotEmpty ? '${oc.code} · ${oc.name}' : oc.name);
      return '$label (${_fmtMin(o.startMinutes)}–${_fmtMin(o.endMinutes)}) on ${courseWeekdayNames[day]}';
    }
    return null;
  }

  String _fmtMin(int m) {
    final t = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return t.format(context);
  }

  Future<bool> _confirmOverlap(String what) async {
    final c = Theme.of(context).extension<AppColors>()!;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.cardBg,
        title: const Text('Overlaps another class'),
        content: Text('$what. Save anyway?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save anyway',
                style: TextStyle(color: c.accent)),
          ),
        ],
      ),
    );
    return save == true;
  }

  Future<void> _save() async {
    final routine = context.read<RoutineState>();
    var courseId = _courseId;
    // Inline new course wins when its form is open with a name typed.
    if (_showNewCourse && _cNameCtrl.text.trim().isNotEmpty) {
      final created = _createInlineCourse();
      if (created == null) return;
      routine.addCourse(created);
      courseId = created.id;
    }
    if (courseId == null) {
      _error('Please pick a course first.');
      return;
    }
    if (_days.isEmpty) {
      _error('Please pick at least one day.');
      return;
    }
    if (_mins(_end) <= _mins(_start)) {
      _error('End time must be after start time.');
      return;
    }
    final room = _roomCtrl.text.trim();
    if (_isEdit) {
      final day = _days.first;
      final conflict = _findOverlap(
          routine.slots, day, _mins(_start), _mins(_end));
      if (conflict != null && !await _confirmOverlap(conflict)) return;
      routine.updateSlot(
        widget.existing!.id,
        widget.existing!.copyWith(
          courseId: courseId,
          weekday: day,
          startMinutes: _mins(_start),
          endMinutes: _mins(_end),
          room: room.isEmpty ? null : room,
          clearRoom: room.isEmpty,
          reminderMinutesBefore: _reminder,
          clearReminder: _reminder == null,
        ),
      );
    } else {
      for (final day in _days.toList()..sort()) {
        final conflict = _findOverlap(
            routine.slots, day, _mins(_start), _mins(_end));
        if (conflict != null && !await _confirmOverlap(conflict)) return;
      }
      routine.addSlots(_days.map((day) => ClassSlot(
            courseId: courseId!,
            weekday: day,
            startMinutes: _mins(_start),
            endMinutes: _mins(_end),
            room: room.isEmpty ? null : room,
            reminderMinutesBefore: _reminder,
          )));
    }
    if (!mounted) return;
    final enabled = context.read<AppState>().settings.notificationsEnabled;
    await NotificationService.instance.refreshClassReminders(
      courses: routine.courses,
      slots: routine.slots,
      enabled: enabled,
    );
    PremiumHaptics.confirm();
    if (!mounted) return;
    if (_reminder != null) {
      BatteryHint.noteReminderCreated();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>()!;
    final routine = context.watch<RoutineState>();
    final selectedCourse = _courseId == null
        ? null
        : routine.courseById(_courseId!);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 14),
            Text(
              _isEdit ? 'Edit Class' : 'Add Class',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _label('COURSE', c),
            const SizedBox(height: 6),
            _courseField(c, routine.courses, selectedCourse),
            if (_showNewCourse) ...[
              const SizedBox(height: 10),
              _newCourseForm(c),
            ],
            const SizedBox(height: 16),
            _label(_isEdit ? 'DAY' : 'DAYS', c),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final day = i + 1;
                final active = _days.contains(day);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      PremiumHaptics.select();
                      setState(() {
                        if (_isEdit) {
                          _days = {day};
                        } else if (active) {
                          if (_days.length > 1) _days.remove(day);
                        } else {
                          _days.add(day);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 40,
                      decoration: BoxDecoration(
                        color: active ? c.navActiveBg : c.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? c.navActiveBg : c.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? c.navActiveText
                              : c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('START', c),
                      const SizedBox(height: 6),
                      _timeBox(c, _start, () => _pickTime(true)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('END', c),
                      const SizedBox(height: 6),
                      _timeBox(c, _end, () => _pickTime(false)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _label('ROOM (OPTIONAL)', c),
            const SizedBox(height: 6),
            TextField(
              controller: _roomCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. 404',
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
                filled: true,
                fillColor: c.inputBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _label('REMINDER', c),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: c.inputBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _reminder,
                  isExpanded: true,
                  dropdownColor: c.cardBg,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15),
                  items: _reminderOptions
                      .map((v) => DropdownMenuItem<int?>(
                            value: v,
                            child: Text(v == null
                                ? 'None'
                                : '$v min before'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    PremiumHaptics.select();
                    setState(() => _reminder = v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: _save,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: c.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  _isEdit ? 'Save Changes' : 'Add Class',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _courseField(
      AppColors c, List<Course> courses, Course? selected) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            PremiumHaptics.select();
            setState(() => _showNewCourse = !_showNewCourse);
          },
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (selected?.colorTag != null)
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: Color(selected!.colorTag!),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    selected == null
                        ? 'Select course…'
                        : ((selected.code ?? '').isNotEmpty
                            ? '${selected.code} · ${selected.name}'
                            : selected.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected == null
                          ? c.textTertiary
                          : c.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _showNewCourse
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_showNewCourse) ...[
          const SizedBox(height: 8),
          ...courses.map((course) => ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4),
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
                    fontWeight:
                        course.id == _courseId ? FontWeight.bold : FontWeight.normal,
                    color: course.id == _courseId
                        ? c.accent
                        : c.textPrimary,
                  ),
                ),
                trailing: course.id == _courseId
                    ? Icon(Icons.check, color: c.accent)
                    : null,
                onTap: () => setState(() => _courseId = course.id),
              )),
        ],
      ],
    );
  }

  Widget _newCourseForm(AppColors c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.inputBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.add, size: 16),
              const SizedBox(width: 6),
              Text(
                'New course',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _miniField(_cNameCtrl, 'Course name * (e.g. EEE141.8)', c),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: Course.palette.map((col) {
              final active = _cColor == col;
              return GestureDetector(
                onTap: () => setState(() => _cColor = col),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(col),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? c.textPrimary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: active
                      ? const Icon(Icons.check,
                          size: 14, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved with the class when you tap "${_isEdit ? 'Save Changes' : 'Add Class'}".',
            style: TextStyle(fontSize: 12, color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _miniField(
      TextEditingController ctrl, String hint, AppColors c) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      keyboardType: hint == 'Credits'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      style: TextStyle(color: c.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.textTertiary, fontSize: 13),
        filled: true,
        fillColor: c.cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _timeBox(AppColors c, TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 16, color: c.textSecondary),
            const SizedBox(width: 8),
            Text(
              t.format(context),
              style: TextStyle(
                  color: c.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, AppColors c) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
        color: c.textTertiary,
      ),
    );
  }
}
