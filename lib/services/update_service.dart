import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../core/logger.dart';
import 'device_channel.dart';
import 'local_store.dart';

/// GitHub-Releases in-app update checker for the fully-offline Uniro app.
///
/// Flow: [checkForUpdate] reads the latest release, compares it against
/// the installed version, and returns an [AppUpdate] when a newer build
/// exists. Everything is wrapped in try/catch with a short timeout —
/// no internet or any error fails silently and NEVER blocks the app.
///
/// GitHub account/organisation that owns the `uniro` repository.
const kGithubUser = 'sudoguy47';

/// Repository name holding the releases.
const kGithubRepo = 'uniro';

/// Set by the user via "Skip this version" (persisted in
/// SharedPreferences through [LocalStore], so it survives restarts).
const _skipKey = 'update_skip_tag';

/// Update info for one newer GitHub release.
class AppUpdate {
  const AppUpdate({
    required this.tag,
    required this.version,
    required this.notes,
    required this.apkUrl,
    this.sha256,
    this.sha256AssetUrl,
  });

  /// Raw tag, e.g. "v1.2.0".
  final String tag;

  /// Pretty version without prefix/build, e.g. "1.2.0".
  final String version;

  /// Release notes (`body`), may be empty.
  final String notes;

  /// Direct download URL of the release `.apk` asset.
  final String apkUrl;

  /// Expected SHA-256 checksum (lowercase 64-char hex), if specified.
  final String? sha256;

  /// Optional URL of a .sha256 asset sidecar.
  final String? sha256AssetUrl;

  Map<String, dynamic> toJson() => {
        'tag': tag,
        'version': version,
        'notes': notes,
        'apkUrl': apkUrl,
        if (sha256 != null) 'sha256': sha256,
        if (sha256AssetUrl != null) 'sha256AssetUrl': sha256AssetUrl,
      };

  factory AppUpdate.fromJson(Map<String, dynamic> json) => AppUpdate(
        tag: (json['tag'] as String?) ?? '',
        version: (json['version'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        apkUrl: (json['apkUrl'] as String?) ?? '',
        sha256: json['sha256'] as String?,
        sha256AssetUrl: json['sha256AssetUrl'] as String?,
      );
}

/// Compares dotted versions numerically: "1.10.0" > "1.9.0".
/// Strips a leading "v"/"V" and any "+build" suffix first.
/// Returns <0 / 0 / >0 like [Comparable.compareTo].
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split('+').first;
    return s.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Returns the pretty version of a tag ("v1.2.0+3" -> "1.2.0").
String prettyVersion(String tag) {
  var s = tag.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  return s.split('+').first;
}

/// User-facing failure from download / verify / install steps.
class UpdateException implements Exception {
  UpdateException(this.message);
  final String message;
  @override
  String toString() => 'UpdateException: $message';
}

/// Picks the correct APK download URL from a release `assets` list.
/// Skips checksum/signature sidecars and non-APK files; prefers an asset
/// whose *name* ends in `.apk`. Pure — unit-tested.
String? selectApkAsset(dynamic assets) {
  if (assets is! List) return null;
  String? fallback;
  for (final a in assets) {
    if (a is! Map) continue;
    final url = (a['browser_download_url'] as String?) ?? '';
    final name = (a['name'] as String?) ?? '';
    if (url.isEmpty) continue;
    if (name.toLowerCase().endsWith('.apk')) return url;
    fallback ??= url.toLowerCase().endsWith('.apk') ? url : null;
  }
  return fallback;
}

/// Extracts a 64-character lowercase SHA-256 hex string from the release notes/body.
/// Supports formats like "SHA-256: <hash>", "sha256: <hash>", "checksum: <hash>",
/// or standalone 64-char hex tokens.
String? extractSha256FromBody(String? body) {
  if (body == null || body.isEmpty) return null;
  final labeled = RegExp(
    r'(?:sha-?256|checksum)[\s:=]+([a-fA-F0-9]{64})',
    caseSensitive: false,
  ).firstMatch(body);
  if (labeled != null) return labeled.group(1)!.toLowerCase();

  final standalone =
      RegExp(r'(?:^|\s)([a-fA-F0-9]{64})(?:\s|$)', multiLine: true)
          .firstMatch(body);
  if (standalone != null) return standalone.group(1)!.toLowerCase();

  return null;
}

/// Finds the URL of a .sha256 or .sha256.txt asset sidecar, if present.
String? selectSha256Asset(dynamic assets) {
  if (assets is! List) return null;
  for (final a in assets) {
    if (a is! Map) continue;
    final url = (a['browser_download_url'] as String?) ?? '';
    final name = (a['name'] as String?) ?? '';
    if (url.isEmpty) continue;
    final lower = name.toLowerCase();
    if (lower.endsWith('.sha256') || lower.endsWith('.sha256.txt')) {
      return url;
    }
  }
  return null;
}

/// Builds an [AppUpdate] from one decoded release JSON object.
/// Returns null for drafts, prereleases, missing/empty tags,
/// equal-or-older versions, skipped tags, and releases without an APK.
/// Pure — unit-tested.
AppUpdate? parseUpdateResponse(
  Map<String, dynamic> json, {
  required String installed,
  String? skipped,
}) {
  try {
    if (json['draft'] == true || json['prerelease'] == true) return null;
    final tag = (json['tag_name'] as String?) ?? '';
    if (tag.isEmpty) return null;
    if (compareVersions(tag, installed) <= 0) return null;
    if (skipped != null && skipped == tag) return null;
    final apkUrl = selectApkAsset(json['assets']);
    if (apkUrl == null || apkUrl.isEmpty) return null;
    final body = (json['body'] as String?) ?? '';
    final bodySha = extractSha256FromBody(body);
    final assetShaUrl = selectSha256Asset(json['assets']);
    return AppUpdate(
      tag: tag,
      version: prettyVersion(tag),
      notes: body,
      apkUrl: apkUrl,
      sha256: bodySha,
      sha256AssetUrl: assetShaUrl,
    );
  } catch (_) {
    return null;
  }
}

/// Checks GitHub Releases for a newer build.
///
/// When [force] is false and [client] is null, checks are throttled to at most
/// once per 6 hours. If throttled, returns the cached update (if still valid) or null.
///
/// If GitHub returns 403 or 429 (rate-limited):
/// - When [force] is true, throws [UpdateException] with a friendly retry message.
/// - When [force] is false, logs via [AppLog.w] and returns null.
Future<AppUpdate?> checkForUpdate({
  bool force = false,
  http.Client? client,
  String? installedOverride,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  const sixHoursMs = 6 * 60 * 60 * 1000;

  String installed;
  if (installedOverride != null) {
    installed = installedOverride;
  } else {
    try {
      final info = await PackageInfo.fromPlatform();
      // package_info_plus version is "1.0.1+2003": compare the dotted part.
      installed = info.version;
    } catch (_) {
      installed = '0.0.0';
    }
  }

  final skipped = LocalStore.instance.load(_skipKey) as String?;

  // 6-hour throttle for automatic background checks
  if (!force && client == null) {
    final lastCheck = LocalStore.instance.load('update_last_check_ms');
    if (lastCheck is num && (now - lastCheck) < sixHoursMs) {
      AppLog.d('Skipping automatic update check (checked within 6h).');
      final cachedJson = LocalStore.instance.load('update_cached_release');
      if (cachedJson is Map) {
        try {
          final cachedUpdate =
              AppUpdate.fromJson(Map<String, dynamic>.from(cachedJson));
          if (compareVersions(cachedUpdate.tag, installed) > 0 &&
              (skipped == null || skipped != cachedUpdate.tag)) {
            return cachedUpdate;
          }
        } catch (_) {}
      }
      return null;
    }
  }

  final http.Client httpClient = client ?? http.Client();
  final bool ownsClient = client == null;
  try {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$kGithubUser/$kGithubRepo/releases/latest',
    );
    final res = await httpClient
        .get(uri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 403 || res.statusCode == 429) {
      AppLog.w('Update check rate-limited (${res.statusCode})');
      if (force) {
        throw UpdateException(
          'Update check rate-limited by GitHub. Please try again in a few hours.',
        );
      }
      return null;
    }

    if (res.statusCode == 404) {
      // No published releases yet (or repo invisible).
      return null;
    }

    if (res.statusCode != 200) {
      if (force) {
        throw UpdateException(
          'Update check failed (server ${res.statusCode}). Try again later.',
        );
      }
      return null;
    }

    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) return null;

    final update =
        parseUpdateResponse(json, installed: installed, skipped: skipped);

    // Cache successful check result and timestamp
    LocalStore.instance.save('update_last_check_ms', now);
    if (update != null) {
      LocalStore.instance.save('update_cached_release', update.toJson());
    } else {
      LocalStore.instance.save('update_cached_release', null);
    }

    return update;
  } on UpdateException {
    rethrow;
  } catch (e, st) {
    AppLog.w('Update check notice: $e', e, st);
    if (force) {
      throw UpdateException(
        'Could not connect to update service. Check your connection.',
      );
    }
    return null;
  } finally {
    if (ownsClient) httpClient.close();
  }
}

/// Downloads [update]'s APK to the app cache directory, reporting
/// `(receivedBytes, totalBytes?)` via [onProgress]. Aborts promptly when
/// [isCancelled] returns true (partial file is deleted).
/// Throws [UpdateException] with a user-readable message on failure.
Future<File> downloadUpdate(
  AppUpdate update, {
  void Function(int received, int? total)? onProgress,
  bool Function()? isCancelled,
}) async {
  final client = http.Client();
  File? outFile;
  try {
    final req = http.Request('GET', Uri.parse(update.apkUrl));
    req.headers['Accept'] = 'application/octet-stream';
    final res = await client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw UpdateException(
          'Download failed (server ${res.statusCode}). Try again.');
    }
    final cacheDir = await DeviceChannel.getCacheDir();
    if (cacheDir == null || cacheDir.isEmpty) {
      throw UpdateException('Cannot access app storage.');
    }
    final safeTag = update.tag.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    outFile = File('$cacheDir/uniro-$safeTag.apk');
    if (await outFile.exists()) await outFile.delete();
    final sink = outFile.openWrite();
    try {
      var received = 0;
      final total = res.contentLength;
      await for (final chunk in res.stream.timeout(const Duration(seconds: 30))) {
        if (isCancelled?.call() == true) {
          throw UpdateException('cancelled');
        }
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }
    if (isCancelled?.call() == true || !await outFile.exists()) {
      try {
        await outFile.delete();
      } catch (_) {}
      throw UpdateException('cancelled');
    }
    return outFile;
  } on UpdateException {
    if (isCancelled?.call() == true) {
      try {
        if (outFile != null && await outFile.exists()) await outFile.delete();
      } catch (_) {}
    }
    rethrow;
  } on TimeoutException {
    try {
      if (outFile != null && await outFile.exists()) await outFile.delete();
    } catch (_) {}
    throw UpdateException('Download timed out. Connection was inactive for 30s. Please retry.');
  } on SocketException {
    try {
      if (outFile != null && await outFile.exists()) await outFile.delete();
    } catch (_) {}
    throw UpdateException('Network connection error. Check your internet connection and retry.');
  } catch (e) {
    try {
      if (outFile != null && await outFile.exists()) await outFile.delete();
    } catch (_) {}
    throw UpdateException('Download failed. Check connection and retry.');
  } finally {
    client.close();
  }
}

/// Result of pre-install verification of a downloaded APK.
class InstallReadiness {
  const InstallReadiness({
    required this.ok,
    required this.reason,
    this.packageName = '',
    this.versionCode = 0,
  });
  final bool ok;
  final String reason;
  final String packageName;
  final int versionCode;
}

/// Verifies the SHA-256 checksum of [apk] against [update].
/// If the release provides a checksum (in body or as a .sha256 asset), it is verified.
/// If no checksum was provided, logs an informational notice and returns ok: true.
Future<InstallReadiness> verifyApkChecksum(
  File apk,
  AppUpdate update, {
  http.Client? client,
}) async {
  String? expectedSha = update.sha256;
  if ((expectedSha == null || expectedSha.isEmpty) &&
      update.sha256AssetUrl != null &&
      update.sha256AssetUrl!.isNotEmpty) {
    final httpClient = client ?? http.Client();
    final ownsClient = client == null;
    try {
      final res = await httpClient
          .get(Uri.parse(update.sha256AssetUrl!))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final match = RegExp(r'[a-fA-F0-9]{64}').firstMatch(res.body);
        if (match != null) {
          expectedSha = match.group(0)!.toLowerCase();
        }
      }
    } catch (e, st) {
      AppLog.w('Could not download sha256 asset sidecar: $e', e, st);
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  if (expectedSha == null || expectedSha.isEmpty) {
    AppLog.i(
        'No SHA-256 checksum provided for release ${update.tag}; proceeding with standard signature verification.');
    return const InstallReadiness(ok: true, reason: 'No checksum provided');
  }

  try {
    final digest = await sha256.bind(apk.openRead()).first;
    final actualSha = digest.toString().toLowerCase();
    if (actualSha != expectedSha.toLowerCase()) {
      AppLog.w(
          'SHA-256 mismatch for ${apk.path}! Expected: $expectedSha, Actual: $actualSha');
      try {
        if (await apk.exists()) await apk.delete();
      } catch (_) {}
      return const InstallReadiness(
        ok: false,
        reason: 'SHA-256 checksum mismatch — download may be corrupted.',
      );
    }
    AppLog.i('SHA-256 checksum verified ($actualSha).');
    return const InstallReadiness(ok: true, reason: 'Checksum verified');
  } catch (e, st) {
    AppLog.w('Error computing SHA-256 checksum: $e', e, st);
    return const InstallReadiness(
      ok: false,
      reason: 'Failed to verify file integrity.',
    );
  }
}

/// Verifies a downloaded APK before install: SHA-256 checksum (if provided),
/// same applicationId, higher versionCode than installed, and identical signing certificate.
/// Never throws — failures return `ok: false` with a user-readable reason.
Future<InstallReadiness> checkInstallReadiness(
  File apk, {
  AppUpdate? update,
  http.Client? client,
}) async {
  try {
    if (!await apk.exists()) {
      return const InstallReadiness(
          ok: false, reason: 'Downloaded file is missing.');
    }
    if (update != null) {
      final checksumCheck =
          await verifyApkChecksum(apk, update, client: client);
      if (!checksumCheck.ok) {
        return checksumCheck;
      }
    }
    final info = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(info.buildNumber) ?? 0;
    final res = await DeviceChannel.verifyApk(
      apk.path,
      expectedPackage: info.packageName,
      minVersionCode: currentCode + 1,
    );
    if (res == null) {
      return const InstallReadiness(
          ok: false, reason: 'Could not read the APK file.');
    }
    if (res['packageOk'] != true) {
      return InstallReadiness(
          ok: false,
          reason: 'Wrong app package (${res['packageName'] ?? '?'}).',
          packageName: '${res['packageName'] ?? ''}');
    }
    if (res['upgradeOk'] != true) {
      return InstallReadiness(
          ok: false,
          reason: 'This file is not newer than the installed app.',
          packageName: '${res['packageName'] ?? ''}',
          versionCode: (res['versionCode'] as num?)?.toInt() ?? 0);
    }
    if (res['signatureOk'] != true) {
      return const InstallReadiness(
          ok: false,
          reason: 'Signature mismatch — install blocked for safety.');
    }
    return InstallReadiness(
        ok: true,
        reason: 'verified',
        packageName: '${res['packageName'] ?? ''}',
        versionCode: (res['versionCode'] as num?)?.toInt() ?? 0);
  } catch (e, st) {
    AppLog.w('install readiness notice: $e', e, st);
    return const InstallReadiness(
        ok: false, reason: 'Verification failed. Try again.');
  }
}

/// Remembers [tag] as skipped so the startup dialog stops asking for it.
void skipUpdateVersion(String tag) {
  try {
    LocalStore.instance.save(_skipKey, tag);
  } catch (e, st) {
    AppLog.w('skip version notice: $e', e, st);
  }
}

/// Opens Android's package installer for a verified [apk].
/// Returns `'launched'` or `'needPermission'` (user must allow "install
/// unknown apps" in system settings, then retry). Throws [UpdateException]
/// when no installer handles the file. NOTE: Android always asks the user
/// to confirm — silent background installs are impossible for this app.
Future<String> launchInstaller(File apk) async {
  try {
    final res = await DeviceChannel.installApk(apk.path);
    if (res == 'launched' || res == 'needPermission') return res;
    throw UpdateException('Could not open the installer.');
  } on UpdateException {
    rethrow;
  } on PlatformException catch (e) {
    throw UpdateException(e.message ?? 'Could not open the installer.');
  } catch (e) {
    if (e is UpdateExceptionBridge) throw UpdateException(e.message);
    throw UpdateException('Could not open the installer.');
  }
}

/// Installed version string for "Check for updates" rows, e.g. "1.0.1".
Future<String> installedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '';
  }
}
