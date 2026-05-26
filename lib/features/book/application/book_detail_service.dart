import 'dart:collection';

import '../../../core/session/session_cancellation.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../reader/application/removed_script_source_guard.dart';
import '../../search/application/server_book_gateway_service.dart';
import '../../search/application/server_gateway_identity.dart';
import '../../source/application/source_health_service.dart';

class BookDetailLoadResult {
  const BookDetailLoadResult({
    required this.detail,
    required this.chapters,
    required this.sourceName,
    required this.tocFromCache,
    this.executionContext,
    this.tocError,
    this.catalogAvailable = true,
    this.catalogLoaded = true,
    this.catalogComplete = true,
  });

  final BookDetail detail;
  final List<Chapter> chapters;
  final String sourceName;
  final bool tocFromCache;
  final String? executionContext;
  final AppException? tocError;
  final bool catalogAvailable;
  final bool catalogLoaded;
  final bool catalogComplete;

  BookDetailLoadResult copyWith({
    BookDetail? detail,
    List<Chapter>? chapters,
    String? sourceName,
    bool? tocFromCache,
    String? executionContext,
    Object? tocError = _bookDetailUnset,
    bool? catalogAvailable,
    bool? catalogLoaded,
    bool? catalogComplete,
  }) {
    return BookDetailLoadResult(
      detail: detail ?? this.detail,
      chapters: chapters ?? this.chapters,
      sourceName: sourceName ?? this.sourceName,
      tocFromCache: tocFromCache ?? this.tocFromCache,
      executionContext: executionContext ?? this.executionContext,
      tocError:
          identical(tocError, _bookDetailUnset)
              ? this.tocError
              : tocError as AppException?,
      catalogAvailable: catalogAvailable ?? this.catalogAvailable,
      catalogLoaded: catalogLoaded ?? this.catalogLoaded,
      catalogComplete: catalogComplete ?? this.catalogComplete,
    );
  }
}

class BookDetailService {
  BookDetailService({
    SourceHealthService? sourceHealthService,
    ServerBookGatewayService? serverGatewayService,
  }) : _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _serverGatewayService =
           serverGatewayService ?? ServerBookGatewayService();

  final SourceHealthService _sourceHealthService;
  final ServerBookGatewayService _serverGatewayService;

  static const int _maxDetailCacheEntries = 120;
  static const Duration _detailCacheTtl = Duration(minutes: 20);

  static final LinkedHashMap<String, _TimedCacheEntry<BookDetailLoadResult>>
  _detailCache =
      LinkedHashMap<String, _TimedCacheEntry<BookDetailLoadResult>>();

  BookDetailLoadResult? peekCached({
    required String sourceId,
    required String detailUrl,
  }) {
    final key = '${sourceId.trim()}|${detailUrl.trim()}';
    return _readDetailCache(key);
  }

  BookDetailLoadResult? _readDetailCache(String key) {
    final entry = _detailCache[key];
    if (entry == null) {
      return null;
    }
    if (entry.isExpired(_detailCacheTtl)) {
      _detailCache.remove(key);
      return null;
    }
    _touchCacheEntry(_detailCache, key, entry);
    final cached = entry.value;
    return BookDetailLoadResult(
      detail: cached.detail,
      chapters: List<Chapter>.unmodifiable(cached.chapters),
      sourceName: cached.sourceName,
      tocFromCache: true,
      executionContext: cached.executionContext,
      tocError: null,
      catalogAvailable: cached.catalogAvailable,
      catalogLoaded: cached.catalogLoaded,
      catalogComplete: cached.catalogComplete,
    );
  }

  void _writeDetailCache(String key, BookDetailLoadResult result) {
    if (!result.catalogLoaded || !result.catalogComplete) {
      return;
    }
    final snapshot = BookDetailLoadResult(
      detail: result.detail,
      chapters: List<Chapter>.unmodifiable(result.chapters),
      sourceName: result.sourceName,
      tocFromCache: false,
      executionContext: result.executionContext,
      tocError: null,
      catalogAvailable: result.catalogAvailable,
      catalogLoaded: result.catalogLoaded,
      catalogComplete: result.catalogComplete,
    );
    _detailCache.remove(key);
    _detailCache[key] = _TimedCacheEntry<BookDetailLoadResult>(snapshot);
    _trimCache(_detailCache, _maxDetailCacheEntries);
  }

  void _touchCacheEntry<T>(
    LinkedHashMap<String, _TimedCacheEntry<T>> cache,
    String key,
    _TimedCacheEntry<T> entry,
  ) {
    cache.remove(key);
    cache[key] = entry;
  }

  void _trimCache<T>(
    LinkedHashMap<String, _TimedCacheEntry<T>> cache,
    int maxEntries,
  ) {
    while (cache.length > maxEntries) {
      final firstKey = cache.keys.first;
      cache.remove(firstKey);
    }
  }

  Future<BookDetailLoadResult> load({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    Book? initialBook,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedBookId = bookId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    final normalizedFallbackTitle = _normalizeOptionalText(fallbackTitle);
    final normalizedFallbackAuthor = _normalizeOptionalText(fallbackAuthor);

    if (normalizedSourceId.isEmpty ||
        normalizedBookId.isEmpty ||
        normalizedDetailUrl.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '加载详情缺少参数。',
      );
    }

    if (isRemovedScriptSourceId(normalizedSourceId)) {
      throwRemovedScriptSource(
        stage: ErrorStage.detail,
        sourceId: normalizedSourceId,
      );
    }

    final cacheKey = '$normalizedSourceId|$normalizedDetailUrl';
    if (isServerGatewaySourceId(normalizedSourceId)) {
      if (!forceRefresh) {
        final cached = _readDetailCache(cacheKey);
        if (cached != null) {
          return cached;
        }
      }
      final result = await _loadFromServerGateway(
        sourceId: normalizedSourceId,
        bookId: normalizedBookId,
        detailUrl: normalizedDetailUrl,
        initialBook: initialBook,
        fallbackTitle: normalizedFallbackTitle,
        fallbackAuthor: normalizedFallbackAuthor,
        forceRefresh: forceRefresh,
        includeCatalog: includeCatalog,
      );
      if (includeCatalog) {
        _writeDetailCache(cacheKey, result);
      }
      return result;
    }

    throw AppException(
      code: ErrorCode.unknownSource,
      stage: ErrorStage.detail,
      sourceId: normalizedSourceId,
      briefMessage: '当前书籍不属于服务器书源详情链路。',
    );
  }

  Future<BookDetailLoadResult?> loadForBackgroundRefresh({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    Book? initialBook,
    String? fallbackTitle,
    String? fallbackAuthor,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedBookId = bookId.trim();
    final normalizedDetailUrl = detailUrl.trim();
    final normalizedFallbackTitle = _normalizeOptionalText(fallbackTitle);
    final normalizedFallbackAuthor = _normalizeOptionalText(fallbackAuthor);

    if (normalizedSourceId.isEmpty ||
        normalizedBookId.isEmpty ||
        normalizedDetailUrl.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '加载详情缺少参数。',
      );
    }

    if (isRemovedScriptSourceId(normalizedSourceId)) {
      throwRemovedScriptSource(
        stage: ErrorStage.detail,
        sourceId: normalizedSourceId,
      );
    }

    final cacheKey = '$normalizedSourceId|$normalizedDetailUrl';
    if (isServerGatewaySourceId(normalizedSourceId)) {
      if (cancellationHandle?.isCancelled ?? false) {
        return null;
      }
      final result = await _loadFromServerGateway(
        sourceId: normalizedSourceId,
        bookId: normalizedBookId,
        detailUrl: normalizedDetailUrl,
        initialBook: initialBook,
        fallbackTitle: normalizedFallbackTitle,
        fallbackAuthor: normalizedFallbackAuthor,
        forceRefresh: true,
        includeCatalog: true,
      );
      if (cancellationHandle?.isCancelled ?? false) {
        return null;
      }
      _writeDetailCache(cacheKey, result);
      return result;
    }
    throw AppException(
      code: ErrorCode.unknownSource,
      stage: ErrorStage.detail,
      sourceId: normalizedSourceId,
      briefMessage: '当前书籍不属于服务器书源详情链路。',
    );
  }

  Future<BookDetailLoadResult> _loadFromServerGateway({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    required Book? initialBook,
    required String? fallbackTitle,
    required String? fallbackAuthor,
    required bool forceRefresh,
    required bool includeCatalog,
  }) async {
    final startedAt = DateTime.now();
    final detail = await _serverGatewayService.loadDetail(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      tocUrl: initialBook?.tocUrl,
      executionContext: initialBook?.executionContext,
      infoHtml: initialBook?.infoHtml,
      tocHtml: initialBook?.tocHtml,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      coverUrl: initialBook?.coverUrl,
      refresh: forceRefresh,
    );
    _sourceHealthService.markDetailSuccess(
      sourceId: sourceId,
      latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
    if (!includeCatalog) {
      return BookDetailLoadResult(
        detail: detail.detail,
        chapters: const <Chapter>[],
        sourceName: detail.sourceName,
        tocFromCache: detail.cacheHit,
        executionContext: detail.executionContext,
        catalogAvailable: true,
        catalogLoaded: false,
        catalogComplete: false,
      );
    }

    try {
      final toc = await _serverGatewayService.loadTocComplete(
        sourceId: detail.detail.sourceId,
        bookId: detail.detail.id,
        detailUrl: detail.detail.detailUrl,
        tocUrl: detail.detail.tocUrl,
        executionContext: detail.executionContext,
        refresh: forceRefresh,
      );
      _sourceHealthService.markChaptersSuccess(sourceId: sourceId);
      return BookDetailLoadResult(
        detail: detail.detail,
        chapters: toc.chapters,
        sourceName: detail.sourceName,
        tocFromCache: detail.cacheHit || toc.cacheHit,
        executionContext: toc.executionContext ?? detail.executionContext,
        catalogAvailable: true,
        catalogLoaded: true,
        catalogComplete: toc.isComplete,
      );
    } on AppException catch (error) {
      _sourceHealthService.markChaptersFailure(
        sourceId: sourceId,
        message: error.briefMessage,
        error: error,
      );
      return BookDetailLoadResult(
        detail: detail.detail,
        chapters: const <Chapter>[],
        sourceName: detail.sourceName,
        tocFromCache: detail.cacheHit,
        executionContext: detail.executionContext,
        tocError: error,
        catalogAvailable: true,
        catalogLoaded: false,
        catalogComplete: false,
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
}

class _TimedCacheEntry<T> {
  _TimedCacheEntry(this.value) : storedAt = DateTime.now();

  final T value;
  final DateTime storedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}

const Object _bookDetailUnset = Object();
