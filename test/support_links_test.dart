import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/services/support_links.dart';

/// Support links are configured in [support_links.dart]. The launcher
/// must fail closed and never throw, and the dialog hides any entry
/// left unconfigured.
void main() {
  // Needed: openExternalLink reaches the url_launcher method channel,
  // which requires an initialized binding even to fail gracefully.
  TestWidgetsFlutterBinding.ensureInitialized();
  test('support links are configured', () {
    expect(hasTelegramSupport, isTrue);
    expect(hasGitHubProfile, isTrue);
    expect(kTelegramSupportUrl, 'https://t.me/Hold_on47');
    expect(kGitHubProfileUrl, 'https://github.com/sudoguy47');
  });

  test('open helpers never throw (false without a launcher plugin)',
      () async {
    expect(await openTelegramSupport(), isFalse);
    expect(await openGitHubProfile(), isFalse);
  });

  test('empty and non-http(s) input fails closed', () async {
    expect(await openExternalLink(''), isFalse);
    expect(await openExternalLink('   '), isFalse);
    expect(await openExternalLink('not a url'), isFalse);
    expect(await openExternalLink('tg://resolve?domain=x'), isFalse);
    expect(await openExternalLink('javascript:alert(1)'), isFalse);
  });

  test('valid https URL fails gracefully without a launcher plugin',
      () async {
    // No platform launcher in unit tests: must return false, not throw.
    expect(await openExternalLink('https://example.com/support'), isFalse);
  });
}
