import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniro1/domain/haptics.dart';
import 'package:uniro1/services/device_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HapticsCapabilities.debugReset();
  });

  tearDown(() {
    HapticsCapabilities.debugReset();
  });

  group('BoundaryHaptics.shouldThock', () {
    test('fires when armed and past the floor', () {
      expect(
        BoundaryHaptics.shouldThock(
            armed: true, nowMs: 1000, lastMs: 0),
        isTrue,
      );
    });

    test('stays silent inside the 500ms floor', () {
      expect(
        BoundaryHaptics.shouldThock(
            armed: true, nowMs: 1200, lastMs: 1000),
        isFalse,
      );
    });

    test('stays silent when disarmed regardless of time', () {
      expect(
        BoundaryHaptics.shouldThock(
            armed: false, nowMs: 99999, lastMs: 0),
        isFalse,
      );
    });

    test('custom floor is honored', () {
      expect(
        BoundaryHaptics.shouldThock(
            armed: true, nowMs: 1100, lastMs: 1000, floorMs: 2000),
        isFalse,
      );
      expect(
        BoundaryHaptics.shouldThock(
            armed: true, nowMs: 3100, lastMs: 1000, floorMs: 2000),
        isTrue,
      );
    });
  });

  group('HapticsCapabilities', () {
    test('defaults to available (preserves behavior when unknown)', () {
      expect(HapticsCapabilities.hasVibrator, isTrue);
      expect(HapticsCapabilities.touchEnabled, isTrue);
      expect(HapticsCapabilities.available, isTrue);
    });

    test('missing vibrator disables availability', () {
      HapticsCapabilities.debugSet(hasVibrator: false);
      expect(HapticsCapabilities.available, isFalse);
    });

    test('disabled system toggle disables availability', () {
      HapticsCapabilities.debugSet(touchEnabled: false);
      expect(HapticsCapabilities.available, isFalse);
    });
  });

  group('PremiumHaptics gating', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (MethodCall call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('tap/select/confirm/edge vibrate when available',
        (tester) async {
      HapticsCapabilities.debugSet(hasVibrator: true, touchEnabled: true);
      PremiumHaptics.tap();
      PremiumHaptics.select();
      PremiumHaptics.confirm();
      PremiumHaptics.edge();
      await tester.idle();
      expect(calls.length, 4);
      expect(
        calls.map((c) => c.method).toSet(),
        {'HapticFeedback.vibrate'},
      );
      expect(
        calls.map((c) => c.arguments).toList(),
        [
          'HapticFeedbackType.lightImpact',
          'HapticFeedbackType.selectionClick',
          'HapticFeedbackType.mediumImpact',
          'HapticFeedbackType.mediumImpact',
        ],
      );
    });

    testWidgets('select falls back to a tap when the tick is unsupported',
        (tester) async {
      HapticsCapabilities.debugSet(
          hasVibrator: true,
          touchEnabled: true,
          selectionTickSupported: false);
      PremiumHaptics.select();
      await tester.idle();
      expect(calls.length, 1);
      expect(calls.single.method, 'HapticFeedback.vibrate');
      expect(calls.single.arguments, 'HapticFeedbackType.lightImpact');
    });

    testWidgets('tap/confirm/edge ignore the tick fallback', (tester) async {
      HapticsCapabilities.debugSet(
          hasVibrator: true,
          touchEnabled: true,
          selectionTickSupported: false);
      PremiumHaptics.tap();
      PremiumHaptics.confirm();
      PremiumHaptics.edge();
      await tester.idle();
      expect(
        calls.map((c) => c.arguments).toList(),
        [
          'HapticFeedbackType.lightImpact',
          'HapticFeedbackType.mediumImpact',
          'HapticFeedbackType.mediumImpact',
        ],
      );
    });

    testWidgets('all entry points stay silent when unavailable',
        (tester) async {
      HapticsCapabilities.debugSet(hasVibrator: false);
      PremiumHaptics.tap();
      PremiumHaptics.select();
      PremiumHaptics.confirm();
      PremiumHaptics.edge();
      HapticsCapabilities.debugSet(
          hasVibrator: true, touchEnabled: false);
      PremiumHaptics.tap();
      PremiumHaptics.select();
      PremiumHaptics.confirm();
      PremiumHaptics.edge();
      await tester.idle();
      expect(calls, isEmpty);
    });
  });

  group('DeviceChannel haptics queries', () {
    test('hasVibrator returns null without a platform plugin', () async {
      // No mock for dev.sudoguy.uniro/device: MissingPluginException
      // must degrade to null, never throw.
      expect(await DeviceChannel.hasVibrator(), isNull);
    });

    test('isTouchHapticsEnabled returns null without a plugin', () async {
      expect(await DeviceChannel.isTouchHapticsEnabled(), isNull);
    });

    test('supportsSelectionTick returns null without a plugin', () async {
      expect(await DeviceChannel.supportsSelectionTick(), isNull);
    });

    test('refresh keeps defaults when the plugin is missing', () async {
      await HapticsCapabilities.refresh();
      expect(HapticsCapabilities.available, isTrue);
    });
  });
}
