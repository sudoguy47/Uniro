import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Self-hosted OTA update system backed by GitHub Releases.
///
/// Flow: on startup [checkForUpdate] hits the GitHub API for the latest
/// release, compares the tag against the installed version, and if a newer
/// version exists the caller shows an update sheet. Downloading streams the
/// APK straight to disk (never into RAM) with progress callbacks, and
/// [installApk] hands the file to Android's package installer.
class UpdateService {
  UpdateService._();

  /// TODO: Replace with your actual GitHub repository (owner/repo).
  static const String _repo = 'YOUR_USERNAME/YOUR_REPO';

  /// Release asset name must end with this suffix to be detected.
  static const String _apkSuffix = '.apk';

  /// GitHub API requires a User-Agent header.
  static const Map<String, String> _headers = {
    'User-Agent': 'CampusTracker-App',
    'Accept': 'application/vnd.github+json',
  };

  static const Duration _timeout = Duration(seconds: 15);

  /// Information about an available update.
  static Future<UpdateInfo?> checkForUpdate() async {
    if (_repo == 'YOUR_USERNAME/YOUR_REPO') return null;
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. "1.0.0"

      final response = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
            headers: _headers,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = (json['tag_name'] as String? ?? '')
          .replaceFirst(RegExp(r'^[vV]'), '');

      if (latestVersion.isEmpty) return null;

      // Ignore malformed / dev tags (e.g. "1.2.0-beta.1" parses to 1.2.0).
      if (!_isNewerVersion(currentVersion, latestVersion)) return null;

      final assets = (json['assets'] as List? ?? const []);
      final downloadUrl = assets
          .whereType<Map<String, dynamic>>()
          .where((a) => (a['name'] as String? ?? '').endsWith(_apkSuffix))
          .map((a) => a['browser_download_url'] as String?)
          .firstWhere((url) => url != null && url.isNotEmpty, orElse: () => null);

      if (downloadUrl == null) return null;

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: json['body'] as String? ?? '',
        assetSizeBytes: _firstApkSize(assets),
      );
    } catch (_) {
      // Offline, rate-limited, or API shape changed — silently skip.
      return null;
    }
  }

  static int? _firstApkSize(List<dynamic> assets) {
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          (asset['name'] as String? ?? '').endsWith(_apkSuffix)) {
        final size = asset['size'];
        if (size is num) return size.toInt();
      }
    }
    return null;
  }

  /// Compares "major.minor.patch" strings. Returns true if [latest] > [current].
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = _versionParts(current);
    final latestParts = _versionParts(latest);
    if (currentParts == null || latestParts == null) return false;
    for (var i = 0; i < 3; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  /// Extracts the leading numeric triple from a version string.
  /// "1.2.3", "v1.2.3", "1.2.3+5", "1.2.3-beta" all yield [1, 2, 3].
  static List<int>? _versionParts(String version) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(version);
    if (match == null) return null;
    return [
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    ];
  }

  /// Streams the APK to external storage. [onProgress] receives 0.0 - 1.0.
  /// Returns the downloaded file path, or null on failure.
  static Future<String?> downloadApk(
    String url,
    void Function(double progress) onProgress,
  ) async {
    http.Client? client;
    try {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/campustracker-update.apk');

      // Delete a stale partial download from a previous attempt.
      if (await file.exists()) await file.delete();

      client = http.Client();
      final request = http.Request('GET', Uri.parse(url))..headers.addAll(_headers);
      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      var lastReportedPercent = -1;

      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          receivedBytes += chunk.length;
          sink.add(chunk);
          if (totalBytes > 0) {
            // Throttle UI updates: only emit when the integer percent changes,
            // so the progress bar never triggers hundreds of rebuilds.
            final percent = ((receivedBytes / totalBytes) * 100).floor();
            if (percent != lastReportedPercent) {
              lastReportedPercent = percent;
              onProgress(percent / 100);
            }
          }
        }
        await sink.flush();
        await sink.close();
      } catch (_) {
        await sink.close().catchError((_) {});
        if (await file.exists()) await file.delete();
        rethrow;
      }

      onProgress(1.0);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client?.close();
    }
  }

  /// Requests the install permission (Android 8+) and launches the system
  /// installer for the downloaded APK. Returns true if the installer opened.
  static Future<bool> installApk(String apkPath) async {
    try {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        status = await Permission.requestInstallPackages.request();
      }
      if (!status.isGranted) return false;

      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}

/// Immutable snapshot of an available release.
class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.assetSizeBytes,
  });

  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final int? assetSizeBytes;

  String get formattedSize {
    final bytes = assetSizeBytes;
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
