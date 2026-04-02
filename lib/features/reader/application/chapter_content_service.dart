import 'dart:async';
import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reader_document.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../source/application/source_runtime_facade.dart';
import 'content_text_cleaner.dart';

class ChapterContentResult {
  factory ChapterContentResult({
    required String content,
    required bool fromCache,
    List<String> imageUrls = const [],
    Map<String, String> imageHeaders = const {},
    String? displayChapterTitle,
    ReaderDocument? document,
  }) {
    final resolvedDocument =
        document ??
        ReaderDocument.fromContent(content: content, imageUrls: imageUrls);
    return ChapterContentResult._(
      content:
          resolvedDocument.isPureImageDocument
              ? ''
              : resolvedDocument.compatibilityContent,
      fromCache: fromCache,
      imageUrls:
          resolvedDocument.isPureImageDocument
              ? resolvedDocument.imageUrls
              : const <String>[],
      imageHeaders: Map<String, String>.unmodifiable(imageHeaders),
      displayChapterTitle: displayChapterTitle,
      document: resolvedDocument,
    );
  }

  const ChapterContentResult._({
    required this.content,
    required this.fromCache,
    required this.imageUrls,
    required this.imageHeaders,
    required this.displayChapterTitle,
    required this.document,
  });

  final String content;
  final bool fromCache;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
  final String? displayChapterTitle;
  final ReaderDocument document;

  bool get isImageContent => document.isPureImageDocument;
}

class ChapterContentService {
  ChapterContentService({
    AppDatabase? database,
    Object? sourceRepository,
    SourceRuntimeFacade? sourceRuntimeFacade,
    Object? httpClient,
    Object? webViewExecutor,
    Object? interactiveVerificationExecutor,
    Object? ruleEngine,
    ContentTextCleaner? cleaner,
    Object? replaceRegexExecutor,
    AppLogger? logger,
    Object? urlTemplateResolver,
    Object? responseProcessor,
  }) : _database = database ?? AppDatabase.instance,
       _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _cleaner = cleaner ?? const ContentTextCleaner(),
       _logger = logger ?? AppLogger.instance;

  final AppDatabase _database;
  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final ContentTextCleaner _cleaner;
  final AppLogger _logger;

  static final Map<String, String> _chapterCache = <String, String>{};
  static const String _imageCachePrefix = '__appread_image_payload__:';

  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    String? bookTitle,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedChapterUrl = chapterUrl.trim();

    if (normalizedSourceId.isEmpty || normalizedChapterUrl.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '加载正文缺少参数。',
      );
    }

    final cacheKey = '$normalizedSourceId|$normalizedChapterUrl';
    final normalizedBookId = bookId?.trim() ?? '';
    final cached = _chapterCache[cacheKey];
    if (cached != null) {
      final decoded = _decodeCachedPayload(cached);
      return ChapterContentResult(
        content: decoded.content,
        fromCache: true,
        imageUrls: decoded.imageUrls,
        imageHeaders: decoded.imageHeaders,
      );
    }

    try {
      final persisted = await _database.getChapterCache(cacheKey);
      final persistedContent = persisted?.content.trim() ?? '';
      if (persistedContent.isNotEmpty) {
        _chapterCache[cacheKey] = persistedContent;
        final decoded = _decodeCachedPayload(persistedContent);
        return ChapterContentResult(
          content: decoded.content,
          fromCache: true,
          imageUrls: decoded.imageUrls,
          imageHeaders: decoded.imageHeaders,
        );
      }
    } catch (error) {
      _logger.warn(
        'Chapter cache lookup failed',
        context: {
          'sourceId': normalizedSourceId,
          'chapterUrl': normalizedChapterUrl,
          'error': error.toString(),
        },
      );
    }

    return _loadFromScriptRuntime(
      sourceId: normalizedSourceId,
      chapterUrl: normalizedChapterUrl,
      bookId: normalizedBookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      cacheKey: cacheKey,
    );
  }

  Future<ChapterContentResult> _loadFromScriptRuntime({
    required String sourceId,
    required String chapterUrl,
    required String bookId,
    required int? chapterIndex,
    required String? chapterTitle,
    required String cacheKey,
  }) async {
    final facade = _sourceRuntimeFacade;
    final registered =
        facade == null
            ? null
            : await facade.ensureRegisteredScriptSourceById(sourceId);
    if (facade == null || registered == null) {
      throw UnknownSourceException(
        briefMessage: '未找到书源：$sourceId',
        sourceId: sourceId,
        stage: ErrorStage.content,
      );
    }

    final runtimeBook = runtime_models.Book(
      title: '',
      author: '',
      detailUrl: '',
      sourceId: sourceId,
    );
    final runtimeChapter = runtime_models.Chapter(
      title:
          chapterTitle?.trim().isNotEmpty == true
              ? chapterTitle!.trim()
              : '未命名章节',
      url: chapterUrl,
      index: chapterIndex ?? 0,
      sourceId: sourceId,
    );

    final content = await facade.content(
      sourceId: sourceId,
      book: runtimeBook,
      chapter: runtimeChapter,
    );

    final normalizedImages = content.images
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (normalizedImages.isNotEmpty) {
      final payload = _encodeImageCachePayload(
        normalizedImages,
        imageHeaders: const <String, String>{},
      );
      _chapterCache[cacheKey] = payload;
      await _persistChapterCache(
        cacheKey: cacheKey,
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        chapterUrl: chapterUrl,
        content: payload,
      );
      return ChapterContentResult(
        content: '',
        fromCache: false,
        imageUrls: normalizedImages,
        displayChapterTitle: _normalizeOptionalText(content.title),
      );
    }

    final normalizedContent = _cleaner.clean(content.content.trim());
    if (normalizedContent.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '正文解析为空，请检查脚本源配置。',
        stage: ErrorStage.content,
        sourceId: sourceId,
      );
    }

    _chapterCache[cacheKey] = normalizedContent;
    await _persistChapterCache(
      cacheKey: cacheKey,
      bookId: bookId,
      sourceId: sourceId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      chapterUrl: chapterUrl,
      content: normalizedContent,
    );

    return ChapterContentResult(
      content: normalizedContent,
      fromCache: false,
      displayChapterTitle: _normalizeOptionalText(content.title),
    );
  }

  Future<void> _persistChapterCache({
    required String cacheKey,
    required String bookId,
    required String sourceId,
    required int? chapterIndex,
    required String? chapterTitle,
    required String chapterUrl,
    required String content,
  }) async {
    if (bookId.isEmpty || chapterIndex == null) {
      return;
    }
    try {
      await _database.upsertChapterCache(
        cacheKey: cacheKey,
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        chapterUrl: chapterUrl,
        content: content,
      );
    } catch (error) {
      _logger.warn(
        'Chapter cache persist failed',
        context: {
          'sourceId': sourceId,
          'chapterUrl': chapterUrl,
          'bookId': bookId,
          'error': error.toString(),
        },
      );
    }
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _encodeImageCachePayload(
    List<String> imageUrls, {
    Map<String, String> imageHeaders = const {},
  }) {
    final payload = <String, dynamic>{
      'imageUrls': imageUrls,
      'imageHeaders': imageHeaders,
    };
    return '$_imageCachePrefix${jsonEncode(payload)}';
  }

  _DecodedChapterCache _decodeCachedPayload(String payload) {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(_imageCachePrefix)) {
      return _DecodedChapterCache(content: trimmed);
    }

    final raw = trimmed.substring(_imageCachePrefix.length);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final urls = decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        return _DecodedChapterCache(content: '', imageUrls: urls);
      }

      if (decoded is Map) {
        final urls =
            (decoded['imageUrls'] as List?)
                ?.map((item) => item?.toString().trim() ?? '')
                .where((item) => item.isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
        final headers =
            (decoded['imageHeaders'] as Map?)
                ?.map(
                  (key, value) =>
                      MapEntry(key.toString(), value?.toString().trim() ?? ''),
                )
                .map((key, value) => MapEntry(key.trim(), value.trim()))
                .entries
                .where(
                  (entry) => entry.key.isNotEmpty && entry.value.isNotEmpty,
                )
                .fold<Map<String, String>>(
                  <String, String>{},
                  (result, entry) => result..[entry.key] = entry.value,
                ) ??
            const <String, String>{};

        return _DecodedChapterCache(
          content: '',
          imageUrls: urls,
          imageHeaders: headers,
        );
      }
    } on FormatException {
      return _DecodedChapterCache(content: trimmed);
    }

    return _DecodedChapterCache(content: trimmed);
  }
}

class _DecodedChapterCache {
  const _DecodedChapterCache({
    required this.content,
    this.imageUrls = const <String>[],
    this.imageHeaders = const <String, String>{},
  });

  final String content;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
}
