import 'package:flutter_appread/features/reader/application/reader_system_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReaderSystemSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads false by default and persists toggle value', () async {
      final service = ReaderSystemSettingsService();

      final defaultValue = await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(defaultValue, isFalse);

      await service.saveAutoSwitchSourceOnFailureEnabled(true);
      final enabledValue = await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(enabledValue, isTrue);

      await service.saveAutoSwitchSourceOnFailureEnabled(false);
      final disabledValue =
          await service.loadAutoSwitchSourceOnFailureEnabled();
      expect(disabledValue, isFalse);
    });
  });
}
