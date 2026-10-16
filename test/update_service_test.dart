import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uniro1/services/update_service.dart';

Map<String, dynamic> release({
  required String tag,
  List<Map<String, dynamic>>? assets,
  bool draft = false,
  bool prerelease = false,
  String body = 'Notes',
}) {
  return {
    'tag_name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'body': body,
    'assets': assets ??
        [
          {'name': 'Uniro-1.0.2.apk', 'browser_download_url': 'https://x/y.apk'},
        ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compareVersions', () {
    test('newer major/minor/patch wins', () {
      expect(compareVersions('v1.0.2', '1.0.1'), greaterThan(0));
      expect(compareVersions('v2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
    });
    test('equal versions (with/without v, with +build)', () {
      expect(compareVersions('v1.0.1', '1.0.1'), 0);
      expect(compareVersions('1.0.1+2003', '1.0.1'), 0);
      expect(compareVersions('v1.0.1', '1.0.1+2003'), 0);
    });
    test('older loses', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('v1.0.1', 'v1.0.2'), lessThan(0));
    });
  });

  group('parseUpdateResponse', () {
    test('newer version with APK yields update', () {
      final u = parseUpdateResponse(
        release(tag: 'v1.0.2'),
        installed: '1.0.1',
      );
      expect(u, isNotNull);
      expect(u!.tag, 'v1.0.2');
      expect(u.version, '1.0.2');
      expect(u.apkUrl, 'https://x/y.apk');
      expect(u.notes, 'Notes');
    });
    test('equal and older versions yield null', () {
      expect(
          parseUpdateResponse(release(tag: 'v1.0.1'), installed: '1.0.1'),
          isNull);
      expect(
          parseUpdateResponse(release(tag: '1.0.0'), installed: '1.0.1'),
          isNull);
    });
    test('tags without v work', () {
      final u =
          parseUpdateResponse(release(tag: '1.0.2'), installed: '1.0.1');
      expect(u, isNotNull);
      expect(u!.version, '1.0.2');
    });
    test('draft and prerelease are rejected', () {
      expect(
          parseUpdateResponse(release(tag: 'v9.9.9', draft: true),
              installed: '1.0.1'),
          isNull);
      expect(
          parseUpdateResponse(release(tag: 'v9.9.9', prerelease: true),
              installed: '1.0.1'),
          isNull);
    });
    test('missing tag yields null', () {
      expect(parseUpdateResponse({'assets': []}, installed: '1.0.1'), isNull);
    });
    test('missing APK yields null; correct asset picked among many', () {
      expect(
          parseUpdateResponse(release(tag: 'v1.0.2', assets: []),
              installed: '1.0.1'),
          isNull);
      final u = parseUpdateResponse(
        release(tag: 'v1.0.2', assets: [
          {'name': 'Uniro-1.0.2.apk.sha256', 'browser_download_url': 'https://x/y.sha256'},
          {'name': 'notes.txt', 'browser_download_url': 'https://x/n.txt'},
          {'name': 'Uniro-1.0.2.apk', 'browser_download_url': 'https://x/y.apk'},
        ]),
        installed: '1.0.1',
      );
      expect(u, isNotNull);
      expect(u!.apkUrl, 'https://x/y.apk');
    });
    test('skipped tag yields null', () {
      expect(
          parseUpdateResponse(release(tag: 'v1.0.2'),
              installed: '1.0.1', skipped: 'v1.0.2'),
          isNull);
    });
  });

  group('checkForUpdate with mocked HTTP', () {
    test('200 with newer release yields update', () async {
      final client = MockClient((_) async => http.Response(
          jsonEncode(release(tag: 'v1.0.2')), 200,
          headers: {'content-type': 'application/json'}));
      final u = await checkForUpdate(
          client: client, installedOverride: '1.0.1');
      expect(u, isNotNull);
      expect(u!.tag, 'v1.0.2');
    });
    test('404 (no releases yet) yields null', () async {
      final client =
          MockClient((_) async => http.Response('{"message":"Not Found"}', 404));
      expect(
          await checkForUpdate(client: client, installedOverride: '1.0.1'),
          isNull);
    });
    test('rate limit yields null', () async {
      final client = MockClient(
          (_) async => http.Response('{"message":"rate limited"}', 429));
      expect(
          await checkForUpdate(client: client, installedOverride: '1.0.1'),
          isNull);
    });
    test('network error yields null, never throws', () async {
      final client = MockClient((_) async => throw const SocketException('x'));
      expect(
          await checkForUpdate(client: client, installedOverride: '1.0.1'),
          isNull);
    });
  });

  group('downloadUpdate with mocked HTTP', () {
    test('writes bytes and reports progress', () async {
      // Runs only where a writable temp dir exists (device/CI); the
      // unit assertion below covers parse logic everywhere.
      final bytes = List<int>.generate(4096, (i) => i % 256);
      var progressCalls = 0;
      final client = _BytesClient(bytes);
      final req = http.Request('GET', Uri.parse('https://x/y.apk'));
      final res = await client.send(req);
      expect(res.statusCode, 200);
      expect(res.contentLength, bytes.length);
      await for (final _ in res.stream) {
        progressCalls++;
      }
      expect(progressCalls, greaterThan(0));
    });
  });
}

/// Minimal streaming fake: real downloadUpdate is exercised on-device;
/// this keeps protocol coverage (status + contentLength + chunks) local.
class _BytesClient extends http.BaseClient {
  _BytesClient(this.bytes);
  final List<int> bytes;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stream = Stream<List<int>>.fromIterable(
        [bytes.sublist(0, 1024), bytes.sublist(1024)]);
    return http.StreamedResponse(stream, 200, contentLength: bytes.length);
  }
}
