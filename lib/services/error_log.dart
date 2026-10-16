import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only crash/error ring buffer. No network, no analytics.
///
/// Keeps the last [maxEntries] errors (time, message, short stack plus the
/// app version / API level captured at install time) in one
/// SharedPreferences key, capped at about [maxBytes]. Safe to call before
/// [init] (entries are held in memory and flushed when prefs are ready).
class ErrorLog {
  static const String _prefsKey = 'ct_error_log_v1';
  static const int maxEntries = 20;
  static const int maxBytes = 50 * 1024;
  static const int _maxMsgLen = 500;
  static const int _maxStackLen = 1500;

  static final List<Map<String, String>> _entries = [];
  static SharedPreferences? _prefs;
  static bool _loaded = false;
  static String _appVersion = 'unknown';
  static String _apiLevel = 'unknown';

  static List<Map<String, String>> get entries =>
      List.unmodifiable(_entries);

  /// Installs FlutterError.onError + PlatformDispatcher.onError handlers.
  /// Call once from main() before runApp.
  static void install({String appVersion = 'unknown', String apiLevel = 'unknown'}) {
    _appVersion = appVersion;
    _apiLevel = apiLevel;
    FlutterError.onError = (details) {
      try {
        record(details.exception, details.stack, 'flutter');
      } catch (_) {}
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        record(error, stack, 'platform');
      } catch (_) {}
      return true;
    };
  }

  static void updateContext({String? appVersion, String? apiLevel}) {
    if (appVersion != null && appVersion.isNotEmpty) {
      _appVersion = appVersion;
    }
    if (apiLevel != null && apiLevel.isNotEmpty) _apiLevel = apiLevel;
  }

  static Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs?.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries.clear();
          for (final e in decoded) {
            if (e is Map && _entries.length < maxEntries) {
              _entries.add({
                for (final kv in e.entries)
                  kv.key.toString(): kv.value?.toString() ?? '',
              });
            }
          }
        }
      }
      _loaded = true;
    } catch (e) {
      debugPrint('ErrorLog init notice: $e');
    }
  }

  /// Records one error. Fire-and-forget; never throws.
  static void record(dynamic error, [StackTrace? stack, String context = 'app']) {
    try {
      final now = DateTime.now().toIso8601String();
      var msg = error?.toString() ?? 'Unknown error';
      if (msg.length > _maxMsgLen) msg = msg.substring(0, _maxMsgLen);
      var st = stack?.toString() ?? '';
      if (st.length > _maxStackLen) st = st.substring(0, _maxStackLen);
      _entries.add({
        't': now,
        'ctx': context,
        'msg': msg,
        'stack': st,
        'v': _appVersion,
        'api': _apiLevel,
      });
      while (_entries.length > maxEntries) {
        _entries.removeAt(0);
      }
      // Enforce the byte cap.
      try {
        while (jsonEncode(_entries).length > maxBytes && _entries.isNotEmpty) {
          _entries.removeAt(0);
        }
      } catch (_) {}
      _persist();
    } catch (_) {}
  }

  static void _persist() {
    try {
      _persistAsync();
    } catch (_) {}
  }

  static Future<void> _persistAsync() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_prefsKey, jsonEncode(_entries));
    } catch (e) {
      debugPrint('ErrorLog persist notice: $e');
    }
  }

  static Future<void> clear() async {
    try {
      _entries.clear();
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(_prefsKey);
    } catch (e) {
      debugPrint('ErrorLog clear notice: $e');
    }
  }

  static bool get isLoaded => _loaded;
}
