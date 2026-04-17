import 'package:shuxiang_reading_next/features/reader/application/reader_system_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReaderSystemSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('always keeps auto switch source on failure enabled', () async {
      final service = ReaderSystemSettingsService();

      final defaultValue = await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(defaultValue, isTrue);

      await service.saveAutoSwitchSourceOnFailureEnabled(true);
      final enabledValue = await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(enabledValue, isTrue);

      await service.saveAutoSwitchSourceOnFailureEnabled(false);
      final disabledValue =
          await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(disabledValue, isTrue);
    });

    test('watchReadRecordEnabled always emits true', () async {
      final service = ReaderSystemSettingsService();
      final values = <bool>[];
      final subscription = service.watchReadRecordEnabled().listen(values.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(values, <bool>[true]);

      await service.saveReadRecordEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(values, <bool>[true]);
      expect(await service.loadReadRecordEnabled(), isTrue);
    });

    test('allows multiple listeners on the same read record stream', () async {
      final service = ReaderSystemSettingsService();
      final stream = service.watchReadRecordEnabled();
      final firstValues = <bool>[];
      final secondValues = <bool>[];
      final firstSubscription = stream.listen(firstValues.add);
      final secondSubscription = stream.listen(secondValues.add);
      addTearDown(firstSubscription.cancel);
      addTearDown(secondSubscription.cancel);

      await Future<void>.delayed(Duration.zero);
      expect(firstValues, <bool>[true]);
      expect(secondValues, <bool>[true]);

      await service.saveReadRecordEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(firstValues, <bool>[true]);
      expect(secondValues, <bool>[true]);
    });

    test('persists local txt split setting', () async {
      final service = ReaderSystemSettingsService();

      expect(await service.loadLocalTxtSplitLongChapterEnabled(), isTrue);

      await service.saveLocalTxtSplitLongChapterEnabled(false);
      expect(await service.loadLocalTxtSplitLongChapterEnabled(), isFalse);

      await service.saveLocalTxtSplitLongChapterEnabled(true);
      expect(await service.loadLocalTxtSplitLongChapterEnabled(), isTrue);
    });
  });
}
