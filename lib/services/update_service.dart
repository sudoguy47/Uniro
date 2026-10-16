import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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
  });

  /// Raw tag, e.g. "v1.2.0".
  final String tag;

  /// Pretty version without prefix/build, e.g. "1.2.0".
  final String version;

  /// Release notes (`body`), may be empty.
  final String notes;

  /// Direct download URL of the release `.apk` asset.
  final String apkUrl;
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
    return AppUpdate(
      tag: tag,
      version: prettyVersion(tag),
      notes: (json['body'] as String?) ?? '',
      apkUrl: apkUrl,
    );
  } catch (_) {
    return null;
  }
}

/// Checks GitHub Releases for a newer build.
///
/// Returns an [AppUpdate] when the latest *stable* release is newer than
/// both the installed version AND the skipped version, otherwise null.
/// Never throws — offline, rate limits (403/429), 404s, or any error
/// yield null. Optional [client]/[installedOverride] exist for tests.
Future<AppUpdate?> checkForUpdate(
    {http.Client? client, String? installedOverride}) async {
  final http.Client httpClient = client ?? http.Client();
  final bool ownsClient = client == null;
  try {
    String installed;
    if (installedOverride != null) {
      installed = installedOverride;
    } else {
      final info = await PackageInfo.fromPlatform();
      // package_info_plus version is "1.0.1+2003": compare the dotted part.
      installed = info.version;
    }

    final uri = Uri.https(
      'api.github.com',
      '/repos/$kGithubUser/$kGithubRepo/releases/latest',
    );
    final res = await httpClient
        .get(uri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 403 || res.statusCode == 429) {
      debugPrint('update check rate-limited (${res.statusCode})');
      return null;
    }
    if (res.statusCode == 404) {
      // No published releases yet (or repo invisible).
      return null;
    }
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) return null;
    final skipped = LocalStore.instance.load(_skipKey) as String?;
    return parseUpdateResponse(json, installed: installed, skipped: skipped);
  } catch (e) {
    debugPrint('update check notice: $e');
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
      await for (final chunk in res.stream) {
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
    rethrow;
  } catch (e) {
    try {
      await outFile?.delete();
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

/// Verifies a downloaded APK before install: same applicationId, higher
/// versionCode than installed, and identical signing certificate.
/// Never throws — failures return `ok: false` with a user-readable reason.
Future<InstallReadiness> checkInstallReadiness(File apk) async {
  try {
    if (!await apk.exists()) {
      return const InstallReadiness(
          ok: false, reason: 'Downloaded file is missing.');
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
  } catch (e) {
    debugPrint('install readiness notice: $e');
    return const InstallReadiness(
        ok: false, reason: 'Verification failed. Try again.');
  }
}

/// Remembers [tag] as skipped so the startup dialog stops asking for it.
void skipUpdateVersion(String tag) {
  try {
    LocalStore.instance.save(_skipKey, tag);
  } catch (e) {
    debugPrint('skip version notice: $e');
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
