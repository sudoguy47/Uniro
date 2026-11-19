import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/attendance_record.dart';

/// Helper formatting and UI classification methods for attendance.
class AttendanceHelpers {
  AttendanceHelpers._();

  /// Determines an appropriate icon for a subject name / course code.
  static IconData iconForSubject(String name, String code) {
    final lower = '$name $code'.toLowerCase();
    if (lower.contains('cse') ||
        lower.contains('cs') ||
        lower.contains('program') ||
        lower.contains('code') ||
        lower.contains('algo') ||
        lower.contains('data') ||
        lower.contains('soft')) {
      return Icons.code_rounded;
    }
    if (lower.contains('mat') ||
        lower.contains('calc') ||
        lower.contains('algebra') ||
        lower.contains('stat')) {
      return Icons.calculate_outlined;
    }
    if (lower.contains('eee') ||
        lower.contains('phy') ||
        lower.contains('elect') ||
        lower.contains('circuit')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('eng') ||
        lower.contains('liter') ||
        lower.contains('lang')) {
      return Icons.menu_book_rounded;
    }
    if (lower.contains('bio') ||
        lower.contains('chem') ||
        lower.contains('sci') ||
        lower.contains('lab')) {
      return Icons.science_outlined;
    }
    return Icons.school_outlined;
  }

  /// Formats a time range for an attendance record (e.g. "Mon, Sep 15 · 10:00 AM–11:30 AM").
  static String timeRange(AttendanceRecord r) {
    String t(int mins) {
      final h24 = mins ~/ 60;
      final m = (mins % 60).toString().padLeft(2, '0');
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      return '$h12:$m ${h24 >= 12 ? 'PM' : 'AM'}';
    }

    if (r.startMinutes == 0 && r.endMinutes == 0) {
      return weekdayLabel(r.date);
    }
    return '${weekdayLabel(r.date)} · ${t(r.startMinutes)}–${t(r.endMinutes)}';
  }

  /// Formats date string to "EEE, MMM d".
  static String weekdayLabel(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    return DateFormat('EEE, MMM d').format(d);
  }

  /// Checks if two dates represent the exact same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
