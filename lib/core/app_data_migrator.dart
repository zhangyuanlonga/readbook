import 'package:shared_preferences/shared_preferences.dart';

import 'app_data_version.dart';
import 'logging/app_logger.dart';
import 'preferences/preference_repair_service.dart';

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
    List<PreferenceRepairService> repairServices =
        const <PreferenceRepairService>[],
    AppLogger? logger,
  }) : _versionStore =
           versionStore ?? AppDataVersionStore(preferences: preferences),
       _repairServices = List<PreferenceRepairService>.unmodifiable(
         repairServices,
       ),
       _logger = logger ?? AppLogger.instance;

  final AppDataVersionStore _versionStore;
  final List<PreferenceRepairService> _repairServices;
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
    var shouldRepairCriticalPreferencePayloads = false;
    for (
      var version = fromVersion + 1;
      version <= currentAppDataVersion;
      version += 1
    ) {
      if (_isCriticalPreferenceRepairStep(version)) {
        shouldRepairCriticalPreferencePayloads = true;
      } else {
        cleanedKeys.addAll(await _runMigrationStep(version));
      }
    }
    if (shouldRepairCriticalPreferencePayloads) {
      cleanedKeys.addAll(await _repairCriticalPreferencePayloads());
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
      _ => const <String>[],
    };
  }

  bool _isCriticalPreferenceRepairStep(int version) {
    return version >= 1 && version <= currentAppDataVersion;
  }

  Future<List<String>> _repairCriticalPreferencePayloads() async {
    final cleanedKeys = <String>[];
    for (final service in _repairServices) {
      try {
        cleanedKeys.addAll(await service.repairInvalidStoredData());
      } catch (error, stackTrace) {
        _logger.warn(
          'Preference repair service failed',
          context: <String, Object?>{
            'serviceType': service.runtimeType.toString(),
            'error': error.toString(),
            'stackTrace': stackTrace.toString(),
          },
        );
      }
    }
    return List<String>.unmodifiable(cleanedKeys.toSet());
  }
}
