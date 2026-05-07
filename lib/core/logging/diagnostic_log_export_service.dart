import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../device/device_identity.dart';
import '../device/device_identity_service.dart';
import 'source_log_store.dart';

class DiagnosticLogExportResult {
  const DiagnosticLogExportResult({
    required this.file,
    required this.text,
    required this.identity,
    required this.filteredEntryCount,
  });

  final File file;
  final String text;
  final DeviceIdentity identity;
  final int filteredEntryCount;
}

class DiagnosticLogExportService {
  DiagnosticLogExportService({
    SourceLogStore? store,
    DeviceIdentityService? deviceIdentityService,
  }) : _store = store ?? SourceLogStore.instance,
       _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService();

  final SourceLogStore _store;
  final DeviceIdentityService _deviceIdentityService;

  Future<DiagnosticLogExportResult?> export({bool includeInfo = false}) async {
    final filteredEntryCount =
        _store.entries
            .where((entry) => includeInfo || entry.level != AppLogLevel.info)
            .length;
    final logs = _store.exportText(includeInfo: includeInfo).trim();
    if (logs.isEmpty) {
      return null;
    }

    final identity = await _deviceIdentityService.loadIdentity();
    final generatedAt = DateTime.now().toIso8601String();
    final content =
        StringBuffer()
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
          ..writeln()
          ..writeln('--- logs ---')
          ..writeln(logs);

    final tempDirectory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}diagnostics',
    );
    await exportDirectory.create(recursive: true);
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}${_buildFileName()}',
    );
    final text = content.toString().trimRight();
    await file.writeAsString(text, flush: true);

    return DiagnosticLogExportResult(
      file: file,
      text: text,
      identity: identity,
      filteredEntryCount: filteredEntryCount,
    );
  }

  String _buildFileName() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return 'shuxiang_diagnostic_${now.year}${twoDigits(now.month)}${twoDigits(now.day)}_${twoDigits(now.hour)}${twoDigits(now.minute)}${twoDigits(now.second)}.txt';
  }
}
