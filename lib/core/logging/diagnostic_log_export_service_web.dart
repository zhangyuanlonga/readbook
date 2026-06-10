import '../device/device_identity.dart';
import '../device/device_identity_service.dart';
import '../storage/storage_health_service.dart';
import 'app_logger.dart';
import 'source_log_store.dart';

class DiagnosticLogExportFile {
  const DiagnosticLogExportFile({required this.path});

  final String path;
}

class DiagnosticLogExportResult {
  const DiagnosticLogExportResult({
    required this.file,
    required this.text,
    required this.identity,
    required this.filteredEntryCount,
  });

  final DiagnosticLogExportFile? file;
  final String text;
  final DeviceIdentity identity;
  final int filteredEntryCount;
}

class DiagnosticLogExportService {
  DiagnosticLogExportService({
    SourceLogStore? store,
    DeviceIdentityService? deviceIdentityService,
    StorageHealthService? storageHealthService,
    AppLogger? logger,
  }) : _store = store ?? SourceLogStore.instance,
       _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService(),
       _storageHealthService = storageHealthService ?? StorageHealthService(),
       _logger = logger ?? AppLogger.instance;

  final SourceLogStore _store;
  final DeviceIdentityService _deviceIdentityService;
  final StorageHealthService _storageHealthService;
  final AppLogger _logger;

  Future<DiagnosticLogExportResult?> export({bool includeInfo = false}) async {
    try {
      final filteredEntryCount =
          _store.entries
              .where((entry) => includeInfo || entry.level != AppLogLevel.info)
              .length;
      final logs = _store.exportText(includeInfo: includeInfo).trim();
      if (logs.isEmpty) {
        return null;
      }

      final identity = await _deviceIdentityService.loadIdentity();
      final health = await _storageHealthService.buildReport();
      final text = _buildContent(
        logs: logs,
        identity: identity,
        health: health,
        includeInfo: includeInfo,
        filteredEntryCount: filteredEntryCount,
      );

      return DiagnosticLogExportResult(
        file: null,
        text: text,
        identity: identity,
        filteredEntryCount: filteredEntryCount,
      );
    } catch (error, stackTrace) {
      _logger.warn(
        'Diagnostic log export failed',
        context: <String, Object?>{
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
      rethrow;
    }
  }
}

String _buildContent({
  required String logs,
  required DeviceIdentity identity,
  required StorageHealthReport health,
  required bool includeInfo,
  required int filteredEntryCount,
}) {
  final generatedAt = DateTime.now().toIso8601String();
  return (StringBuffer()
        ..writeln('# 诊断日志')
        ..writeln()
        ..writeln('generated_at: $generatedAt')
        ..writeln('install_id: ${identity.installId}')
        ..writeln('platform: ${identity.platform}')
        ..writeln('device_brand: ${identity.deviceBrand}')
        ..writeln('device_model: ${identity.deviceModel}')
        ..writeln('os_version: ${identity.osVersion}')
        ..writeln('app_version: ${identity.appVersion}')
        ..writeln('include_info_logs: $includeInfo')
        ..writeln('log_count: $filteredEntryCount')
        ..writeln('storage_health_level: ${health.level.name}')
        ..writeln('storage_health_score: ${health.score}')
        ..writeln(
          'storage_shared_preferences_entries: ${health.sharedPreferencesEntryCount}',
        )
        ..writeln('storage_database_bytes: ${health.databaseBytes}')
        ..writeln('storage_cache_bytes: ${health.cacheBytes}')
        ..writeln(
          'storage_orphan_candidate_count: ${health.orphanCandidateCount}',
        )
        ..writeln(
          'storage_health_warnings: ${health.warnings.isEmpty ? "-" : health.warnings.join(" | ")}',
        )
        ..writeln()
        ..writeln('--- logs ---')
        ..writeln(logs))
      .toString()
      .trimRight();
}
