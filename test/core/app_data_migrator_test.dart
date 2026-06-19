import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/app_data_migrator.dart';
import 'package:shuxiang_reading_next/core/app_data_version.dart';
import 'package:shuxiang_reading_next/core/preferences/preference_repair_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_preferences_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_visual_overrides_service.dart';

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
          await AppDataMigrator(
            preferences: prefs,
            repairServices: <PreferenceRepairService>[
              ReaderPreferencesService(preferences: prefs),
              ReaderVisualOverridesService(preferences: prefs),
              AdvancedThemeService(preferences: prefs),
            ],
          ).migrateIfNeeded();

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

  test('runs injected repair services in order', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.data_version': 0,
    });
    final prefs = await SharedPreferences.getInstance();
    final calls = <String>[];

    final report =
        await AppDataMigrator(
          preferences: prefs,
          repairServices: <PreferenceRepairService>[
            _FakePreferenceRepairService(
              calls: calls,
              key: 'first',
              cleanedKeys: const ['a', 'b'],
            ),
            _FakePreferenceRepairService(
              calls: calls,
              key: 'second',
              cleanedKeys: const ['b', 'c'],
            ),
          ],
        ).migrateIfNeeded();

    expect(report.executed, isTrue);
    expect(calls, <String>['first', 'second']);
    expect(report.cleanedKeys, <String>['a', 'b', 'c']);
  });

  test('migrates without repair services', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.data_version': 0,
    });
    final prefs = await SharedPreferences.getInstance();

    final report = await AppDataMigrator(preferences: prefs).migrateIfNeeded();

    expect(report.executed, isTrue);
    expect(report.cleanedKeys, isEmpty);
    expect(prefs.getInt(appDataVersionPreferenceKey), currentAppDataVersion);
  });

  test('continues when one repair service fails', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.data_version': 0,
    });
    final prefs = await SharedPreferences.getInstance();
    final calls = <String>[];

    final report =
        await AppDataMigrator(
          preferences: prefs,
          repairServices: <PreferenceRepairService>[
            _ThrowingPreferenceRepairService(calls: calls, key: 'broken'),
            _FakePreferenceRepairService(
              calls: calls,
              key: 'healthy',
              cleanedKeys: const ['fixed'],
            ),
          ],
        ).migrateIfNeeded();

    expect(report.executed, isTrue);
    expect(calls, <String>['broken', 'healthy']);
    expect(report.cleanedKeys, <String>['fixed']);
    expect(prefs.getInt(appDataVersionPreferenceKey), currentAppDataVersion);
  });
}

class _FakePreferenceRepairService implements PreferenceRepairService {
  _FakePreferenceRepairService({
    required this.calls,
    required this.key,
    required this.cleanedKeys,
  });

  final List<String> calls;
  final String key;
  final List<String> cleanedKeys;

  @override
  Future<List<String>> repairInvalidStoredData() async {
    calls.add(key);
    return cleanedKeys;
  }
}

class _ThrowingPreferenceRepairService implements PreferenceRepairService {
  _ThrowingPreferenceRepairService({required this.calls, required this.key});

  final List<String> calls;
  final String key;

  @override
  Future<List<String>> repairInvalidStoredData() async {
    calls.add(key);
    throw StateError('repair failed');
  }
}
