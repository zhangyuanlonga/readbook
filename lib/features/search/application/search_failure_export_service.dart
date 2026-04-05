import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../runtime/sources/source_registry.dart';
import 'search_service.dart';

typedef SearchExportDirectoryResolver = Future<Directory> Function();
typedef SearchExportFallbackDirectoryResolver = Future<Directory> Function();

class SearchFailureExportResult {
  const SearchFailureExportResult({
    required this.filePath,
    required this.failureCount,
    required this.missingSourceCount,
  });

  final String filePath;
  final int failureCount;
  final int missingSourceCount;
}

class SearchFailureExportService {
  SearchFailureExportService({
    SearchExportDirectoryResolver? exportDirectoryResolver,
    SearchExportFallbackDirectoryResolver? fallbackDirectoryResolver,
    DateTime Function()? now,
  }) : _exportDirectoryResolver =
           exportDirectoryResolver ?? _defaultExportDirectoryResolver,
       _fallbackDirectoryResolver =
           fallbackDirectoryResolver ?? _defaultFallbackDirectoryResolver,
       _now = now ?? DateTime.now;

  final SearchExportDirectoryResolver _exportDirectoryResolver;
  final SearchExportFallbackDirectoryResolver _fallbackDirectoryResolver;
  final DateTime Function() _now;

  String buildSuggestedFileName({DateTime? now}) {
    final value = now ?? _now();
    return 'search_failed_sources_${_formatTimestamp(value)}.json';
  }

  Future<SearchFailureExportResult> exportFailedSources({
    required SearchExecutionReport report,
    required Iterable<RegisteredSource> sources,
    required SearchContentMode contentMode,
    String? preferredFilePath,
  }) async {
    if (report.failures.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: '没有失败书源可导出。',
      );
    }

    final sourceById = <String, RegisteredSource>{
      for (final source in sources) source.runtime.id: source,
    };

    final now = _now();
    final fileName = buildSuggestedFileName(now: now);

    final items = report.failures
        .map((failure) {
          final source = sourceById[failure.sourceId];
          final normalizedSource =
              source == null
                  ? null
                  : <String, dynamic>{
                    'id': source.runtime.id,
                    'name': source.runtime.name,
                    'group': source.runtime.group,
                    'revision': source.runtime.revision,
                    'manifest': <String, dynamic>{
                      'name': source.definition.manifest.name,
                      'group': source.definition.manifest.group,
                      'author': source.definition.manifest.author,
                      'description': source.definition.manifest.description,
                      'homepage': source.definition.manifest.homepage,
                      'domains': source.definition.manifest.domains,
                      'enabled': source.definition.manifest.enabled,
                      'capabilities': source.definition.manifest.capabilities
                          .toList(growable: false),
                    },
                  };

          return <String, dynamic>{
            'sourceId': failure.sourceId,
            'sourceName': failure.sourceName,
            'error': {
              'code': failure.code.name,
              'stage': failure.stage.name,
              'message': failure.message,
              if (failure.debugMessage != null &&
                  failure.debugMessage!.trim().isNotEmpty)
                'debugMessage': failure.debugMessage,
              if (failure.requestUrl != null &&
                  failure.requestUrl!.trim().isNotEmpty)
                'requestUrl': failure.requestUrl,
            },
            'source': normalizedSource,
            'sourceFound': source != null,
          };
        })
        .toList(growable: false);

    final payload = <String, dynamic>{
      'schema': 'shuxiang_reading_next.search_failures.v3',
      'exportedAt': now.toIso8601String(),
      'keyword': report.keyword,
      'contentMode': contentMode.name,
      'summary': {
        'sourceCount': report.sourceCount,
        'successSourceCount': report.successSourceCount,
        'failedSourceCount': report.failedSourceCount,
        'bookCount': report.books.length,
      },
      'note': 'source 为当前运行时已注册书源快照。',
      'failures': items,
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    final normalizedPreferredPath = preferredFilePath?.trim();
    final filePath =
        normalizedPreferredPath != null && normalizedPreferredPath.isNotEmpty
            ? await _writeToSpecificPath(
              filePath: normalizedPreferredPath,
              fallbackFileName: fileName,
              content: content,
            )
            : await _writeExportFile(fileName: fileName, content: content);

    final missingSourceCount =
        items.where((item) => item['sourceFound'] == false).length;

    return SearchFailureExportResult(
      filePath: filePath,
      failureCount: report.failures.length,
      missingSourceCount: missingSourceCount,
    );
  }

  Future<String> _writeToSpecificPath({
    required String filePath,
    required String fallbackFileName,
    required String content,
  }) async {
    try {
      final normalized = _normalizeTargetFilePath(
        filePath,
        fallbackFileName: fallbackFileName,
      );
      final file = File(normalized);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(content, flush: true);
      return file.path;
    } catch (error) {
      throw AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.search,
        briefMessage: '导出到指定位置失败：$error',
        cause: error,
      );
    }
  }

  String _normalizeTargetFilePath(
    String filePath, {
    required String fallbackFileName,
  }) {
    final normalized = filePath.trim();
    if (normalized.isEmpty) {
      return fallbackFileName;
    }

    if (normalized.toLowerCase().endsWith('.json')) {
      return normalized;
    }
    return '$normalized.json';
  }

  Future<String> _writeExportFile({
    required String fileName,
    required String content,
  }) async {
    Directory? preferredDirectory;
    try {
      preferredDirectory = await _ensureDirectory(
        await _exportDirectoryResolver(),
      );
      return await _writeFile(
        directory: preferredDirectory,
        fileName: fileName,
        content: content,
      );
    } catch (preferredError) {
      final fallbackDirectory = await _ensureDirectory(
        await _fallbackDirectoryResolver(),
      );

      if (preferredDirectory != null &&
          _isSamePath(preferredDirectory.path, fallbackDirectory.path)) {
        throw AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.search,
          briefMessage: '导出文件写入失败：$preferredError',
          cause: preferredError,
        );
      }

      try {
        return await _writeFile(
          directory: fallbackDirectory,
          fileName: fileName,
          content: content,
        );
      } catch (fallbackError) {
        throw AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.search,
          briefMessage: '导出文件写入失败：$fallbackError',
          cause: fallbackError,
        );
      }
    }
  }

  Future<String> _writeFile({
    required Directory directory,
    required String fileName,
    required String content,
  }) async {
    final file = File(_joinPath(directory.path, fileName));
    await file.writeAsString(content, flush: true);
    return file.path;
  }

  Future<Directory> _ensureDirectory(Directory directory) async {
    if (await directory.exists()) {
      return directory;
    }
    return directory.create(recursive: true);
  }

  static Future<Directory> _defaultExportDirectoryResolver() async {
    final downloadDirectory = await getDownloadsDirectory();
    if (downloadDirectory != null) {
      return downloadDirectory;
    }
    throw AppException(
      code: ErrorCode.unknown,
      stage: ErrorStage.search,
      briefMessage: '当前平台未提供下载目录。',
    );
  }

  static Future<Directory> _defaultFallbackDirectoryResolver() async {
    final supportDirectory = await getApplicationSupportDirectory();
    return Directory(_joinPath(supportDirectory.path, 'exports'));
  }

  static String _joinPath(String left, String right) {
    if (left.endsWith(Platform.pathSeparator)) {
      return '$left$right';
    }
    return '$left${Platform.pathSeparator}$right';
  }

  static String _formatTimestamp(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}_${twoDigits(value.hour)}${twoDigits(value.minute)}${twoDigits(value.second)}';
  }

  bool _isSamePath(String left, String right) {
    return left.trim() == right.trim();
  }
}
