import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Support links for the Profile > Help > "Need a hand?" dialog.
///
/// Paste your real links here. An empty (or blank) value means "not
/// configured": the dialog hides that entry instead of opening a
/// placeholder page. Never commit a private invite link you do not
/// want public — these strings ship inside the app.
const String kTelegramSupportUrl = 'https://t.me/Hold_on47';

/// Public GitHub profile shown as a small link at the bottom of the
/// support dialog. Empty means "not configured" (link hidden).
const String kGitHubProfileUrl = 'https://github.com/sudoguy47';

/// True when a Telegram support link is configured.
bool get hasTelegramSupport => kTelegramSupportUrl.trim().isNotEmpty;

/// True when a GitHub profile link is configured.
bool get hasGitHubProfile => kGitHubProfileUrl.trim().isNotEmpty;

/// Opens [url] in the external browser/app (same approach as the
/// in-app update dialog: [LaunchMode.externalApplication]).
/// Never throws: false on empty/unparseable URLs, non-http(s)
/// schemes, or launch failures.
Future<bool> openExternalLink(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;
  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('open link notice: $e');
    return false;
  }
}

/// Opens the configured Telegram support link. False when unconfigured
/// or when the launch fails. Never throws.
Future<bool> openTelegramSupport() => openExternalLink(kTelegramSupportUrl);

/// Opens the configured GitHub profile link. False when unconfigured
/// or when the launch fails. Never throws.
Future<bool> openGitHubProfile() => openExternalLink(kGitHubProfileUrl);
