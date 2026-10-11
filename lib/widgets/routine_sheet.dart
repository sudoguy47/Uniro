import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/class_routine.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

/// Opens the add/edit class-routine bottom sheet. [existing] == null → add.
Future<void> showRoutineSheet(BuildContext context,
    [ClassRoutineEntry? existing]) {
  HapticFeedback.lightImpact();
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
      child: RoutineSheet(existing: existing),
    ),
  );
}

class RoutineSheet extends StatefulWidget {
  const RoutineSheet({super.key, this.existing});
  final ClassRoutineEntry? existing;

  @override
  State<RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<RoutineSheet> {
  late final TextEditingController _subjectCtrl;
  late final TextEditingController _roomCtrl;
  late int _day;
  late TimeOfDay _start;
  late TimeOfDay _end;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectCtrl = TextEditingController(text: e?.subjectName ?? '');
    _roomCtrl = TextEditingController(text: e?.room ?? '');
    _day = e?.dayOfWeek ?? (DateTime.now().weekday - 1);
    _start = _parse(e?.startTime) ?? const TimeOfDay(hour: 9, minute: 0);
    _end = _parse(e?.endTime) ?? const TimeOfDay(hour: 10, minute: 30);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parse(String? hhmm) {
    if (hhmm == null) return null;
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  void _save() {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) {
      _error('Please enter a subject name.');
      return;
    }
    if (_minutes(_end) <= _minutes(_start)) {
      _error('End time must be after start time.');
      return;
    }
    final room = _roomCtrl.text.trim();
    final app = context.read<AppState>();
    if (_isEdit) {
      app.updateRoutineEntry(
        widget.existing!.id,
        widget.existing!.copyWith(
          subjectName: subject,
          dayOfWeek: _day,
          startTime: _fmt(_start),
          endTime: _fmt(_end),
          room: room.isEmpty ? null : room,
          clearRoom: room.isEmpty,
        ),
      );
    } else {
      app.addRoutineEntry(ClassRoutineEntry(
        subjectName: subject,
        dayOfWeek: _day,
        startTime: _fmt(_start),
        endTime: _fmt(_end),
        room: room.isEmpty ? null : room,
      ));
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _delete() {
    context.read<AppState>().deleteRoutineEntry(widget.existing!.id);
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _error(String msg) {
    HapticFeedback.lightImpact();
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
        } else {
          _end = picked;
        }
      });
    }
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _label('SUBJECT', c),
            const SizedBox(height: 6),
            TextField(
              controller: _subjectCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Data Structures',
                hintStyle: TextStyle(color: c.textTertiary),
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
            _label('DAY OF WEEK', c),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final active = i == _day;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _day = i);
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
                        ClassRoutineEntry.dayChips[i],
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
            _label('ROOM / LOCATION (OPTIONAL)', c),
            const SizedBox(height: 6),
            TextField(
              controller: _roomCtrl,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: c.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Room 402',
                hintStyle: TextStyle(color: c.textTertiary),
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
            if (_isEdit) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _delete,
                  child: Text(
                    'Delete Class',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.overdue),
                  ),
                ),
              ),
            ],
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
