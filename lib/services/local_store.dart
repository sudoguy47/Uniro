import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static LocalStore? _instance;
  static LocalStore get instance => _instance ??= LocalStore._();
  LocalStore._();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void save(String key, dynamic data) {
    _prefs?.setString('ct_$key', jsonEncode(data));
  }

  Future<void> remove(String key) async {
    await _prefs?.remove('ct_$key');
  }

  dynamic load(String key) {
    final raw = _prefs?.getString('ct_$key');
    if (raw == null) return null;
    return jsonDecode(raw);
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
