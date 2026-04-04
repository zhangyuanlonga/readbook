import 'dart:async';
import 'dart:collection';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../source/application/source_runtime_facade.dart';

class BookDetailLoadResult {
  const BookDetailLoadResult({
    required this.detail,
    required this.chapters,
    required this.sourceName,
    required this.tocFromCache,
    this.tocError,
  });

  final BookDetail detail;
  final List<Chapter> chapters;
  final String sourceName;
  final bool tocFromCache;
  final AppException? tocError;
}

class BookDetailService {
  BookDetailService({SourceRuntimeFacade? sourceRuntimeFacade})
    : _sourceRuntimeFacade =
          sourceRuntimeFacade ?? SourceRuntimeFacade.instance;

  final SourceRuntimeFacade? _sourceRuntimeFacade;

  static const int _maxDetailCacheEntries = 120;
  static const int _maxTocCacheEntries = 120;
  static const Duration _detailCacheTtl = Duration(minutes: 20);

  static final LinkedHashMap<String, _TimedCacheEntry<BookDetailLoadResult>>
  _detailCache =
      LinkedHashMap<String, _TimedCacheEntry<BookDetailLoadResult>>();
  static final LinkedHashMap<String, _TimedCacheEntry<List<Chapter>>>
  _tocCache = LinkedHashMap<String, _TimedCacheEntry<List<Chapter>>>();
  static final Map<String, Future<BookDetailLoadResult>> _inFlightLoads =
      <String, Future<BookDetailLoadResult>>{};

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
      tocError: null,
    );
  }

  void _writeDetailCache(String key, BookDetailLoadResult result) {
    final snapshot = BookDetailLoadResult(
      detail: result.detail,
      chapters: List<Chapter>.unmodifiable(result.chapters),
      sourceName: result.sourceName,
      tocFromCache: false,
      tocError: null,
    );
    _detailCache.remove(key);
    _detailCache[key] = _TimedCacheEntry<BookDetailLoadResult>(snapshot);
    _trimCache(_detailCache, _maxDetailCacheEntries);
  }

  void _writeTocCache(String key, List<Chapter> chapters) {
    _tocCache.remove(key);
    _tocCache[key] = _TimedCacheEntry<List<Chapter>>(
      List<Chapter>.unmodifiable(chapters),
    );
    _trimCache(_tocCache, _maxTocCacheEntries);
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
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
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

    final cacheKey = '$normalizedSourceId|$normalizedDetailUrl';
    if (!forceRefresh) {
      final cached = _readDetailCache(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    final existingInFlight = _inFlightLoads[cacheKey];
    if (existingInFlight != null) {
      return existingInFlight;
    }

    final future = _loadFromScriptRuntime(
      sourceId: normalizedSourceId,
      bookId: normalizedBookId,
      detailUrl: normalizedDetailUrl,
      fallbackTitle: normalizedFallbackTitle,
      fallbackAuthor: normalizedFallbackAuthor,
      cacheKey: cacheKey,
    );
    _inFlightLoads[cacheKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightLoads[cacheKey], future)) {
        _inFlightLoads.remove(cacheKey);
      }
    }
  }

  Future<BookDetailLoadResult> _loadFromScriptRuntime({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    required String? fallbackTitle,
    required String? fallbackAuthor,
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
        stage: ErrorStage.detail,
      );
    }

    final runtimeBook = runtime_models.Book(
      title: fallbackTitle ?? bookId,
      author: fallbackAuthor ?? '',
      detailUrl: detailUrl,
      sourceId: sourceId,
    );
    final detailed = await facade.detail(sourceId: sourceId, book: runtimeBook);
    final runtimeChapters = await facade.chapters(
      sourceId: sourceId,
      book: detailed,
    );

    final chapters = runtimeChapters
        .map(
          (chapter) => Chapter(
            id: _buildScriptChapterId(
              bookId: bookId,
              chapterUrl: chapter.url,
              index: chapter.index,
            ),
            bookId: bookId,
            title:
                chapter.title.trim().isNotEmpty
                    ? chapter.title.trim()
                    : chapter.isVolume
                    ? '未命名分卷'
                    : '第 ${chapter.index + 1} 章',
            chapterUrl: chapter.url.trim(),
            index: chapter.index,
            isVolume: chapter.isVolume,
          ),
        )
        .toList(growable: false);

    if (chapters.isNotEmpty) {
      _writeTocCache(cacheKey, chapters);
    }

    final result = BookDetailLoadResult(
      detail: BookDetail(
        id: bookId,
        sourceId: sourceId,
        title:
            detailed.title.trim().isNotEmpty
                ? detailed.title.trim()
                : (fallbackTitle ?? '未命名书籍'),
        detailUrl:
            detailed.detailUrl.trim().isNotEmpty
                ? detailed.detailUrl.trim()
                : detailUrl,
        author: _normalizeOptionalText(detailed.author),
        intro: _normalizeOptionalText(detailed.intro),
        coverUrl: _normalizeOptionalText(detailed.cover),
        tocUrl:
            _normalizeOptionalText(detailed.tocUrl) ??
            _normalizeOptionalText(detailed.extra['tocUrl']?.toString()) ??
            _normalizeOptionalText(detailed.extra['catalogUrl']?.toString()),
      ),
      chapters: chapters,
      sourceName: registered.runtime.name,
      tocFromCache: false,
      tocError: null,
    );
    _writeDetailCache(cacheKey, result);
    return result;
  }

  String _buildScriptChapterId({
    required String bookId,
    required String chapterUrl,
    required int index,
  }) {
    final normalizedChapterUrl = chapterUrl.trim();
    if (normalizedChapterUrl.isNotEmpty) {
      return '$bookId:${Uri.encodeComponent(normalizedChapterUrl)}';
    }
    return '${bookId}_$index';
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
