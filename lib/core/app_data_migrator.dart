import 'package:shared_preferences/shared_preferences.dart';

import '../features/mine/application/advanced_theme_service.dart';
import '../features/reader/application/reader_preferences_service.dart';
import '../features/reader/application/reader_visual_overrides_service.dart';
import 'app_data_version.dart';
import 'logging/app_logger.dart';

class AppDataMigrationReport {
  const AppDataMigrationReport({
    required this.fromVersion,
    required this.toVersion,
    required this.executed,
    required this.cleanedKeys,
  });

  final int fromVersion;
  final int toVersion;
  final bool executed;
  final List<String> cleanedKeys;
}

class AppDataMigrator {
  AppDataMigrator({
    SharedPreferences? preferences,
    AppDataVersionStore? versionStore,
    ReaderPreferencesService? readerPreferencesService,
    ReaderVisualOverridesService? readerVisualOverridesService,
    AdvancedThemeService? advancedThemeService,
    AppLogger? logger,
  }) : _versionStore =
           versionStore ?? AppDataVersionStore(preferences: preferences),
       _readerPreferencesService =
           readerPreferencesService ??
           ReaderPreferencesService(preferences: preferences),
       _readerVisualOverridesService =
           readerVisualOverridesService ??
           ReaderVisualOverridesService(preferences: preferences),
       _advancedThemeService =
           advancedThemeService ??
           AdvancedThemeService(preferences: preferences),
       _logger = logger ?? AppLogger.instance;

  final AppDataVersionStore _versionStore;
  final ReaderPreferencesService _readerPreferencesService;
  final ReaderVisualOverridesService _readerVisualOverridesService;
  final AdvancedThemeService _advancedThemeService;
  final AppLogger _logger;

  Future<AppDataMigrationReport> migrateIfNeeded() async {
    final fromVersion = await _versionStore.read();
    if (fromVersion >= currentAppDataVersion) {
      return AppDataMigrationReport(
        fromVersion: fromVersion,
        toVersion: fromVersion,
        executed: false,
        cleanedKeys: const <String>[],
      );
    }

    final cleanedKeys = <String>[];
    for (
      var version = fromVersion + 1;
      version <= currentAppDataVersion;
      version += 1
    ) {
      cleanedKeys.addAll(await _runMigrationStep(version));
    }
    await _versionStore.write(currentAppDataVersion);
    _logger.info(
      'App data migration complete',
      context: <String, Object?>{
        'fromVersion': fromVersion,
        'toVersion': currentAppDataVersion,
        'cleanedKeyCount': cleanedKeys.length,
        'cleanedKeys': cleanedKeys.isEmpty ? null : cleanedKeys.join(','),
      },
    );
    return AppDataMigrationReport(
      fromVersion: fromVersion,
      toVersion: currentAppDataVersion,
      executed: true,
      cleanedKeys: List<String>.unmodifiable(cleanedKeys),
    );
  }

  Future<List<String>> _runMigrationStep(int version) async {
    return switch (version) {
      1 => _repairCriticalPreferencePayloads(),
      2 => _repairCriticalPreferencePayloads(),
      3 => _repairCriticalPreferencePayloads(),
      _ => const <String>[],
    };
  }

  Future<List<String>> _repairCriticalPreferencePayloads() async {
    final cleanedKeys = <String>[];
    cleanedKeys.addAll(
      await _readerPreferencesService.repairInvalidStoredData(),
    );
    cleanedKeys.addAll(
      await _readerVisualOverridesService.repairInvalidStoredData(),
    );
    cleanedKeys.addAll(await _advancedThemeService.repairInvalidStoredData());
    return List<String>.unmodifiable(cleanedKeys.toSet());
  }
}
