import 'dart:math';

/// Zero-dependency unique ID generator (hex timestamp + secure random).
/// Collision-safe for local on-device data. Single shared helper so every
/// model mints ids the same way.
String newLocalId() {
  final r = Random.secure();
  final rand = r.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}$rand';
}
