import 'dart:async';
import 'dart:collection';

import '../../../core/session/session_cancellation.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../reader/application/removed_script_source_guard.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_task_gate_service.dart';
import '../../source/application/source_runtime_facade.dart';

class BookDetailLoadResult {
  const BookDetailLoadResult({
    required this.detail,
    required this.chapters,
    required this.sourceName,
    required this.tocFromCache,
    this.tocError,
    this.catalogAvailable = true,
    this.catalogLoaded = true,
  });

  final BookDetail detail;
  final List<Chapter> chapters;
  final String sourceName;
  final bool tocFromCache;
  final AppException? tocError;
  final bool catalogAvailable;
  final bool catalogLoaded;

  BookDetailLoadResult copyWith({
    BookDetail? detail,
    List<Chapter>? chapters,
    String? sourceName,
    bool? tocFromCache,
    Object? tocError = _bookDetailUnset,
    bool? catalogAvailable,
    bool? catalogLoaded,
  }) {
    return BookDetailLoadResult(
      detail: detail ?? this.detail,
      chapters: chapters ?? this.chapters,
      sourceName: sourceName ?? this.sourceName,
      tocFromCache: tocFromCache ?? this.tocFromCache,
      tocError:
          identical(tocError, _bookDetailUnset)
              ? this.tocError
              : tocError as AppException?,
      catalogAvailable: catalogAvailable ?? this.catalogAvailable,
      catalogLoaded: catalogLoaded ?? this.catalogLoaded,
    );
  }
}

class BookDetailService {
  BookDetailService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    SourceRuntimeTaskGateService? taskGateService,
    AppLogger? logger,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _taskGateService =
           taskGateService ?? SourceRuntimeTaskGateService.instance,
       _logger = logger ?? AppLogger.instance;

  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final SourceRuntimeTaskGateService _taskGateService;
  final AppLogger _logger;

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
      catalogAvailable: cached.catalogAvailable,
      catalogLoaded: cached.catalogLoaded,
    );
  }

  void _writeDetailCache(String key, BookDetailLoadResult result) {
    if (!result.catalogLoaded) {
      return;
    }
    final snapshot = BookDetailLoadResult(
      detail: result.detail,
      chapters: List<Chapter>.unmodifiable(result.chapters),
      sourceName: result.sourceName,
      tocFromCache: false,
      tocError: null,
      catalogAvailable: result.catalogAvailable,
      catalogLoaded: result.catalogLoaded,
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
    if (!forceRefresh) {
      final cached = _readDetailCache(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    if (includeCatalog) {
      final existingInFlight = _inFlightLoads[cacheKey];
      if (existingInFlight != null) {
        return existingInFlight;
      }
    }

    final future =
        includeCatalog
            ? _loadFromScriptRuntime(
              sourceId: normalizedSourceId,
              bookId: normalizedBookId,
              detailUrl: normalizedDetailUrl,
              fallbackTitle: normalizedFallbackTitle,
              fallbackAuthor: normalizedFallbackAuthor,
              cacheKey: cacheKey,
            )
            : _loadSummaryFromScriptRuntime(
              sourceId: normalizedSourceId,
              bookId: normalizedBookId,
              detailUrl: normalizedDetailUrl,
              fallbackTitle: normalizedFallbackTitle,
              fallbackAuthor: normalizedFallbackAuthor,
            );
    if (!includeCatalog) {
      return future;
    }
    _inFlightLoads[cacheKey] = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightLoads[cacheKey], future)) {
        _inFlightLoads.remove(cacheKey);
      }
    }
  }

  Future<BookDetailLoadResult?> loadForBackgroundRefresh({
    required String sourceId,
    required String bookId,
    required String detailUrl,
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
    return _loadWithDiagnosticContainer(
      sourceId: normalizedSourceId,
      bookId: normalizedBookId,
      detailUrl: normalizedDetailUrl,
      fallbackTitle: normalizedFallbackTitle,
      fallbackAuthor: normalizedFallbackAuthor,
      cacheKey: cacheKey,
      cancellationHandle: cancellationHandle,
    );
  }

  Future<BookDetailLoadResult> _loadSummaryFromScriptRuntime({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    required String? fallbackTitle,
    required String? fallbackAuthor,
  }) async {
    final facade = _sourceRuntimeFacade;
    var currentStep = ErrorStage.detail;
    final registered =
        facade == null
            ? null
            : await facade.ensureRegisteredScriptSourceById(sourceId);
    if (facade == null || registered == null) {
      _sourceHealthService.markDetailFailure(
        sourceId: sourceId,
        message: '未找到书源：$sourceId',
      );
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
    try {
      final detailStartedAt = DateTime.now();
      final detailed = await _runDetailTask(
        source: registered,
        action: () => facade.detail(sourceId: sourceId, book: runtimeBook),
      );
      _sourceHealthService.markDetailSuccess(
        sourceId: sourceId,
        latencyMs: DateTime.now().difference(detailStartedAt).inMilliseconds,
      );
      _logger.info(
        'Runtime detail success',
        context: <String, Object?>{
          'chain': 'detail',
          'step': 'detail',
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'durationMs':
              DateTime.now().difference(detailStartedAt).inMilliseconds,
          'catalogRequested': false,
        },
      );

      return _buildDetailResult(
        bookId: bookId,
        sourceId: sourceId,
        fallbackTitle: fallbackTitle,
        detailUrl: detailUrl,
        detailed: detailed,
        sourceName: registered.runtime.name,
        chapters: const <Chapter>[],
        tocFromCache: false,
        catalogAvailable: true,
        catalogLoaded: false,
      );
    } on AppException catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: error.briefMessage,
        error: error,
      );
      _logger.warn(
        'Runtime detail chain failed',
        context: <String, Object?>{
          'chain': 'detail',
          'step': currentStep.name,
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'code': error.code.name,
          'stage': error.stage.name,
          'message': error.briefMessage,
          'catalogRequested': false,
        },
      );
      rethrow;
    } catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: error.toString(),
        error: error,
      );
      _logger.error(
        'Runtime detail chain crashed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: currentStep,
          sourceId: sourceId,
          briefMessage: error.toString(),
          cause: error,
        ),
        context: <String, Object?>{
          'chain': 'detail',
          'step': currentStep.name,
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'catalogRequested': false,
        },
      );
      rethrow;
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
    var currentStep = ErrorStage.detail;
    final registered =
        facade == null
            ? null
            : await facade.ensureRegisteredScriptSourceById(sourceId);
    if (facade == null || registered == null) {
      _sourceHealthService.markDetailFailure(
        sourceId: sourceId,
        message: '未找到书源：$sourceId',
      );
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
    try {
      final detailStartedAt = DateTime.now();
      final detailed = await _runDetailTask(
        source: registered,
        action: () => facade.detail(sourceId: sourceId, book: runtimeBook),
      );
      _sourceHealthService.markDetailSuccess(
        sourceId: sourceId,
        latencyMs: DateTime.now().difference(detailStartedAt).inMilliseconds,
      );
      _logger.info(
        'Runtime detail success',
        context: <String, Object?>{
          'chain': 'detail',
          'step': 'detail',
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'durationMs':
              DateTime.now().difference(detailStartedAt).inMilliseconds,
        },
      );
      currentStep = ErrorStage.toc;
      final chaptersStartedAt = DateTime.now();
      final runtimeChapters = await _runChaptersTask(
        source: registered,
        action: () => facade.chapters(sourceId: sourceId, book: detailed),
      );
      _sourceHealthService.markChaptersSuccess(sourceId: sourceId);
      _logger.info(
        'Runtime chapters success',
        context: <String, Object?>{
          'chain': 'detail',
          'step': 'chapters',
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'chapterCount': runtimeChapters.length,
          'durationMs':
              DateTime.now().difference(chaptersStartedAt).inMilliseconds,
        },
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

      final result = _buildDetailResult(
        bookId: bookId,
        sourceId: sourceId,
        fallbackTitle: fallbackTitle,
        detailUrl: detailUrl,
        detailed: detailed,
        sourceName: registered.runtime.name,
        chapters: chapters,
        tocFromCache: false,
        tocError: null,
        catalogAvailable: true,
        catalogLoaded: true,
      );
      _writeDetailCache(cacheKey, result);
      return result;
    } on AppException catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: error.briefMessage,
        error: error,
      );
      _logger.warn(
        'Runtime detail chain failed',
        context: <String, Object?>{
          'chain': 'detail',
          'step': currentStep.name,
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'code': error.code.name,
          'stage': error.stage.name,
          'message': error.briefMessage,
        },
      );
      rethrow;
    } catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: error.toString(),
        error: error,
      );
      _logger.error(
        'Runtime detail chain crashed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: currentStep,
          sourceId: sourceId,
          briefMessage: error.toString(),
          cause: error,
        ),
        context: <String, Object?>{
          'chain': 'detail',
          'step': currentStep.name,
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
        },
      );
      rethrow;
    }
  }

  Future<BookDetailLoadResult?> _loadWithDiagnosticContainer({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    required String? fallbackTitle,
    required String? fallbackAuthor,
    required String cacheKey,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final facade = _sourceRuntimeFacade;
    var currentStep = ErrorStage.detail;
    final registered =
        facade == null
            ? null
            : await facade.ensureRegisteredScriptSourceById(sourceId);
    if (facade == null || registered == null) {
      _sourceHealthService.markDetailFailure(
        sourceId: sourceId,
        message: '未找到书源：$sourceId',
      );
      throw UnknownSourceException(
        briefMessage: '未找到书源：$sourceId',
        sourceId: sourceId,
        stage: ErrorStage.detail,
      );
    }

    final diagnosticContainer = await facade
        .createDiagnosticExecutionContainerById(sourceId);
    if (diagnosticContainer == null) {
      _sourceHealthService.markDetailFailure(
        sourceId: sourceId,
        message: '未找到书源：$sourceId',
      );
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

    try {
      final detailStartedAt = DateTime.now();
      final detailed = await _runDetailTask(
        source: registered,
        action: () => diagnosticContainer.detail(runtimeBook),
      );
      if (cancellationHandle?.isCancelled ?? false) {
        return null;
      }
      _sourceHealthService.markDetailSuccess(
        sourceId: sourceId,
        latencyMs: DateTime.now().difference(detailStartedAt).inMilliseconds,
      );
      _logger.info(
        'Runtime detail success',
        context: <String, Object?>{
          'chain': 'detail',
          'step': 'detail',
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'durationMs':
              DateTime.now().difference(detailStartedAt).inMilliseconds,
          'runtimeMode': 'diagnostic_isolated',
        },
      );

      currentStep = ErrorStage.toc;
      final chaptersStartedAt = DateTime.now();
      final runtimeChapters = await _runChaptersTask(
        source: registered,
        action: () => diagnosticContainer.chapters(detailed),
      );
      if (cancellationHandle?.isCancelled ?? false) {
        return null;
      }
      _sourceHealthService.markChaptersSuccess(sourceId: sourceId);
      _logger.info(
        'Runtime chapters success',
        context: <String, Object?>{
          'chain': 'detail',
          'step': 'chapters',
          'sourceId': sourceId,
          'sourceName': registered.runtime.name,
          'bookId': bookId,
          'detailUrl': detailUrl,
          'chapterCount': runtimeChapters.length,
          'durationMs':
              DateTime.now().difference(chaptersStartedAt).inMilliseconds,
          'runtimeMode': 'diagnostic_isolated',
        },
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

      final result = _buildDetailResult(
        bookId: bookId,
        sourceId: sourceId,
        fallbackTitle: fallbackTitle,
        detailUrl: detailUrl,
        detailed: detailed,
        sourceName: registered.runtime.name,
        chapters: chapters,
        tocFromCache: false,
        tocError: null,
        catalogAvailable: true,
        catalogLoaded: true,
      );
      if (chapters.isNotEmpty) {
        _writeTocCache(cacheKey, chapters);
      }
      _writeDetailCache(cacheKey, result);
      return result;
    } on AppException catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: error.briefMessage,
        error: error,
      );
      rethrow;
    } catch (error) {
      if (error is SessionTaskCancelledException) {
        return null;
      }
      final message = error.toString();
      _recordStepFailure(
        sourceId: sourceId,
        stage: currentStep,
        message: message,
        error: error,
      );
      rethrow;
    } finally {
      diagnosticContainer.dispose();
    }
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

  BookDetailLoadResult _buildDetailResult({
    required String bookId,
    required String sourceId,
    required String? fallbackTitle,
    required String detailUrl,
    required runtime_models.Book detailed,
    required String sourceName,
    required List<Chapter> chapters,
    required bool tocFromCache,
    AppException? tocError,
    required bool catalogAvailable,
    required bool catalogLoaded,
  }) {
    return BookDetailLoadResult(
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
        latestChapterTitle: _normalizeOptionalText(detailed.latestChapter),
        totalChapterNum: chapters.isNotEmpty ? chapters.length : null,
        wordCount: _normalizeOptionalText(detailed.wordCount),
        category: _normalizeOptionalText(detailed.category),
        tags: detailed.tags
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
        updateTime: _normalizeOptionalText(detailed.updateTime),
      ),
      chapters: chapters,
      sourceName: sourceName,
      tocFromCache: tocFromCache,
      tocError: tocError,
      catalogAvailable: catalogAvailable,
      catalogLoaded: catalogLoaded,
    );
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<runtime_models.Book> _runDetailTask({
    required RegisteredSource source,
    required Future<runtime_models.Book> Function() action,
  }) {
    return _taskGateService.run<runtime_models.Book>(
      source: source,
      taskKind: SourceRuntimeTaskKind.detail,
      action: action,
    );
  }

  Future<List<runtime_models.Chapter>> _runChaptersTask({
    required RegisteredSource source,
    required Future<List<runtime_models.Chapter>> Function() action,
  }) {
    return _taskGateService.run<List<runtime_models.Chapter>>(
      source: source,
      taskKind: SourceRuntimeTaskKind.chapters,
      action: action,
    );
  }

  void _recordStepFailure({
    required String sourceId,
    required ErrorStage stage,
    required String message,
    Object? error,
  }) {
    switch (stage) {
      case ErrorStage.toc:
        _sourceHealthService.markChaptersFailure(
          sourceId: sourceId,
          message: message,
          error: error,
        );
        break;
      case ErrorStage.detail:
      default:
        _sourceHealthService.markDetailFailure(
          sourceId: sourceId,
          message: message,
          error: error,
        );
        break;
    }
  }
}

class _TimedCacheEntry<T> {
  _TimedCacheEntry(this.value) : storedAt = DateTime.now();

  final T value;
  final DateTime storedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}

const Object _bookDetailUnset = Object();
