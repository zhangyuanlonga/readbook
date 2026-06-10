import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/app_data_migrator.dart';
import 'package:shuxiang_reading_next/core/app_data_version.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'migrates app data version and removes invalid critical payloads',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'reader.settings.customBackgroundImages': '{broken',
        'reader.settings.recentBodyTextColors': '[1,2',
        'reader.visualOverrides': '{broken',
        'app.advancedThemes.activeAppearanceSnapshot': '{broken',
        'app.data_version': 0,
      });
      final prefs = await SharedPreferences.getInstance();

      final report =
          await AppDataMigrator(preferences: prefs).migrateIfNeeded();

      expect(report.executed, isTrue);
      expect(report.toVersion, currentAppDataVersion);
      expect(prefs.getString('reader.settings.customBackgroundImages'), isNull);
      expect(prefs.getString('reader.settings.recentBodyTextColors'), isNull);
      expect(prefs.getString('reader.visualOverrides'), isNull);
      expect(
        prefs.getString('app.advancedThemes.activeAppearanceSnapshot'),
        isNull,
      );
      expect(prefs.getInt(appDataVersionPreferenceKey), currentAppDataVersion);
    },
  );
}
