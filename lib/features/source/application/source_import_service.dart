import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:charset/charset.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/result/result.dart';
import '../../../data/adapters/legado_source_adapter.dart';
import '../../../data/models/legado_source_raw.dart';
import '../../../domain/entities/source_definition.dart';
import 'source_validator.dart';

class SourceImportIssue {
  const SourceImportIssue({
    required this.message,
    this.index,
    this.line,
    this.sourceLabel,
  });

  final int? index;
  final int? line;
  final String message;
  final String? sourceLabel;

  String toDisplayText() {
    final parts = <String>[];
    if (sourceLabel != null && sourceLabel!.trim().isNotEmpty) {
      parts.add('[$sourceLabel]');
    }
    if (index != null) {
      parts.add('第 $index 条');
    }
    if (line != null) {
      parts.add('行 $line');
    }
    parts.add(message);
    return parts.join(' | ');
  }

  SourceImportIssue withSourceLabel(String label) {
    return SourceImportIssue(
      message: message,
      index: index,
      line: line,
      sourceLabel: label,
    );
  }
}

class SourceImportPreviewReport {
  const SourceImportPreviewReport({
    required this.validSources,
    required this.issues,
    required this.totalCount,
  });

  final List<SourceDefinition> validSources;
  final List<SourceImportIssue> issues;
  final int totalCount;

  int get validCount => validSources.length;
  int get invalidCount => issues.length;
  bool get hasIssues => issues.isNotEmpty;
}

class SourceImportService {
  SourceImportService({
    LegadoSourceAdapter? adapter,
    AppLogger? logger,
    SourceValidator? validator,
  }) : _adapter = adapter ?? const LegadoSourceAdapter(),
       _logger = logger ?? AppLogger.instance,
       _validator = validator ?? const SourceValidator();

  final LegadoSourceAdapter _adapter;
  final AppLogger _logger;
  final SourceValidator _validator;

  Result<SourceImportPreviewReport> previewFromText(String jsonText) {
    final input = jsonText.trim();
    if (input.isEmpty) {
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: '导入内容为空，请粘贴合法 JSON。',
        ),
      );
    }

    try {
      final decoded = jsonDecode(input);
      final entries = _parseEntries(decoded);
      final lineByIndex =
          decoded is List ? _estimateItemStartLines(input) : const <int, int>{};

      final validSources = <SourceDefinition>[];
      final issues = <SourceImportIssue>[];

      for (final entry in entries) {
        final rawItem = entry.item;
        if (rawItem is! Map) {
          issues.add(
            SourceImportIssue(
              index: entry.index,
              line: lineByIndex[entry.zeroBasedIndex],
              message: '条目不是 JSON 对象。',
            ),
          );
          continue;
        }

        try {
          final raw = LegadoSourceRaw.fromJson(
            Map<String, dynamic>.from(rawItem),
          );
          final source = _adapter.adapt(raw);
          _validator.validate(source, index: entry.index);
          validSources.add(source);
        } on AppException catch (error) {
          issues.add(
            SourceImportIssue(
              index: entry.index,
              line: lineByIndex[entry.zeroBasedIndex],
              message: error.briefMessage,
            ),
          );
        } catch (error) {
          issues.add(
            SourceImportIssue(
              index: entry.index,
              line: lineByIndex[entry.zeroBasedIndex],
              message: '条目解析失败：$error',
            ),
          );
        }
      }

      return Success(
        SourceImportPreviewReport(
          validSources: List.unmodifiable(validSources),
          issues: List.unmodifiable(issues),
          totalCount: entries.length,
        ),
      );
    } on AppException catch (error) {
      _logger.warn(
        'Source import preview failed',
        context: {
          'stage': error.stage.name,
          'code': error.code.name,
          'message': error.briefMessage,
        },
      );
      return Failure(error);
    } on FormatException catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        briefMessage: 'JSON 格式无效：${error.message}',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.error('Source import preview parse failed', exception: exception);
      return Failure(exception);
    } catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.source,
        briefMessage: '书源预校验失败，请检查 JSON 内容。',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.error('Source import preview failed', exception: exception);
      return Failure(exception);
    }
  }

  Future<Result<SourceImportPreviewReport>> previewFromTextInBackground(
    String jsonText,
  ) async {
    final input = jsonText.trim();
    if (input.isEmpty) {
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: '导入内容为空，请粘贴合法 JSON。',
        ),
      );
    }

    try {
      final payload = await Isolate.run(
        () => _buildPreviewPayloadInIsolate(input),
      );
      return _decodePreviewPayload(payload);
    } catch (error, stackTrace) {
      _logger.warn(
        'Source import background preview fallback',
        context: {'error': error.toString()},
      );

      final fallback = previewFromText(input);
      if (fallback case Success<SourceImportPreviewReport>(
        data: final report,
      )) {
        return Success(report);
      }

      final exception =
          (fallback as Failure<SourceImportPreviewReport>).exception;
      if (exception.stackTrace == null) {
        return Failure(
          AppException(
            code: exception.code,
            stage: exception.stage,
            sourceId: exception.sourceId,
            requestUrl: exception.requestUrl,
            briefMessage: exception.briefMessage,
            cause: error,
            stackTrace: stackTrace,
          ),
        );
      }
      return Failure(exception);
    }
  }

  Result<SourceImportPreviewReport> _decodePreviewPayload(
    Map<String, Object?> payload,
  ) {
    final isSuccess = payload['ok'] == true;
    if (!isSuccess) {
      final errorPayload = payload['error'];
      if (errorPayload is Map) {
        final normalized = errorPayload.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final codeName = normalized['code']?.toString();
        final stageName = normalized['stage']?.toString();
        final message =
            normalized['message']?.toString().trim() ?? '书源预校验失败，请检查 JSON 内容。';
        final requestUrl = normalized['requestUrl']?.toString();

        return Failure(
          AppException(
            code: ErrorCode.values.firstWhere(
              (value) => value.name == codeName,
              orElse: () => ErrorCode.unknown,
            ),
            stage: ErrorStage.values.firstWhere(
              (value) => value.name == stageName,
              orElse: () => ErrorStage.source,
            ),
            requestUrl: requestUrl,
            briefMessage: message,
          ),
        );
      }

      return Failure(
        AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.source,
          briefMessage: '书源预校验失败，请检查 JSON 内容。',
        ),
      );
    }

    try {
      final totalCount = (payload['totalCount'] as num?)?.toInt() ?? 0;

      final validSourcesPayload = payload['validSources'];
      final validSources = <SourceDefinition>[];
      if (validSourcesPayload is List) {
        for (final item in validSourcesPayload) {
          if (item is Map) {
            final normalized = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            validSources.add(SourceDefinition.fromJson(normalized));
          }
        }
      }

      final issuesPayload = payload['issues'];
      final issues = <SourceImportIssue>[];
      if (issuesPayload is List) {
        for (final item in issuesPayload) {
          if (item is Map) {
            final normalized = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            final index = (normalized['index'] as num?)?.toInt();
            final line = (normalized['line'] as num?)?.toInt();
            final message = normalized['message']?.toString().trim() ?? '';
            final sourceLabel = normalized['sourceLabel']?.toString().trim();
            issues.add(
              SourceImportIssue(
                index: index,
                line: line,
                message: message.isEmpty ? '未知导入错误。' : message,
                sourceLabel:
                    sourceLabel == null || sourceLabel.isEmpty
                        ? null
                        : sourceLabel,
              ),
            );
          }
        }
      }

      return Success(
        SourceImportPreviewReport(
          validSources: List.unmodifiable(validSources),
          issues: List.unmodifiable(issues),
          totalCount: totalCount,
        ),
      );
    } catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.source,
        briefMessage: '书源预校验结果解析失败，请重试。',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.error(
        'Decode source preview payload failed',
        exception: exception,
      );
      return Failure(exception);
    }
  }

  String decodeSourceBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      final gbkEncoding = Charset.getByName('gbk');
      if (gbkEncoding != null) {
        try {
          final gbkDecoded = gbkEncoding.decode(bytes);
          if (gbkDecoded.trim().isNotEmpty) {
            return gbkDecoded;
          }
        } on FormatException {
          // ignore and fallback to malformed utf8 decode
        }
      }

      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  Result<List<SourceDefinition>> importFromText(String jsonText) {
    final preview = previewFromText(jsonText);
    if (preview case Failure<SourceImportPreviewReport>(
      exception: final error,
    )) {
      return Failure(error);
    }

    final report = (preview as Success<SourceImportPreviewReport>).data;
    if (report.hasIssues) {
      final firstIssue = report.issues.first;
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: firstIssue.toDisplayText(),
        ),
      );
    }

    if (report.validSources.isEmpty) {
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: '未发现可导入书源。',
        ),
      );
    }

    return Success(report.validSources);
  }

  Future<Result<SourceImportPreviewReport>> previewFromFilePath(
    String filePath,
  ) async {
    final contentResult = await _readFileContent(filePath);
    if (contentResult case Failure<String>(exception: final error)) {
      return Failure(error);
    }

    return previewFromText((contentResult as Success<String>).data);
  }

  Future<Result<List<SourceDefinition>>> importFromFilePath(
    String filePath,
  ) async {
    final contentResult = await _readFileContent(filePath);
    if (contentResult case Failure<String>(exception: final error)) {
      return Failure(error);
    }

    return importFromText((contentResult as Success<String>).data);
  }

  Future<Result<String>> _readFileContent(String filePath) async {
    final path = filePath.trim();
    if (path.isEmpty) {
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: '文件路径不能为空。',
        ),
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      return Failure(
        AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          requestUrl: path,
          briefMessage: '文件不存在：$path',
        ),
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final content = decodeSourceBytes(Uint8List.fromList(bytes));
      return Success(content);
    } on FileSystemException catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.source,
        requestUrl: path,
        briefMessage: '读取文件失败：$path',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.error('Read source file failed', exception: exception);
      return Failure(exception);
    }
  }

  List<_RawEntry> _parseEntries(Object? decoded) {
    if (decoded is Map) {
      return [_RawEntry(index: 1, zeroBasedIndex: 0, item: decoded)];
    }

    if (decoded is List) {
      if (decoded.isEmpty) {
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.source,
          briefMessage: '书源数组为空，请提供至少 1 条书源。',
        );
      }

      return decoded
          .asMap()
          .entries
          .map(
            (entry) => _RawEntry(
              index: entry.key + 1,
              zeroBasedIndex: entry.key,
              item: entry.value,
            ),
          )
          .toList(growable: false);
    }

    throw AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.source,
      briefMessage: '导入内容必须是 JSON 对象或数组。',
    );
  }

  Map<int, int> _estimateItemStartLines(String input) {
    final result = <int, int>{};
    var line = 1;
    var arrayDepth = 0;
    var objectDepth = 0;
    var inString = false;
    var escaped = false;
    var currentIndex = 0;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
      } else {
        if (char == '"') {
          inString = true;
        } else if (char == '[') {
          arrayDepth++;
        } else if (char == ']') {
          if (arrayDepth > 0) {
            arrayDepth--;
          }
        } else if (char == '{') {
          if (arrayDepth == 1 && objectDepth == 0) {
            result[currentIndex] = line;
          }
          objectDepth++;
        } else if (char == '}') {
          if (objectDepth > 0) {
            objectDepth--;
            if (arrayDepth == 1 && objectDepth == 0) {
              currentIndex++;
            }
          }
        }
      }

      if (char == '\n') {
        line++;
      }
    }

    return result;
  }
}

Map<String, Object?> _buildPreviewPayloadInIsolate(String jsonText) {
  final service = SourceImportService();
  final result = service.previewFromText(jsonText);

  if (result case Success<SourceImportPreviewReport>(data: final report)) {
    return {
      'ok': true,
      'totalCount': report.totalCount,
      'validSources': report.validSources
          .map((source) => source.toJson())
          .toList(growable: false),
      'issues': report.issues
          .map(_convertIssueToPayload)
          .toList(growable: false),
    };
  }

  final exception = (result as Failure<SourceImportPreviewReport>).exception;
  return {
    'ok': false,
    'error': {
      'code': exception.code.name,
      'stage': exception.stage.name,
      'message': exception.briefMessage,
      'requestUrl': exception.requestUrl,
    },
  };
}

Map<String, Object?> _convertIssueToPayload(SourceImportIssue issue) {
  return {
    'index': issue.index,
    'line': issue.line,
    'message': issue.message,
    'sourceLabel': issue.sourceLabel,
  };
}

class _RawEntry {
  const _RawEntry({
    required this.index,
    required this.zeroBasedIndex,
    required this.item,
  });

  final int index;
  final int zeroBasedIndex;
  final Object? item;
}
