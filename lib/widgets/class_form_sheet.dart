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
import 'app_notification.dart';
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

  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
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
      _days = {e.weekday};
      _start = TimeOfDay(hour: e.startMinutes ~/ 60, minute: e.startMinutes % 60);
      _end = TimeOfDay(hour: e.endMinutes ~/ 60, minute: e.endMinutes % 60);
      _endTouched = true;
      _roomCtrl.text = e.room ?? '';
      _reminder = e.reminderMinutesBefore;
      // Pre-fill the class name and course code from its backing course.
      final routine = context.read<RoutineState>();
      final course = routine.courseById(e.courseId);
      _nameCtrl.text = course?.name ?? '';
      _codeCtrl.text = course?.code ?? '';
    } else {
      _days = {widget.initialWeekday ?? DateTime.now().weekday};
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 10, minute: 20);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  void _error(String msg) {
    PremiumHaptics.tap();
    AppNotification.warning(context, msg);
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

  /// Returns the course id to back [name]. Reuses a course with the same
  /// name (case-insensitive), renames the current course when [currentId]
  /// has no other slots, or creates a fresh one. Silent by design — the
  /// name is the whole identity of a class in this sheet.
  String _ensureCourseForName(
    RoutineState routine,
    String name, {
    String? code,
    String? currentId,
  }) {
    final cleanCode = (code != null && code.isNotEmpty) ? code : null;
    String? existing;
    for (final co in routine.courses) {
      if (co.name.trim().toLowerCase() == name.toLowerCase()) {
        existing = co.id;
        if (cleanCode != null && co.code != cleanCode) {
          routine.updateCourse(co.id, co.copyWith(code: cleanCode));
        }
        break;
      }
    }
    if (existing != null) return existing;

    final current = currentId == null ? null : routine.courseById(currentId);
    if (current != null) {
      final usedElsewhere = routine.slots
          .any((s) => s.courseId == currentId && s.id != widget.existing?.id);
      if (!usedElsewhere) {
        routine.updateCourse(
          currentId!,
          current.copyWith(
            name: name,
            code: cleanCode,
            clearCode: cleanCode == null,
          ),
        );
        return currentId;
      }
    }
    final created = Course(name: name, code: cleanCode);
    routine.addCourse(created);
    return created.id;
  }

  Future<void> _save() async {
    final routine = context.read<RoutineState>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _error('Please enter a class name.');
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
    final code = _codeCtrl.text.trim();
    final room = _roomCtrl.text.trim();

    if (_isEdit) {
      final day = _days.first;
      final conflict = _findOverlap(
          routine.slots, day, _mins(_start), _mins(_end));
      if (conflict != null && !await _confirmOverlap(conflict)) return;
      final courseId = _ensureCourseForName(
        routine,
        name,
        code: code,
        currentId: widget.existing!.courseId,
      );
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
      final courseId = _ensureCourseForName(routine, name, code: code);
      routine.addSlots(_days.map((day) => ClassSlot(
            courseId: courseId,
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
    await NotificationService.instance.refreshAttendancePrompts(
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
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: c.textPrimary,
              ),
            ),
            if (_isEdit)
              const SizedBox(height: 2)
            else ...[
              const SizedBox(height: 2),
              Text(
                'One entry per class — pick every day it happens.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textTertiary,
                ),
              ),
            ],
            const SizedBox(height: 14),

            _label('CLASS NAME', c),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Mathematics',
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
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

            _label('COURSE CODE (OPTIONAL)', c),
            const SizedBox(height: 6),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: c.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. MATH 101',
                hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
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
                          color: active ? c.navActiveBg : c.borderLight,
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
            const SizedBox(height: 14),
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
            const SizedBox(height: 14),
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
            _label('REMINDER', c),
            const SizedBox(height: 6),
            Row(
              children: _reminderOptions.map((v) {
                final active = v == _reminder;
                final label = v == null ? 'None' : '$v min';
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      PremiumHaptics.select();
                      setState(() => _reminder = v);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? c.navActiveBg : c.inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? c.navActiveBg : c.borderLight,
                        ),
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? c.navActiveText : c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                    borderRadius: BorderRadius.circular(16),
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

  Widget _timeBox(AppColors c, TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
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
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: c.textTertiary,
      ),
    );
  }
}
