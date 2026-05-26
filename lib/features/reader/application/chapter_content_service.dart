import 'dart:async';
import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/reader_document.dart';
import '../../search/application/server_book_gateway_service.dart';
import '../../search/application/server_gateway_identity.dart';
import '../../source/application/source_health_service.dart';
import 'content_text_cleaner.dart';
import 'removed_script_source_guard.dart';

class ChapterContentResult {
  factory ChapterContentResult({
    required String content,
    required bool fromCache,
    List<String> imageUrls = const [],
    Map<String, String> imageHeaders = const {},
    String? contentType,
    String? sourceFilePath,
    int? totalPageCount,
    String? audioUrl,
    String? audioManifestUrl,
    Map<String, String> audioHeaders = const {},
    String? displayChapterTitle,
    String? executionContext,
    ReaderDocument? document,
  }) {
    final normalizedContentType =
        _normalizeOptionalTextStatic(contentType)?.toLowerCase();
    final normalizedImageUrls = List<String>.unmodifiable(
      imageUrls
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
    );
    final preferImageOnlyDocument =
        normalizedImageUrls.isNotEmpty &&
        _shouldPreferImageOnlyDocument(normalizedContentType);
    final resolvedDocument =
        document ??
        ReaderDocument.fromContent(
          content: preferImageOnlyDocument ? '' : content,
          imageUrls: normalizedImageUrls,
        );
    final effectiveDocument =
        preferImageOnlyDocument && !resolvedDocument.isPureImageDocument
            ? ReaderDocument.fromContent(
              content: '',
              imageUrls: normalizedImageUrls,
            )
            : resolvedDocument;
    final resolvedImageUrls =
        preferImageOnlyDocument || effectiveDocument.isPureImageDocument
            ? List<String>.unmodifiable(
              effectiveDocument.imageUrls.isNotEmpty
                  ? effectiveDocument.imageUrls
                  : normalizedImageUrls,
            )
            : const <String>[];
    return ChapterContentResult._(
      content:
          preferImageOnlyDocument || effectiveDocument.isPureImageDocument
              ? ''
              : effectiveDocument.compatibilityContent,
      fromCache: fromCache,
      imageUrls: resolvedImageUrls,
      imageHeaders: Map<String, String>.unmodifiable(imageHeaders),
      contentType: normalizedContentType,
      sourceFilePath: _normalizeOptionalTextStatic(sourceFilePath),
      totalPageCount: totalPageCount,
      audioUrl: _normalizeOptionalTextStatic(audioUrl),
      audioManifestUrl: _normalizeOptionalTextStatic(audioManifestUrl),
      audioHeaders: Map<String, String>.unmodifiable(audioHeaders),
      displayChapterTitle: displayChapterTitle,
      executionContext: _normalizeOptionalTextStatic(executionContext),
      document: effectiveDocument,
    );
  }

  const ChapterContentResult._({
    required this.content,
    required this.fromCache,
    required this.imageUrls,
    required this.imageHeaders,
    required this.contentType,
    required this.sourceFilePath,
    required this.totalPageCount,
    required this.audioUrl,
    required this.audioManifestUrl,
    required this.audioHeaders,
    required this.displayChapterTitle,
    required this.executionContext,
    required this.document,
  });

  final String content;
  final bool fromCache;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
  final String? contentType;
  final String? sourceFilePath;
  final int? totalPageCount;
  final String? audioUrl;
  final String? audioManifestUrl;
  final Map<String, String> audioHeaders;
  final String? displayChapterTitle;
  final String? executionContext;
  final ReaderDocument document;

  bool get isImageContent => document.isPureImageDocument;
  bool get hasAudioContent =>
      (audioUrl?.isNotEmpty ?? false) ||
      (audioManifestUrl?.isNotEmpty ?? false);

  static String? _normalizeOptionalTextStatic(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool _shouldPreferImageOnlyDocument(String? normalizedContentType) {
    switch (normalizedContentType) {
      case 'manga':
      case 'comic-book':
      case 'comic_book':
      case 'comic':
        return true;
    }
    return false;
  }
}

class ChapterContentService {
  ChapterContentService({
    AppDatabase? database,
    SourceHealthService? sourceHealthService,
    ServerBookGatewayService? serverGatewayService,
    ContentTextCleaner? cleaner,
    AppLogger? logger,
  }) : _database = database ?? AppDatabase.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _serverGatewayService =
           serverGatewayService ?? ServerBookGatewayService(),
       _cleaner = cleaner ?? const ContentTextCleaner(),
       _logger = logger ?? AppLogger.instance;

  final AppDatabase _database;
  final SourceHealthService _sourceHealthService;
  final ServerBookGatewayService _serverGatewayService;
  final ContentTextCleaner _cleaner;
  final AppLogger _logger;

  static final Map<String, String> _chapterCache = <String, String>{};
  static const String _imageCachePrefix = '__appread_image_payload__:';

  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    String? bookTitle,
    String? detailUrl,
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

    if (isRemovedScriptSourceId(normalizedSourceId)) {
      throwRemovedScriptSource(
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
      );
    }

    final cacheKey = '$normalizedSourceId|$normalizedChapterUrl';
    final normalizedBookId = bookId?.trim() ?? '';
    final cached = _chapterCache[cacheKey];
    if (cached != null) {
      final decoded = _decodeCachedPayload(cached);
      _logger.info(
        'Chapter content cache hit',
        context: <String, Object?>{
          'chain': 'content',
          'step': 'content',
          'sourceId': normalizedSourceId,
          'bookId': normalizedBookId,
          'chapterUrl': normalizedChapterUrl,
          'cacheHit': true,
          'isImageContent': decoded.imageUrls.isNotEmpty,
        },
      );
      return ChapterContentResult(
        content: decoded.content,
        fromCache: true,
        imageUrls: decoded.imageUrls,
        imageHeaders: decoded.imageHeaders,
        executionContext: null,
      );
    }

    try {
      final persisted = await _database.getChapterCache(cacheKey);
      final persistedContent = persisted?.content.trim() ?? '';
      if (persistedContent.isNotEmpty) {
        _chapterCache[cacheKey] = persistedContent;
        final decoded = _decodeCachedPayload(persistedContent);
        _logger.info(
          'Chapter content cache hit',
          context: <String, Object?>{
            'chain': 'content',
            'step': 'content',
            'sourceId': normalizedSourceId,
            'bookId': normalizedBookId,
            'chapterUrl': normalizedChapterUrl,
            'cacheHit': true,
            'cacheSource': 'database',
            'isImageContent': decoded.imageUrls.isNotEmpty,
          },
        );
        return ChapterContentResult(
          content: decoded.content,
          fromCache: true,
          imageUrls: decoded.imageUrls,
          imageHeaders: decoded.imageHeaders,
          executionContext: null,
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

    if (isServerGatewaySourceId(normalizedSourceId)) {
      return _loadFromServerGateway(
        sourceId: normalizedSourceId,
        chapterUrl: normalizedChapterUrl,
        bookId: normalizedBookId,
        bookTitle: bookTitle?.trim(),
        detailUrl: detailUrl?.trim(),
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        cacheKey: cacheKey,
      );
    }

    throw AppException(
      code: ErrorCode.unknownSource,
      stage: ErrorStage.content,
      sourceId: normalizedSourceId,
      briefMessage: '当前书籍不属于服务器书源正文链路。',
    );
  }

  Future<ChapterContentResult> _loadFromServerGateway({
    required String sourceId,
    required String chapterUrl,
    required String bookId,
    required String? bookTitle,
    required String? detailUrl,
    required int? chapterIndex,
    required String? chapterTitle,
    required String cacheKey,
  }) async {
    try {
      final startedAt = DateTime.now();
      final content = await _serverGatewayService.loadContent(
        sourceId: sourceId,
        bookId: bookId,
        detailUrl: detailUrl ?? '',
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      );
      final rawContent = content.content.trim();
      final normalizedKind = content.kind.trim().toLowerCase();
      final normalizedImages = content.imageUrls
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final normalizedContent =
          normalizedImages.isEmpty ? _cleaner.clean(rawContent) : rawContent;
      final hasAudioContent =
          (content.audioUrl?.trim().isNotEmpty ?? false) ||
          (content.audioManifestUrl?.trim().isNotEmpty ?? false) ||
          content.contentType.trim().toLowerCase() == 'audio' ||
          normalizedKind == 'audio';
      if (normalizedContent.isEmpty &&
          normalizedImages.isEmpty &&
          !hasAudioContent) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          sourceId: sourceId,
          briefMessage: '服务器正文解析为空，请换源或稍后重试。',
        );
      }

      final cachePayload =
          normalizedImages.isNotEmpty
              ? _encodeImageCachePayload(
                normalizedImages,
                imageHeaders: content.imageHeaders,
              )
              : normalizedContent;
      _chapterCache[cacheKey] = cachePayload;
      await _persistChapterCache(
        cacheKey: cacheKey,
        bookId: bookId,
        sourceId: sourceId,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        chapterUrl: chapterUrl,
        content: cachePayload,
      );
      _sourceHealthService.markContentSuccess(sourceId: sourceId);
      _logger.info(
        'Server gateway content success',
        context: <String, Object?>{
          'chain': 'content',
          'step': 'server_gateway_content',
          'sourceId': sourceId,
          'bookId': bookId,
          'bookTitle': bookTitle,
          'chapterUrl': chapterUrl,
          'chapterIndex': chapterIndex,
          'cacheHit': content.cacheHit,
          'isImageContent': normalizedImages.isNotEmpty,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        },
      );
      return ChapterContentResult(
        content: normalizedContent,
        fromCache: content.cacheHit,
        imageUrls: normalizedImages,
        imageHeaders: content.imageHeaders,
        contentType:
            normalizedKind.isNotEmpty ? normalizedKind : content.contentType,
        audioUrl: content.audioUrl,
        audioManifestUrl: content.audioManifestUrl,
        audioHeaders: content.audioHeaders,
        displayChapterTitle: chapterTitle,
        executionContext: content.executionContext,
      );
    } on AppException catch (error) {
      _sourceHealthService.markContentFailure(
        sourceId: sourceId,
        message: error.briefMessage,
        error: error,
      );
      rethrow;
    }
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
