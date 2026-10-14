import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/services/update_service.dart';

void main() {
  group('compareVersions', () {
    test('numeric comparison, not lexicographic', () {
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('v1.10.0', 'v1.9.0'), greaterThan(0));
      expect(compareVersions('1.0.0', 'v1.0.1'), lessThan(0));
      expect(compareVersions('v2.0', 'v1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0+5', '1.0.0+3'), 0);
      expect(compareVersions('v1.2', 'v1.2.0'), 0);
    });
  });

  group('prettyVersion', () {
    test('strips prefix and build', () {
      expect(prettyVersion('v1.2.0'), '1.2.0');
      expect(prettyVersion('V2.0.1+4'), '2.0.1');
      expect(prettyVersion('1.0.0+1'), '1.0.0');
    });
  });
}
