import 'dart:io';

import 'package:file_selector/file_selector.dart';

class SourceScriptImportSummary {
  const SourceScriptImportSummary({
    required this.successCount,
    required this.failureCount,
    this.lastError,
    this.truncatedByLimit = false,
  });

  final int successCount;
  final int failureCount;
  final String? lastError;
  final bool truncatedByLimit;

  bool get hasSuccess => successCount > 0;
}

class SourceScriptImportProgress {
  const SourceScriptImportProgress({
    required this.completedCount,
    required this.totalCount,
    required this.currentFileLabel,
  });

  final int completedCount;
  final int totalCount;
  final String currentFileLabel;
}

typedef SourceScriptImportProgressCallback =
    void Function(SourceScriptImportProgress progress);

class SourceScriptImportService {
  const SourceScriptImportService();

  Future<SourceScriptImportSummary> importLocalFiles({
    required List<XFile> files,
    required int remainingSlots,
    required Future<void> Function(String sourceCode) saver,
    required String Function(Object error) errorFormatter,
    SourceScriptImportProgressCallback? onProgress,
  }) async {
    var successCount = 0;
    var failureCount = 0;
    String? lastError;
    final importTargets =
        remainingSlots < 0
            ? files
            : files.take(remainingSlots).toList(growable: false);

    for (var index = 0; index < importTargets.length; index += 1) {
      final file = importTargets[index];
      onProgress?.call(
        SourceScriptImportProgress(
          completedCount: index,
          totalCount: importTargets.length,
          currentFileLabel: file.name.trim().isEmpty ? file.path : file.name,
        ),
      );
      try {
        final contents = await file.readAsString();
        await saver(contents);
        successCount += 1;
      } catch (error) {
        failureCount += 1;
        lastError = errorFormatter(error);
      }
    }

    if (importTargets.isNotEmpty) {
      onProgress?.call(
        SourceScriptImportProgress(
          completedCount: importTargets.length,
          totalCount: importTargets.length,
          currentFileLabel:
              importTargets.last.name.trim().isEmpty
                  ? importTargets.last.path
                  : importTargets.last.name,
        ),
      );
    }

    return SourceScriptImportSummary(
      successCount: successCount,
      failureCount: failureCount,
      lastError: lastError,
      truncatedByLimit:
          remainingSlots >= 0 && importTargets.length < files.length,
    );
  }

  Future<void> importNetworkSource({
    required String sourceCode,
    required Future<void> Function(String sourceCode) saver,
  }) {
    return saver(sourceCode.trim());
  }

  Future<void> importCachedExternalFile({
    required File file,
    required Future<void> Function(String sourceCode) saver,
  }) async {
    final contents = await file.readAsString();
    await saver(contents);
  }
}
