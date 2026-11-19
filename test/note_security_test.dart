import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uniro1/models/note.dart';
import 'package:uniro1/services/note_security_service.dart';

class MockLocalAuthFailure extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic>? authMessages,
    AuthenticationOptions? options,
  }) async {
    return false; // Simulated failed authentication or cancelled by user
  }
}

class MockLocalAuthNoCredentials extends LocalAuthentication {
  @override
  Future<bool> isDeviceSupported() async => false;

  @override
  Future<bool> get canCheckBiometrics async => false;
}

void main() {
  group('NoteSecurityService AES-GCM & Authentication Tests', () {
    final testKey = List<int>.generate(32, (i) => (i * 7 + 13) % 256);

    test('Encrypt and decrypt blocks round-trip preserves all data', () async {
      final service = NoteSecurityService();
      final blocks = [
        const NoteBlock(
          id: 'b1',
          type: BlockType.paragraph,
          text: 'Secret top secret journal entry',
          style: NoteBlockStyle(bold: true, fontSize: 18.0),
        ),
        const NoteBlock(
          id: 'b2',
          type: BlockType.checklist,
          text: 'Confidential action item',
          checked: true,
        ),
        const NoteBlock(
          id: 'b3',
          type: BlockType.quote,
          text: 'Private quote',
        ),
      ];

      final encryptedPayload = await service.encryptBlocks(blocks, keyOverride: testKey);
      expect(encryptedPayload, isNotEmpty);
      expect(encryptedPayload.contains('Secret'), isFalse);
      expect(encryptedPayload.contains('Confidential'), isFalse);

      final decryptedBlocks = await service.decryptBlocks(encryptedPayload, keyOverride: testKey);
      expect(decryptedBlocks.length, equals(3));
      expect(decryptedBlocks[0].id, equals('b1'));
      expect(decryptedBlocks[0].text, equals('Secret top secret journal entry'));
      expect(decryptedBlocks[0].style.bold, isTrue);
      expect(decryptedBlocks[1].type, equals(BlockType.checklist));
      expect(decryptedBlocks[1].checked, isTrue);
      expect(decryptedBlocks[2].type, equals(BlockType.quote));
      expect(decryptedBlocks[2].text, equals('Private quote'));
    });

    test('Decryption with tampered payload throws NoteSecurityException', () async {
      final service = NoteSecurityService();
      final blocks = [
        const NoteBlock(id: 'b1', type: BlockType.paragraph, text: 'Sensitive financial information'),
      ];

      final encryptedPayload = await service.encryptBlocks(blocks, keyOverride: testKey);
      final rawBytes = base64Decode(encryptedPayload);

      // Flip a bit in the ciphertext / MAC region
      rawBytes[rawBytes.length - 1] ^= 0x01;
      final tamperedPayload = base64Encode(rawBytes);

      expect(
        () async => await service.decryptBlocks(tamperedPayload, keyOverride: testKey),
        throwsA(isA<NoteSecurityException>()),
      );
    });

    test('Decryption with truncated payload throws NoteSecurityException', () async {
      final service = NoteSecurityService();
      // Payload shorter than 28 bytes (12 bytes nonce + 16 bytes MAC)
      final tooShortPayload = base64Encode([1, 2, 3, 4, 5]);

      expect(
        () async => await service.decryptBlocks(tooShortPayload, keyOverride: testKey),
        throwsA(isA<NoteSecurityException>()),
      );
    });

    test('Authentication failure is handled cleanly', () async {
      final mockAuth = MockLocalAuthFailure();
      final service = NoteSecurityService(localAuth: mockAuth);

      final canAuth = await service.canAuthenticate();
      expect(canAuth, isTrue);

      final didAuth = await service.authenticate(localizedReason: 'Test reason');
      expect(didAuth, isFalse);
    });

    test('Device with no biometrics or screen lock is detected and rejected', () async {
      final mockAuth = MockLocalAuthNoCredentials();
      final service = NoteSecurityService(localAuth: mockAuth);

      final canAuth = await service.canAuthenticate();
      expect(canAuth, isFalse);

      final didAuth = await service.authenticate(localizedReason: 'Test reason');
      expect(didAuth, isFalse);
    });

    test('Note preview and serialization protect locked notes content', () {
      final lockedNote = Note(
        id: 'note_123',
        title: 'Secret Notes',
        blocks: const [
          NoteBlock(id: 'b1', type: BlockType.paragraph, text: 'Should never appear in preview or raw JSON'),
        ],
        encryptedPayload: 'mock_encrypted_base64_payload',
        isLocked: true,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Preview text must mask content
      expect(lockedNote.previewText, equals('Locked Note'));

      // Serialization must omit plaintext blocks
      final jsonMap = lockedNote.toJson();
      expect(jsonMap['blocks'], isEmpty);
      expect(jsonMap['encryptedPayload'], equals('mock_encrypted_base64_payload'));
      expect(jsonMap['isLocked'], isTrue);

      // Deserialization restores encryptedPayload
      final restored = Note.fromJson(jsonMap);
      expect(restored.encryptedPayload, equals('mock_encrypted_base64_payload'));
      expect(restored.isLocked, isTrue);
      expect(restored.blocks, isEmpty);
    });
  });
}
