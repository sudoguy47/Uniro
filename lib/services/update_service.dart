import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

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

/// Checks GitHub Releases for a newer build.
///
/// Returns an [AppUpdate] when the latest tag is newer than both the
/// installed version AND the skipped version, otherwise null.
/// Never throws — offline or any error yields null.
Future<AppUpdate?> checkForUpdate() async {
  try {
    final info = await PackageInfo.fromPlatform();
    // package_info_plus version is "1.0.0+1": compare the dotted part.
    final installed = info.version;

    final uri = Uri.https(
      'api.github.com',
      '/repos/$kGithubUser/$kGithubRepo/releases/latest',
    );
    final res = await http
        .get(uri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;

    final json = jsonDecode(res.body);
    if (json is! Map) return null;
    final tag = (json['tag_name'] as String?) ?? '';
    if (tag.isEmpty) return null;
    if (compareVersions(tag, installed) <= 0) return null;

    final skipped = LocalStore.instance.load(_skipKey) as String?;
    if (skipped == tag) return null;

    String apkUrl = '';
    final assets = json['assets'];
    if (assets is List) {
      for (final a in assets) {
        if (a is! Map) continue;
        final url = (a['browser_download_url'] as String?) ?? '';
        final name = (a['name'] as String?) ?? '';
        if (url.isNotEmpty &&
            (name.toLowerCase().endsWith('.apk') ||
                url.toLowerCase().endsWith('.apk'))) {
          apkUrl = url;
          break;
        }
      }
    }
    if (apkUrl.isEmpty) return null;

    return AppUpdate(
      tag: tag,
      version: prettyVersion(tag),
      notes: (json['body'] as String?) ?? '',
      apkUrl: apkUrl,
    );
  } catch (e) {
    debugPrint('update check notice: $e');
    return null;
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

/// Installed version string for "Check for updates" rows, e.g. "1.0.0".
Future<String> installedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return '';
  }
}
