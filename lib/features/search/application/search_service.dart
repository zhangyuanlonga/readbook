import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/request_context.dart';
import '../../../domain/entities/book.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../source/application/source_runtime_facade.dart';
import 'search_hit_cache_service.dart';
import 'search_system_settings_service.dart';

class SourceSearchFailure {
  const SourceSearchFailure({
    required this.sourceId,
    required this.sourceName,
    required this.message,
    required this.code,
    required this.stage,
    this.requestUrl,
    this.debugMessage,
  });

  final String sourceId;
  final String sourceName;
  final String message;
  final ErrorCode code;
  final ErrorStage stage;
  final String? requestUrl;
  final String? debugMessage;
}

class SearchExecutionReport {
  const SearchExecutionReport({
    required this.keyword,
    required this.sourceCount,
    required this.successSourceCount,
    required this.books,
    required this.failures,
    required this.sourceNames,
    this.bookSourceHitCounts = const <String, int>{},
    this.bookSourceHits = const <String, List<Book>>{},
  });

  final String keyword;
  final int sourceCount;
  final int successSourceCount;
  final List<Book> books;
  final List<SourceSearchFailure> failures;
  final Map<String, String> sourceNames;
  final Map<String, int> bookSourceHitCounts;
  final Map<String, List<Book>> bookSourceHits;

  int get failedSourceCount => failures.length;
  int get processedSourceCount => successSourceCount + failedSourceCount;

  int sourceHitCountOf(Book book) => bookSourceHitCounts[book.id] ?? 1;

  List<Book> sourceHitsOf(Book book) {
    final hits = bookSourceHits[book.id];
    if (hits == null || hits.isEmpty) {
      return <Book>[book];
    }
    return hits;
  }
}

typedef SearchProgressCallback = void Function(SearchExecutionReport report);

enum SearchContentMode { novel, manga }

class SearchCancellationToken {
  bool _cancelled = false;
  bool _paused = false;
  Completer<void>? _resumeCompleter;

  bool get isCancelled => _cancelled;
  bool get isPaused => _paused && !_cancelled;

  void pause() {
    if (_cancelled || _paused) {
      return;
    }
    _paused = true;
    _resumeCompleter ??= Completer<void>();
  }

  void resume() {
    if (_cancelled || !_paused) {
      return;
    }
    _paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }

  Future<void> waitIfPaused() async {
    while (!_cancelled && _paused) {
      final completer = _resumeCompleter ??= Completer<void>();
      await completer.future;
    }
  }

  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    _paused = false;
    _resumeCompleter?.complete();
    _resumeCompleter = null;
  }
}

class SearchService {
  SearchService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    AppLogger? logger,
    SearchHitCacheService? searchHitCacheService,
    SearchSystemSettingsService? searchSystemSettingsService,
    int maxConcurrentSources =
        SearchSystemSettingsService.defaultMaxConcurrentSources,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _logger = logger ?? AppLogger.instance,
       _searchHitCacheService =
           searchHitCacheService ?? SearchHitCacheService(),
       _searchSystemSettingsService =
           searchSystemSettingsService ?? SearchSystemSettingsService(),
       _maxConcurrentSources = max(
         SearchSystemSettingsService.minMaxConcurrentSources,
         maxConcurrentSources,
       );

  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final AppLogger _logger;
  final SearchHitCacheService _searchHitCacheService;
  final SearchSystemSettingsService _searchSystemSettingsService;

  int _maxConcurrentSources;
  bool _searchDebugLoggingEnabled = false;
  bool _searchDebugLoggingSettingLoaded = false;
  static const Duration _progressAggregationInterval = Duration(
    milliseconds: 900,
  );

  void setSearchDebugLoggingEnabled(bool enabled) {
    _searchDebugLoggingEnabled = enabled;
    _searchDebugLoggingSettingLoaded = true;
  }

  void setMaxConcurrentSources(int value) {
    _maxConcurrentSources = value.clamp(
      SearchSystemSettingsService.minMaxConcurrentSources,
      SearchSystemSettingsService.maxMaxConcurrentSources,
    );
  }

  Future<SearchExecutionReport> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
    SearchContentMode contentMode = SearchContentMode.novel,
    List<String>? sourceIds,
    bool aggregateByTitleAuthor = false,
  }) async {
    await _syncSearchDebugLoggingSetting();
    await _syncMaxConcurrentSourcesSetting();
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: '搜索关键词不能为空。',
      );
    }

    var enabledScriptSources = await _loadAvailableScriptSources(
      contentMode: contentMode,
    );

    final sourceIdSet =
        sourceIds
            ?.map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    if (sourceIdSet != null && sourceIdSet.isNotEmpty) {
      enabledScriptSources = enabledScriptSources
          .where((source) => sourceIdSet.contains(source.runtime.id))
          .toList(growable: false);
    }

    if (enabledScriptSources.isEmpty) {
      if (sourceIdSet != null && sourceIdSet.isNotEmpty) {
        throw UnknownSourceException(
          briefMessage: '没有可用已选书源，请调整筛选条件或启用书源。',
          stage: ErrorStage.search,
        );
      }
      final modeLabel = contentMode == SearchContentMode.manga ? '漫画' : '小说';
      throw UnknownSourceException(
        briefMessage: '没有可用$modeLabel书源，请先在书源页导入并启用对应书源。',
        stage: ErrorStage.search,
      );
    }

    final allTargets = <_SearchTarget>[
      ...enabledScriptSources.map(_SearchTarget.script),
    ];
    final concurrency = min(_maxConcurrentSources, allTargets.length);

    _searchDebugInfo(
      'Search started',
      context: {
        'keyword': normalizedKeyword,
        'sourceCount': allTargets.length,
        'page': page,
        'pageSize': pageSize,
        'concurrency': concurrency,
        'contentMode': contentMode.name,
        'selectedSourceCount': sourceIdSet?.length ?? 0,
      },
    );

    final sourceNames = <String, String>{
      for (final source in enabledScriptSources)
        source.runtime.id: source.runtime.name,
    };
    final sourceOrderById = <String, int>{
      for (var index = 0; index < allTargets.length; index++)
        allTargets[index].sourceId: index,
    };

    final booksById = <String, Book>{};
    final failures = <SourceSearchFailure>[];
    var successSourceCount = 0;
    var progressAggregationState = const _ProgressAggregationState();

    final pendingSources = Queue<_SearchTarget>.from(allTargets);
    final workerCount = min(concurrency, pendingSources.length);

    Future<void> worker() async {
      while (true) {
        if (cancellationToken?.isCancelled ?? false) {
          return;
        }

        if (cancellationToken != null) {
          await cancellationToken.waitIfPaused();
          if (cancellationToken.isCancelled) {
            return;
          }
        }

        if (pendingSources.isEmpty) {
          return;
        }

        final source = pendingSources.removeFirst();
        final startAt = DateTime.now();

        try {
          final report = await _searchSingleScriptSource(
            source: source.scriptSource,
            keyword: normalizedKeyword,
          );

          successSourceCount++;
          for (final book in report.books) {
            booksById[book.id] = book;
          }

          _searchDebugInfo(
            'Search source success',
            context: {
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
              'bookCount': report.books.length,
              'requestUrl': report.requestUrl,
              'method': report.method.name,
              'statusCode': report.statusCode,
              'durationMs': DateTime.now().difference(startAt).inMilliseconds,
            },
          );
        } on AppException catch (error) {
          final failure = SourceSearchFailure(
            sourceId: source.sourceId,
            sourceName: source.sourceName,
            message: _toUserReadableMessage(error),
            code: error.code,
            stage: error.stage,
            requestUrl: error.requestUrl,
            debugMessage: error.briefMessage,
          );
          failures.add(failure);

          _logger.warn(
            'Search source failed',
            context: {
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
              'code': error.code.name,
              'stage': error.stage.name,
              'message': error.briefMessage,
              'requestUrl': error.requestUrl,
              'durationMs': DateTime.now().difference(startAt).inMilliseconds,
            },
          );
        } catch (error, stackTrace) {
          final rawDetail = _sanitizeDebugMessage(error.toString());
          final exception = AppException(
            code: ErrorCode.unknown,
            stage: ErrorStage.search,
            sourceId: source.sourceId,
            briefMessage:
                rawDetail.isEmpty ? '搜索失败：${source.sourceName}' : rawDetail,
            cause: error,
            stackTrace: stackTrace,
          );
          failures.add(
            SourceSearchFailure(
              sourceId: source.sourceId,
              sourceName: source.sourceName,
              message: _toUserReadableMessage(exception),
              code: exception.code,
              stage: exception.stage,
              requestUrl: exception.requestUrl,
              debugMessage: rawDetail.isEmpty ? null : rawDetail,
            ),
          );

          _logger.error(
            'Search source crashed',
            exception: exception,
            context: {
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
            },
          );
        }

        progressAggregationState = await _emitProgress(
          keyword: normalizedKeyword,
          sourceCount: allTargets.length,
          successSourceCount: successSourceCount,
          booksById: booksById,
          failures: failures,
          sourceNames: sourceNames,
          sourceOrderById: sourceOrderById,
          aggregateByTitleAuthor: aggregateByTitleAuthor,
          onProgress: onProgress,
          progressAggregationState: progressAggregationState,
        );
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    final finalReport = await _buildExecutionReport(
      keyword: normalizedKeyword,
      sourceCount: allTargets.length,
      successSourceCount: successSourceCount,
      booksById: booksById,
      failures: failures,
      sourceNames: sourceNames,
      sourceOrderById: sourceOrderById,
      aggregateByTitleAuthor: aggregateByTitleAuthor,
    );
    await _persistSearchHitCache(
      books: booksById.values,
      sourceNames: sourceNames,
    );

    if (cancellationToken?.isCancelled ?? false) {
      _searchDebugInfo(
        'Search cancelled',
        context: {
          'keyword': normalizedKeyword,
          'processedSources': finalReport.processedSourceCount,
          'sourceCount': finalReport.sourceCount,
          'bookCount': finalReport.books.length,
        },
      );
      return finalReport;
    }

    _searchDebugInfo(
      'Search finished',
      context: {
        'keyword': normalizedKeyword,
        'successSources': finalReport.successSourceCount,
        'failedSources': finalReport.failedSourceCount,
        'bookCount': finalReport.books.length,
      },
    );

    return finalReport;
  }

  Future<List<RegisteredSource>> _loadAvailableScriptSources({
    required SearchContentMode contentMode,
  }) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      return const <RegisteredSource>[];
    }

    var sources = facade.registeredScriptSources(enabledOnly: true);
    if (sources.isEmpty) {
      final report = await facade.reloadScriptSources();
      sources = report.loaded;
    }
    return _filterScriptSourcesByContentMode(
      sources: sources,
      contentMode: contentMode,
    );
  }

  List<RegisteredSource> _filterScriptSourcesByContentMode({
    required List<RegisteredSource> sources,
    required SearchContentMode contentMode,
  }) {
    return sources
        .where(
          (source) =>
              _matchesScriptSourceContentMode(source, contentMode: contentMode),
        )
        .toList(growable: false);
  }

  bool _matchesScriptSourceContentMode(
    RegisteredSource source, {
    required SearchContentMode contentMode,
  }) {
    final manifest = source.definition.manifest;
    final capabilities =
        manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    final declaresManga =
        capabilities.contains('manga') ||
        capabilities.contains('comic') ||
        capabilities.contains('manhua') ||
        capabilities.contains('manhwa');
    final declaresNovel =
        capabilities.contains('novel') ||
        capabilities.contains('book') ||
        capabilities.contains('text');

    if (contentMode == SearchContentMode.manga) {
      return declaresManga;
    }

    if (declaresManga && !declaresNovel) {
      return false;
    }
    return true;
  }

  Future<_SourceSearchOutput> _searchSingleScriptSource({
    required RegisteredSource source,
    required String keyword,
  }) async {
    final facade = _sourceRuntimeFacade;
    if (facade == null) {
      throw StateError('SourceRuntimeFacade is unavailable.');
    }

    final books = await facade.search(
      sourceId: source.runtime.id,
      keyword: keyword,
    );
    return _SourceSearchOutput(
      requestUrl: '',
      method: HttpRequestMethod.get,
      statusCode: 200,
      books: books
          .map(
            (book) =>
                _mapRuntimeBookToDomain(book, sourceId: source.runtime.id),
          )
          .toList(growable: false),
    );
  }

  Book _mapRuntimeBookToDomain(
    runtime_models.Book book, {
    required String sourceId,
  }) {
    final normalizedDetailUrl = book.detailUrl.trim();
    final resolvedId = _buildRuntimeBookId(
      sourceId: sourceId,
      detailUrl: normalizedDetailUrl,
      title: book.title,
    );
    return Book(
      id: resolvedId,
      sourceId: sourceId,
      title: book.title.trim().isEmpty ? '未命名书籍' : book.title.trim(),
      detailUrl: normalizedDetailUrl,
      author: _normalizeOptionalText(book.author),
      intro: _normalizeOptionalText(book.intro),
      coverUrl: _normalizeOptionalText(book.cover),
      latestChapter: _normalizeOptionalText(book.latestChapter),
    );
  }

  String _buildRuntimeBookId({
    required String sourceId,
    required String detailUrl,
    required String title,
  }) {
    final normalizedDetailUrl = detailUrl.trim();
    if (normalizedDetailUrl.isNotEmpty) {
      return '$sourceId:${Uri.encodeComponent(normalizedDetailUrl)}';
    }
    return '$sourceId:${Uri.encodeComponent(title.trim())}';
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<void> _syncMaxConcurrentSourcesSetting() async {
    try {
      final value =
          await _searchSystemSettingsService.loadMaxConcurrentSources();
      setMaxConcurrentSources(value);
    } catch (_) {}
  }

  Future<void> _persistSearchHitCache({
    required Iterable<Book> books,
    required Map<String, String> sourceNames,
  }) async {
    if (books.isEmpty) {
      return;
    }

    try {
      await _searchHitCacheService.recordBooks(books, sourceNames: sourceNames);
    } catch (error) {
      _logger.warn(
        'Persist search hit cache failed',
        context: <String, Object?>{'error': error.toString()},
      );
    }
  }

  Future<SearchExecutionReport> _buildExecutionReport({
    required String keyword,
    required int sourceCount,
    required int successSourceCount,
    required Map<String, Book> booksById,
    required List<SourceSearchFailure> failures,
    required Map<String, String> sourceNames,
    required Map<String, int> sourceOrderById,
    required bool aggregateByTitleAuthor,
  }) async {
    final books = booksById.values.toList(growable: false);
    final hitCounts = <String, int>{};
    final hitBooks = <String, List<Book>>{};

    late final List<Book> outputBooks;
    if (aggregateByTitleAuthor) {
      final aggregated = await _aggregateAndRankBooksAsync(
        keyword: keyword,
        books: books,
        sourceOrderById: sourceOrderById,
      );
      outputBooks = aggregated.books;
      hitCounts.addAll(aggregated.hitCountsByPrimaryBookId);
      hitBooks.addAll(aggregated.hitsByPrimaryBookId);
    } else {
      outputBooks = books;
      for (final book in books) {
        hitCounts[book.id] = 1;
        hitBooks[book.id] = List.unmodifiable(<Book>[book]);
      }
    }

    return SearchExecutionReport(
      keyword: keyword,
      sourceCount: sourceCount,
      successSourceCount: successSourceCount,
      books: List.unmodifiable(outputBooks),
      failures: List.unmodifiable(failures),
      sourceNames: Map.unmodifiable(sourceNames),
      bookSourceHitCounts: Map.unmodifiable(hitCounts),
      bookSourceHits: Map.unmodifiable(hitBooks),
    );
  }

  Future<_ProgressAggregationState> _emitProgress({
    required String keyword,
    required int sourceCount,
    required int successSourceCount,
    required Map<String, Book> booksById,
    required List<SourceSearchFailure> failures,
    required Map<String, String> sourceNames,
    required Map<String, int> sourceOrderById,
    required bool aggregateByTitleAuthor,
    required SearchProgressCallback? onProgress,
    required _ProgressAggregationState progressAggregationState,
  }) async {
    if (onProgress == null) {
      return progressAggregationState;
    }

    final processedSourceCount = successSourceCount + failures.length;
    final now = DateTime.now();
    final lastProgressEmittedAt =
        progressAggregationState.lastProgressEmittedAt;
    final shouldEmitProgress =
        processedSourceCount >= sourceCount ||
        lastProgressEmittedAt == null ||
        now.difference(lastProgressEmittedAt) >= _progressAggregationInterval;
    if (!shouldEmitProgress) {
      return progressAggregationState;
    }

    final shouldRefreshAggregatedBooks =
        !aggregateByTitleAuthor ||
        progressAggregationState.cachedAggregatedReport == null ||
        processedSourceCount >= sourceCount ||
        progressAggregationState.lastAggregatedAt == null ||
        now.difference(progressAggregationState.lastAggregatedAt!) >=
            _progressAggregationInterval;

    final SearchExecutionReport report;
    var nextState = progressAggregationState;
    if (shouldRefreshAggregatedBooks) {
      report = await _buildExecutionReport(
        keyword: keyword,
        sourceCount: sourceCount,
        successSourceCount: successSourceCount,
        booksById: booksById,
        failures: failures,
        sourceNames: sourceNames,
        sourceOrderById: sourceOrderById,
        aggregateByTitleAuthor: aggregateByTitleAuthor,
      );
      if (aggregateByTitleAuthor) {
        nextState = _ProgressAggregationState(
          cachedAggregatedReport: report,
          lastAggregatedAt: now,
        );
      }
    } else {
      final cachedReport = progressAggregationState.cachedAggregatedReport!;
      report = SearchExecutionReport(
        keyword: keyword,
        sourceCount: sourceCount,
        successSourceCount: successSourceCount,
        books: cachedReport.books,
        failures: List.unmodifiable(failures),
        sourceNames: Map.unmodifiable(sourceNames),
        bookSourceHitCounts: cachedReport.bookSourceHitCounts,
        bookSourceHits: cachedReport.bookSourceHits,
      );
    }

    try {
      onProgress(report);
      return nextState.copyWith(lastProgressEmittedAt: now);
    } catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.search,
        briefMessage: '搜索进度回调执行失败。',
        cause: error,
        stackTrace: stackTrace,
      );
      _logger.warn(
        'Search progress callback failed',
        context: {'message': exception.briefMessage},
      );
      return nextState.copyWith(lastProgressEmittedAt: lastProgressEmittedAt);
    }
  }

  Future<_AggregatedBookReport> _aggregateAndRankBooksAsync({
    required String keyword,
    required Iterable<Book> books,
    required Map<String, int> sourceOrderById,
  }) async {
    final candidateBooks = books.toList(growable: false);
    if (candidateBooks.length < 160) {
      return _aggregateAndRankBooks(
        keyword: keyword,
        books: candidateBooks,
        sourceOrderById: sourceOrderById,
      );
    }

    try {
      return await Isolate.run(
        () => _aggregateAndRankBooksInIsolate(
          _AggregateAndRankInput(
            keyword: keyword,
            books: candidateBooks,
            sourceOrderById: sourceOrderById,
          ),
        ),
      );
    } catch (_) {
      return _aggregateAndRankBooks(
        keyword: keyword,
        books: candidateBooks,
        sourceOrderById: sourceOrderById,
      );
    }
  }

  _AggregatedBookReport _aggregateAndRankBooks({
    required String keyword,
    required Iterable<Book> books,
    required Map<String, int> sourceOrderById,
  }) {
    final normalizedKeyword = _normalizeAggregateText(keyword);
    final groupsByKey = <_BookAggregateKey, _BookAggregateGroup>{};

    for (final book in books) {
      final key = _BookAggregateKey(title: book.title, author: book.author);
      final group = groupsByKey.putIfAbsent(key, () => _BookAggregateGroup());

      final existing = group.hitsBySourceId[book.sourceId];
      if (existing == null) {
        group.hitsBySourceId[book.sourceId] = book;
      } else {
        final candidateScore = _bookQualityScore(
          book,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: sourceOrderById,
        );
        final existingScore = _bookQualityScore(
          existing,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: sourceOrderById,
        );
        if (candidateScore > existingScore) {
          group.hitsBySourceId[book.sourceId] = book;
        }
      }
      final tier = _resolveBookRelevanceTier(
        book,
        normalizedKeyword: normalizedKeyword,
      );
      if (tier > group.relevanceTier) {
        group.relevanceTier = tier;
      }
    }

    final aggregates = <_RankedAggregateBook>[];
    for (final group in groupsByKey.values) {
      final hits = group.hitsBySourceId.values.toList(growable: false);
      if (hits.isEmpty) {
        continue;
      }
      final sortedHits = hits.toList(growable: false)..sort((a, b) {
        final qualityDiff =
            _bookQualityScore(
              b,
              normalizedKeyword: normalizedKeyword,
              sourceOrderById: sourceOrderById,
            ) -
            _bookQualityScore(
              a,
              normalizedKeyword: normalizedKeyword,
              sourceOrderById: sourceOrderById,
            );
        if (qualityDiff != 0) {
          return qualityDiff;
        }
        final sourceOrderDiff = (sourceOrderById[a.sourceId] ?? 1 << 20)
            .compareTo(sourceOrderById[b.sourceId] ?? 1 << 20);
        if (sourceOrderDiff != 0) {
          return sourceOrderDiff;
        }
        return a.title.compareTo(b.title);
      });
      final primaryBook = sortedHits.first;
      aggregates.add(
        _RankedAggregateBook(
          primaryBook: primaryBook,
          hits: List.unmodifiable(sortedHits),
          relevanceTier: group.relevanceTier,
          primaryQualityScore: _bookQualityScore(
            primaryBook,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: sourceOrderById,
          ),
          primarySourceOrder: sourceOrderById[primaryBook.sourceId] ?? 1 << 20,
        ),
      );
    }

    aggregates.sort((a, b) {
      final tierDiff = b.relevanceTier.compareTo(a.relevanceTier);
      if (tierDiff != 0) {
        return tierDiff;
      }
      final hitCountDiff = b.hits.length.compareTo(a.hits.length);
      if (hitCountDiff != 0) {
        return hitCountDiff;
      }
      final qualityDiff = b.primaryQualityScore.compareTo(
        a.primaryQualityScore,
      );
      if (qualityDiff != 0) {
        return qualityDiff;
      }
      final sourceOrderDiff = a.primarySourceOrder.compareTo(
        b.primarySourceOrder,
      );
      if (sourceOrderDiff != 0) {
        return sourceOrderDiff;
      }
      return a.primaryBook.title.compareTo(b.primaryBook.title);
    });

    final booksOut = <Book>[];
    final hitCounts = <String, int>{};
    final hitsByPrimaryBookId = <String, List<Book>>{};
    for (final aggregate in aggregates) {
      booksOut.add(aggregate.primaryBook);
      hitCounts[aggregate.primaryBook.id] = aggregate.hits.length;
      hitsByPrimaryBookId[aggregate.primaryBook.id] = aggregate.hits;
    }

    return _AggregatedBookReport(
      books: List.unmodifiable(booksOut),
      hitCountsByPrimaryBookId: Map.unmodifiable(hitCounts),
      hitsByPrimaryBookId: Map.unmodifiable(hitsByPrimaryBookId),
    );
  }

  int _resolveBookRelevanceTier(
    Book book, {
    required String normalizedKeyword,
  }) {
    if (normalizedKeyword.isEmpty) {
      return 1;
    }
    final normalizedTitle = _normalizeAggregateText(book.title);
    final normalizedAuthor = _normalizeAggregateText(book.author ?? '');

    if (normalizedTitle == normalizedKeyword ||
        normalizedAuthor == normalizedKeyword) {
      return 3;
    }
    if (normalizedTitle.contains(normalizedKeyword) ||
        normalizedAuthor.contains(normalizedKeyword)) {
      return 2;
    }
    return 1;
  }

  int _bookQualityScore(
    Book book, {
    required String normalizedKeyword,
    required Map<String, int> sourceOrderById,
  }) {
    var score =
        _resolveBookRelevanceTier(book, normalizedKeyword: normalizedKeyword) *
        1000;
    if (book.coverUrl?.trim().isNotEmpty == true) {
      score += 40;
    }
    if (book.latestChapter?.trim().isNotEmpty == true) {
      score += 24;
    }
    if (book.intro?.trim().isNotEmpty == true) {
      score += 12;
    }
    final sourceOrder = sourceOrderById[book.sourceId] ?? 200;
    score += max(0, 200 - min(sourceOrder, 200));
    return score;
  }

  String _normalizeAggregateText(String raw) {
    var normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '';
    }
    normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[\u3000\s]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[《》〈〉【】\[\]()（）<>「」『』]'), '');
    return normalized.trim();
  }

  String _toUserReadableMessage(AppException error) {
    final stageText = _stageLabel(error.stage);
    final detail = _sanitizeDebugMessage(error.briefMessage);

    return switch (error.code) {
      ErrorCode.network => '$stageText网络请求失败，请检查书源地址或网络设置。',
      ErrorCode.validation => '$stageText脚本源配置不完整：$detail',
      ErrorCode.ruleParse => '$stageText脚本解析失败，请检查脚本语法。',
      ErrorCode.ruleMatchEmpty => '$stageText未匹配到有效结果，请尝试其他书源。',
      ErrorCode.decode => '$stageText响应解析失败，可能编码或格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown =>
        detail.isEmpty ? '$stageText发生未知错误，请稍后重试。' : '$stageText$detail',
    };
  }

  String _sanitizeDebugMessage(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.length <= 180) {
      return normalized;
    }
    return '${normalized.substring(0, 180)}...';
  }

  String _stageLabel(ErrorStage stage) {
    return switch (stage) {
      ErrorStage.search => '搜索阶段：',
      ErrorStage.detail => '详情阶段：',
      ErrorStage.toc => '目录阶段：',
      ErrorStage.content => '正文阶段：',
      ErrorStage.source => '书源阶段：',
      ErrorStage.reader => '阅读阶段：',
      ErrorStage.unknown => '未知阶段：',
    };
  }

  Future<void> _syncSearchDebugLoggingSetting() async {
    if (_searchDebugLoggingSettingLoaded) {
      return;
    }
    try {
      _searchDebugLoggingEnabled =
          await _searchSystemSettingsService.loadSearchDebugLogEnabled();
      _searchDebugLoggingSettingLoaded = true;
    } catch (_) {}
  }

  void _searchDebugInfo(
    String message, {
    Map<String, Object?> context = const {},
  }) {
    if (!_searchDebugLoggingEnabled) {
      return;
    }
    _logger.info(message, context: context);
  }
}

class _SearchTarget {
  const _SearchTarget.script(this.scriptSource);

  final RegisteredSource scriptSource;

  String get sourceId => scriptSource.runtime.id;

  String get sourceName => scriptSource.runtime.name;
}

class _BookAggregateGroup {
  final Map<String, Book> hitsBySourceId = <String, Book>{};
  int relevanceTier = 1;
}

class _BookAggregateKey {
  const _BookAggregateKey({required this.title, required this.author});

  final String title;
  final String? author;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _BookAggregateKey &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          author == other.author;

  @override
  int get hashCode => Object.hash(title, author);
}

class _RankedAggregateBook {
  const _RankedAggregateBook({
    required this.primaryBook,
    required this.hits,
    required this.relevanceTier,
    required this.primaryQualityScore,
    required this.primarySourceOrder,
  });

  final Book primaryBook;
  final List<Book> hits;
  final int relevanceTier;
  final int primaryQualityScore;
  final int primarySourceOrder;
}

class _AggregatedBookReport {
  const _AggregatedBookReport({
    required this.books,
    required this.hitCountsByPrimaryBookId,
    required this.hitsByPrimaryBookId,
  });

  final List<Book> books;
  final Map<String, int> hitCountsByPrimaryBookId;
  final Map<String, List<Book>> hitsByPrimaryBookId;
}

class _SourceSearchOutput {
  const _SourceSearchOutput({
    required this.requestUrl,
    required this.method,
    required this.statusCode,
    required this.books,
  });

  final String requestUrl;
  final HttpRequestMethod method;
  final int statusCode;
  final List<Book> books;
}

class _ProgressAggregationState {
  const _ProgressAggregationState({
    this.cachedAggregatedReport,
    this.lastAggregatedAt,
    this.lastProgressEmittedAt,
  });

  final SearchExecutionReport? cachedAggregatedReport;
  final DateTime? lastAggregatedAt;
  final DateTime? lastProgressEmittedAt;

  _ProgressAggregationState copyWith({
    SearchExecutionReport? cachedAggregatedReport,
    DateTime? lastAggregatedAt,
    DateTime? lastProgressEmittedAt,
  }) {
    return _ProgressAggregationState(
      cachedAggregatedReport:
          cachedAggregatedReport ?? this.cachedAggregatedReport,
      lastAggregatedAt: lastAggregatedAt ?? this.lastAggregatedAt,
      lastProgressEmittedAt:
          lastProgressEmittedAt ?? this.lastProgressEmittedAt,
    );
  }
}

class _AggregateAndRankInput {
  const _AggregateAndRankInput({
    required this.keyword,
    required this.books,
    required this.sourceOrderById,
  });

  final String keyword;
  final List<Book> books;
  final Map<String, int> sourceOrderById;
}

_AggregatedBookReport _aggregateAndRankBooksInIsolate(
  _AggregateAndRankInput input,
) {
  final normalizedKeyword = _normalizeAggregateTextForIsolate(input.keyword);
  final groupsByKey = <_BookAggregateKey, _BookAggregateGroup>{};

  for (final book in input.books) {
    final key = _BookAggregateKey(title: book.title, author: book.author);
    final group = groupsByKey.putIfAbsent(key, () => _BookAggregateGroup());

    final existing = group.hitsBySourceId[book.sourceId];
    if (existing == null) {
      group.hitsBySourceId[book.sourceId] = book;
    } else {
      final candidateScore = _bookQualityScoreForIsolate(
        book,
        normalizedKeyword: normalizedKeyword,
        sourceOrderById: input.sourceOrderById,
      );
      final existingScore = _bookQualityScoreForIsolate(
        existing,
        normalizedKeyword: normalizedKeyword,
        sourceOrderById: input.sourceOrderById,
      );
      if (candidateScore > existingScore) {
        group.hitsBySourceId[book.sourceId] = book;
      }
    }
    final tier = _resolveBookRelevanceTierForIsolate(
      book,
      normalizedKeyword: normalizedKeyword,
    );
    if (tier > group.relevanceTier) {
      group.relevanceTier = tier;
    }
  }

  final aggregates = <_RankedAggregateBook>[];
  for (final group in groupsByKey.values) {
    final hits = group.hitsBySourceId.values.toList(growable: false);
    if (hits.isEmpty) {
      continue;
    }
    final sortedHits = hits.toList(growable: false)..sort((a, b) {
      final qualityDiff =
          _bookQualityScoreForIsolate(
            b,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: input.sourceOrderById,
          ) -
          _bookQualityScoreForIsolate(
            a,
            normalizedKeyword: normalizedKeyword,
            sourceOrderById: input.sourceOrderById,
          );
      if (qualityDiff != 0) {
        return qualityDiff;
      }
      final sourceOrderDiff = (input.sourceOrderById[a.sourceId] ?? 1 << 20)
          .compareTo(input.sourceOrderById[b.sourceId] ?? 1 << 20);
      if (sourceOrderDiff != 0) {
        return sourceOrderDiff;
      }
      return a.title.compareTo(b.title);
    });
    final primaryBook = sortedHits.first;
    aggregates.add(
      _RankedAggregateBook(
        primaryBook: primaryBook,
        hits: List.unmodifiable(sortedHits),
        relevanceTier: group.relevanceTier,
        primaryQualityScore: _bookQualityScoreForIsolate(
          primaryBook,
          normalizedKeyword: normalizedKeyword,
          sourceOrderById: input.sourceOrderById,
        ),
        primarySourceOrder:
            input.sourceOrderById[primaryBook.sourceId] ?? 1 << 20,
      ),
    );
  }

  aggregates.sort((a, b) {
    final tierDiff = b.relevanceTier.compareTo(a.relevanceTier);
    if (tierDiff != 0) {
      return tierDiff;
    }
    final hitCountDiff = b.hits.length.compareTo(a.hits.length);
    if (hitCountDiff != 0) {
      return hitCountDiff;
    }
    final qualityDiff = b.primaryQualityScore.compareTo(a.primaryQualityScore);
    if (qualityDiff != 0) {
      return qualityDiff;
    }
    final sourceOrderDiff = a.primarySourceOrder.compareTo(
      b.primarySourceOrder,
    );
    if (sourceOrderDiff != 0) {
      return sourceOrderDiff;
    }
    return a.primaryBook.title.compareTo(b.primaryBook.title);
  });

  final booksOut = <Book>[];
  final hitCounts = <String, int>{};
  final hitsByPrimaryBookId = <String, List<Book>>{};
  for (final aggregate in aggregates) {
    booksOut.add(aggregate.primaryBook);
    hitCounts[aggregate.primaryBook.id] = aggregate.hits.length;
    hitsByPrimaryBookId[aggregate.primaryBook.id] = aggregate.hits;
  }

  return _AggregatedBookReport(
    books: List.unmodifiable(booksOut),
    hitCountsByPrimaryBookId: Map.unmodifiable(hitCounts),
    hitsByPrimaryBookId: Map.unmodifiable(hitsByPrimaryBookId),
  );
}

int _resolveBookRelevanceTierForIsolate(
  Book book, {
  required String normalizedKeyword,
}) {
  if (normalizedKeyword.isEmpty) {
    return 1;
  }
  final normalizedTitle = _normalizeAggregateTextForIsolate(book.title);
  final normalizedAuthor = _normalizeAggregateTextForIsolate(book.author ?? '');

  if (normalizedTitle == normalizedKeyword ||
      normalizedAuthor == normalizedKeyword) {
    return 3;
  }
  if (normalizedTitle.contains(normalizedKeyword) ||
      normalizedAuthor.contains(normalizedKeyword)) {
    return 2;
  }
  return 1;
}

int _bookQualityScoreForIsolate(
  Book book, {
  required String normalizedKeyword,
  required Map<String, int> sourceOrderById,
}) {
  var score =
      _resolveBookRelevanceTierForIsolate(
        book,
        normalizedKeyword: normalizedKeyword,
      ) *
      1000;
  if (book.coverUrl?.trim().isNotEmpty == true) {
    score += 40;
  }
  if (book.latestChapter?.trim().isNotEmpty == true) {
    score += 24;
  }
  if (book.intro?.trim().isNotEmpty == true) {
    score += 12;
  }
  final sourceOrder = sourceOrderById[book.sourceId] ?? 200;
  score += max(0, 200 - min(sourceOrder, 200));
  return score;
}

String _normalizeAggregateTextForIsolate(String raw) {
  var normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return '';
  }
  normalized = normalized.replaceAll(RegExp(r'<[^>]+>'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[\u3000\s]+'), ' ');
  normalized = normalized.replaceAll(RegExp(r'[《》〈〉【】\[\]()（）<>「」『』]'), '');
  return normalized.trim();
}
