import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/class_slot.dart';
import '../models/course.dart';
import '../services/local_store.dart';

/// Courses + weekly class slots (Routine tab). Mirrors the NotesState
/// pattern: own in-RAM lists, 400ms debounced writes, only-dirty-keys
/// persistence, loaded before the first frame in main.dart.
class RoutineState extends ChangeNotifier {
  RoutineState() {
    _courses = [];
    _slots = [];
  }

  List<Course> _courses = [];
  List<ClassSlot> _slots = [];
  Timer? _saveDebounce;
  bool _disposed = false;

  List<Course> get courses => List.unmodifiable(_courses);
  List<ClassSlot> get slots => List.unmodifiable(_slots);

  Course? courseById(String id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Slots for a weekday (1–7), sorted by start time.
  List<ClassSlot> slotsForWeekday(int weekday) {
    final list = _slots.where((s) => s.weekday == weekday).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return list;
  }

  Future<void> load() async {
    final rawCourses = LocalStore.instance.load('courses');
    if (rawCourses is List) {
      _courses = rawCourses
          .map((j) => Course.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    final rawSlots = LocalStore.instance.load('slots');
    if (rawSlots is List) {
      _slots = rawSlots
          .map((j) => ClassSlot.fromJson(Map<String, dynamic>.from(j as Map)))
          .toList();
    }
    // One-time migration from the old dashboard mini-routine
    // (ClassRoutineEntry: dayOfWeek 0–6) → Course + ClassSlot.
    await _migrateLegacyRoutine();
    notifyListeners();
  }

  Future<void> _migrateLegacyRoutine() async {
    if (_courses.isNotEmpty || _slots.isNotEmpty) return;
    final raw = LocalStore.instance.load('routine');
    if (raw is! List || raw.isEmpty) return;
    try {
      final bySubject = <String, String>{}; // subject -> courseId
      for (final item in raw) {
        final j = Map<String, dynamic>.from(item as Map);
        final subject = (j['subjectName'] as String? ?? '').trim();
        if (subject.isEmpty) continue;
        var courseId = bySubject[subject];
        if (courseId == null) {
          final course = Course(
            name: subject,
            colorTag: Course
                .palette[subject.hashCode.abs() % Course.palette.length],
          );
          _courses.add(course);
          courseId = course.id;
          bySubject[subject] = courseId;
        }
        int day = (j['dayOfWeek'] as num?)?.toInt() ?? 0;
        day = (day.clamp(0, 6) + 1); // 0–6 Mon..Sun → 1–7
        _slots.add(ClassSlot(
          courseId: courseId,
          weekday: day,
          startMinutes: _hhmmToMinutes(j['startTime'] as String? ?? '09:00'),
          endMinutes: _hhmmToMinutes(j['endTime'] as String? ?? '10:00'),
          room: j['room'] as String?,
        ));
      }
      _persistNow();
    } catch (_) {
      // Corrupt legacy data: start clean rather than crash.
      _courses = [];
      _slots = [];
    }
    await LocalStore.instance.remove('routine');
  }

  int _hhmmToMinutes(String v) {
    final p = v.split(':');
    final h = int.tryParse(p[0]);
    final m = p.length > 1 ? int.tryParse(p[1]) : 0;
    if (h == null || m == null) return 540;
    return (h * 60 + m).clamp(0, 1439);
  }

  // ── Courses ──────────────────────────────────────────────────────────
  void addCourse(Course course) {
    _courses = [..._courses, course];
    notifyListeners();
    _persist();
  }

  void updateCourse(String id, Course updated) {
    final i = _courses.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _courses = List.of(_courses)..[i] = updated;
    notifyListeners();
    _persist();
  }

  /// Deletes the course AND its slots. Callers unlink tasks/notes via
  /// AppState.unlinkCourse / NotesState.unlinkCourse.
  List<ClassSlot> deleteCourse(String id) {
    final removed =
        _slots.where((s) => s.courseId == id).toList();
    _courses = _courses.where((c) => c.id != id).toList();
    _slots = _slots.where((s) => s.courseId != id).toList();
    notifyListeners();
    _persist();
    return removed;
  }

  // ── Slots ────────────────────────────────────────────────────────────
  void addSlot(ClassSlot slot) {
    _slots = [..._slots, slot];
    notifyListeners();
    _persist();
  }

  void addSlots(Iterable<ClassSlot> newSlots) {
    _slots = [..._slots, ...newSlots];
    notifyListeners();
    _persist();
  }

  void updateSlot(String id, ClassSlot updated) {
    final i = _slots.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _slots = List.of(_slots)..[i] = updated;
    notifyListeners();
    _persist();
  }

  /// Returns the removed slot (for undo).
  ClassSlot? deleteSlot(String id) {
    final i = _slots.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    final removed = _slots[i];
    _slots = List.of(_slots)..removeAt(i);
    notifyListeners();
    _persist();
    return removed;
  }

  void restoreSlot(ClassSlot slot) {
    _slots = [..._slots, slot];
    notifyListeners();
    _persist();
  }

  // ── Persistence (debounced; only dirty keys) ─────────────────────────
  void _persist() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!_disposed) _persistNow();
    });
  }

  void _persistNow() {
    if (_disposed) return;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    LocalStore.instance
        .save('courses', _courses.map((c) => c.toJson()).toList());
    LocalStore.instance.save('slots', _slots.map((s) => s.toJson()).toList());
  }

  void persistNow() => _persistNow();

  @override
  void dispose() {
    _disposed = true;
    _saveDebounce?.cancel();
    super.dispose();
  }
}
