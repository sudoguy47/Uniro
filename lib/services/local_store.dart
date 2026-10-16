import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static LocalStore? _instance;
  static LocalStore get instance => _instance ??= LocalStore._();
  LocalStore._();

  /// Current schema version. Bump when stored formats change and add the
  /// migration in [migrateSchema].
  static const int schemaVersion = 1;
  static const String _schemaKey = 'ct_schema';

  SharedPreferences? _prefs;

  /// Set when any corrupt payload was backed up during this boot.
  /// Read after bootstrap to show the one-time recovery banner.
  bool _recovered = false;
  bool get hadRecovery => _recovered;
  void markRecovery() => _recovered = true;
  void clearRecoveryFlag() => _recovered = false;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await ensureSchema();
    } catch (e) {
      debugPrint('LocalStore init notice: $e');
    }
  }

  /// Ensures the schema version key exists and runs [migrateSchema] on
  /// version change. No-op today; hook for future migrations.
  Future<void> ensureSchema() async {
    try {
      final raw = _prefs?.getInt(_schemaKey);
      if (raw == null) {
        await _prefs?.setInt(_schemaKey, schemaVersion);
        return;
      }
      if (raw != schemaVersion) {
        await migrateSchema(raw, schemaVersion);
        await _prefs?.setInt(_schemaKey, schemaVersion);
      }
    } catch (e) {
      debugPrint('LocalStore schema notice: $e');
    }
  }

  /// Migration hook. Intentionally a no-op for schema v1.
  Future<void> migrateSchema(int from, int to) async {
    debugPrint('LocalStore migrateSchema $from -> $to (no-op)');
  }

  void save(String key, dynamic data) {
    try {
      _prefs?.setString('ct_$key', jsonEncode(data));
    } catch (e) {
      debugPrint('LocalStore save notice ($key): $e');
    }
  }

  Future<void> remove(String key) async {
    try {
      await _prefs?.remove('ct_$key');
    } catch (e) {
      debugPrint('LocalStore remove notice ($key): $e');
    }
  }

  /// Never throws. On corrupt JSON the bad raw string is moved to
  /// `ct_<key>.corrupt` (latest only), the key is treated as empty,
  /// and [hadRecovery] is set.
  dynamic load(String key) {
    try {
      final raw = _prefs?.getString('ct_$key');
      if (raw == null) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        _backupCorrupt(key, raw);
        return null;
      }
    } catch (e) {
      debugPrint('LocalStore load notice ($key): $e');
      return null;
    }
  }

  void _backupCorrupt(String key, String raw) {
    try {
      _prefs?.setString('ct_$key.corrupt', raw);
      _prefs?.remove('ct_$key');
    } catch (e) {
      debugPrint('LocalStore backup notice ($key): $e');
    }
    _recovered = true;
    debugPrint('LocalStore: corrupt "$key" backed up to "$key.corrupt"');
  }

  bool get isOnboardingDone {
    final raw = _prefs?.getString('ct_onboarding_done');
    if (raw == null) return false;
    try {
      return jsonDecode(raw) == true;
    } catch (_) {
      return false;
    }
  }

  void setOnboardingDone(bool done) {
    save('onboarding_done', done);
  }
}
