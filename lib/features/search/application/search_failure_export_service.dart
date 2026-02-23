import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/source_definition.dart';
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

  Future<SearchFailureExportResult> exportFailedSources({
    required SearchExecutionReport report,
    required Iterable<SourceDefinition> sources,
    required SearchContentMode contentMode,
  }) async {
    if (report.failures.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: '没有失败书源可导出。',
      );
    }

    final sourceById = <String, SourceDefinition>{
      for (final source in sources) source.id: source,
    };

    final now = _now();
    final fileName = 'search_failed_sources_${_formatTimestamp(now)}.json';

    final items = report.failures
        .map((failure) {
          final source = sourceById[failure.sourceId];
          final normalizedSource = source?.toJson();
          final originalSource = source?.originalSource;

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
            'sourceRaw': originalSource,
            'sourcePayload': originalSource ?? normalizedSource,
            'sourceFound': source != null,
            'sourceRawExact': originalSource != null,
          };
        })
        .toList(growable: false);

    final payload = <String, dynamic>{
      'schema': 'flutter_appread.search_failures.v2',
      'exportedAt': now.toIso8601String(),
      'keyword': report.keyword,
      'contentMode': contentMode.name,
      'summary': {
        'sourceCount': report.sourceCount,
        'successSourceCount': report.successSourceCount,
        'failedSourceCount': report.failedSourceCount,
        'bookCount': report.books.length,
      },
      'note':
          'source 为当前应用保存的标准化书源，sourceRaw 为原始导入书源，sourcePayload 优先返回原始书源用于回放。',
      'failures': items,
    };

    final content = const JsonEncoder.withIndent('  ').convert(payload);
    final filePath = await _writeExportFile(
      fileName: fileName,
      content: content,
    );

    final missingSourceCount =
        items.where((item) => item['sourceFound'] == false).length;

    return SearchFailureExportResult(
      filePath: filePath,
      failureCount: report.failures.length,
      missingSourceCount: missingSourceCount,
    );
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
      return Directory(
        _joinPath(downloadDirectory.path, 'flutter_appread_exports'),
      );
    }
    return _defaultFallbackDirectoryResolver();
  }

  static Future<Directory> _defaultFallbackDirectoryResolver() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return Directory(
      _joinPath(documentsDirectory.path, 'flutter_appread_exports'),
    );
  }

  bool _isSamePath(String left, String right) {
    final normalizedLeft = left.replaceAll('\\', '/');
    final normalizedRight = right.replaceAll('\\', '/');
    return normalizedLeft == normalizedRight;
  }

  static String _formatTimestamp(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month$day-$hour$minute$second';
  }

  static String _joinPath(String left, String right) {
    final separator = Platform.pathSeparator;
    if (left.endsWith(separator)) {
      return '$left$right';
    }
    return '$left$separator$right';
  }
}
