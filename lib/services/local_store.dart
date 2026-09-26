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

  dynamic load(String key) {
    final raw = _prefs?.getString('ct_$key');
    if (raw == null) return null;
    return jsonDecode(raw);
  }
}
