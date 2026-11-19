import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../core/logger.dart';
import '../models/note.dart';

/// Exception thrown when cryptographic operations or key operations fail.
class NoteSecurityException implements Exception {
  final String message;
  const NoteSecurityException(this.message);

  @override
  String toString() => 'NoteSecurityException: $message';
}

/// Service managing biometric / device credential authentication and AES-GCM
/// at-rest encryption for locked notes using an Android Keystore backed key.
class NoteSecurityService {
  static const String _keyStorageKey = 'uniro_notes_master_key_v1';
  static NoteSecurityService? _instance;
  static NoteSecurityService get instance => _instance ??= NoteSecurityService();
  static set instance(NoteSecurityService? s) => _instance = s;

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _storage;
  final AesGcm _cipher;

  // In-memory cached key bytes once retrieved/generated in this app session
  List<int>? _cachedKeyBytes;

  NoteSecurityService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? storage,
    AesGcm? cipher,
    List<int>? masterKey,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _cipher = cipher ?? AesGcm.with256bits(),
        _cachedKeyBytes = masterKey;

  /// Creates a test instance that operates completely in-memory without platform channels.
  factory NoteSecurityService.test({
    List<int>? masterKey,
    bool canAuth = true,
  }) {
    return NoteSecurityService(
      localAuth: _MockLocalAuthForTest(canAuth: canAuth),
      masterKey: masterKey ?? List<int>.filled(32, 7),
    );
  }

  /// Checks if the device has biometric sensors or device security (PIN/pattern/password) set up.
  Future<bool> canAuthenticate() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return isSupported || canCheck;
    } catch (e, st) {
      AppLog.w('Error checking device authentication support: $e', e, st);
      return false;
    }
  }

  /// Prompts the user to authenticate using biometrics or their device screen lock PIN/passcode.
  Future<bool> authenticate({String localizedReason = 'Authenticate to access locked note'}) async {
    try {
      final canAuth = await canAuthenticate();
      if (!canAuth) {
        return false;
      }
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (e, st) {
      AppLog.w('Authentication error: $e', e, st);
      return false;
    }
  }

  /// Retrieves or generates a secure 256-bit AES master key from secure storage.
  Future<List<int>> getMasterKey() async {
    if (_cachedKeyBytes != null) return _cachedKeyBytes!;

    try {
      final storedBase64 = await _storage.read(key: _keyStorageKey);
      if (storedBase64 != null && storedBase64.isNotEmpty) {
        final decoded = base64Decode(storedBase64);
        if (decoded.length == 32) {
          _cachedKeyBytes = decoded;
          return decoded;
        }
      }

      // Generate a new 256-bit (32 bytes) cryptographically secure random key
      final random = Random.secure();
      final newKey = List<int>.generate(32, (_) => random.nextInt(256));
      await _storage.write(key: _keyStorageKey, value: base64Encode(newKey));
      _cachedKeyBytes = newKey;
      return newKey;
    } catch (e, st) {
      AppLog.e('Failed to read or write master encryption key', e, st);
      throw NoteSecurityException('Could not access secure storage for encryption keys: $e');
    }
  }

  /// Encrypts note blocks using AES-GCM (256-bit key, 96-bit nonce, 128-bit MAC).
  /// Returns a combined base64 payload: [12 bytes nonce] + [16 bytes tag] + [ciphertext].
  Future<String> encryptBlocks(List<NoteBlock> blocks, {List<int>? keyOverride}) async {
    final keyBytes = keyOverride ?? await getMasterKey();
    final secretKey = SecretKey(keyBytes);

    final rawJson = jsonEncode(blocks.map((b) => b.toJson()).toList());
    final clearTextBytes = utf8.encode(rawJson);

    final secretBox = await _cipher.encrypt(
      clearTextBytes,
      secretKey: secretKey,
    );

    // Format: nonce (12 bytes) + mac (16 bytes) + ciphertext
    final payloadBytes = <int>[
      ...secretBox.nonce,
      ...secretBox.mac.bytes,
      ...secretBox.cipherText,
    ];

    return base64Encode(payloadBytes);
  }

  /// Decrypts an AES-GCM base64 payload back into a list of [NoteBlock]s.
  Future<List<NoteBlock>> decryptBlocks(String encryptedPayload, {List<int>? keyOverride}) async {
    final keyBytes = keyOverride ?? await getMasterKey();
    final secretKey = SecretKey(keyBytes);

    final payloadBytes = base64Decode(encryptedPayload);
    if (payloadBytes.length < 28) {
      throw const NoteSecurityException('Encrypted note payload is corrupted or too short');
    }

    final nonce = payloadBytes.sublist(0, 12);
    final macBytes = payloadBytes.sublist(12, 28);
    final cipherText = payloadBytes.sublist(28);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(macBytes),
    );

    try {
      final decryptedBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      final jsonStr = utf8.decode(decryptedBytes);
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((item) => NoteBlock.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      throw NoteSecurityException('Failed to decrypt note content. Incorrect key or corrupted payload: $e');
    }
  }

  /// For testing or session reset.
  void debugReset() {
    _cachedKeyBytes = null;
  }
}

class _MockLocalAuthForTest extends LocalAuthentication {
  final bool canAuth;
  _MockLocalAuthForTest({this.canAuth = true});

  @override
  Future<bool> isDeviceSupported() async => canAuth;

  @override
  Future<bool> get canCheckBiometrics async => canAuth;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic>? authMessages,
    AuthenticationOptions? options,
  }) async => canAuth;
}
