import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/device/device_identity.dart';
import 'package:shuxiang_reading_next/core/device/device_identity_service.dart';
import 'package:shuxiang_reading_next/core/logging/diagnostic_log_export_service.dart';
import 'package:shuxiang_reading_next/core/logging/source_log_store.dart';
import 'package:shuxiang_reading_next/core/storage/storage_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiagnosticLogExportService', () {
    late SourceLogStore store;
    late _FakeDeviceIdentityService identityService;
    late _FakeStorageHealthService healthService;
    late Directory tempDirectory;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      store = SourceLogStore.instance;
      store.clear();
      identityService = _FakeDeviceIdentityService();
      healthService = _FakeStorageHealthService();
      tempDirectory = await Directory.systemTemp.createTemp(
        'diagnostic_log_export_service_test_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDirectory);
    });

    tearDown(() async {
      store.clear();
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('returns null when there are no exportable logs', () async {
      SourceLogStore.instance.add(
        AppLogEntry(
          timestamp: DateTime(2026, 5, 12, 9),
          level: AppLogLevel.info,
          message: 'startup',
        ),
      );

      final result =
          await DiagnosticLogExportService(
            store: store,
            deviceIdentityService: identityService,
            storageHealthService: healthService,
          ).export();

      expect(result, isNull);
    });

    test('writes a diagnostic file and keeps the text copy fallback', () async {
      SourceLogStore.instance.add(
        AppLogEntry(
          timestamp: DateTime(2026, 5, 12, 10),
          level: AppLogLevel.error,
          message: 'reader failed',
          context: const <String, Object?>{'bookId': 'local-1'},
        ),
      );

      final result =
          await DiagnosticLogExportService(
            store: store,
            deviceIdentityService: identityService,
            storageHealthService: healthService,
          ).export();

      expect(result, isNotNull);
      expect(result!.text, contains('# 诊断日志'));
      expect(result.text, contains('install_id: install-test'));
      expect(result.text, contains('storage_health_level: notice'));
      expect(result.text, contains('storage_health_score: 82'));
      expect(result.text, contains('reader failed'));
      expect(result.file, isNotNull);
      final file = File(result.file!.path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), result.text);
    });
  });
}

class _FakeDeviceIdentityService extends DeviceIdentityService {
  @override
  Future<DeviceIdentity> loadIdentity() async {
    return const DeviceIdentity(
      installId: 'install-test',
      deviceUid: 'device-test',
      deviceFingerprint: 'fingerprint-test',
      platform: 'test',
      deviceBrand: 'brand-test',
      deviceModel: 'model-test',
      osVersion: 'os-test',
      appVersion: '1.0.0',
    );
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.directory);

  final Directory directory;

  @override
  Future<String?> getApplicationSupportPath() async {
    return directory.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return directory.path;
  }
}

class _FakeStorageHealthService extends StorageHealthService {
  @override
  Future<StorageHealthReport> buildReport() async {
    return const StorageHealthReport(
      level: StorageHealthLevel.notice,
      score: 82,
      sharedPreferencesEntryCount: 12,
      databaseBytes: 4096,
      cacheBytes: 2048,
      orphanCandidateCount: 3,
      warnings: <String>['示例告警'],
    );
  }
}
