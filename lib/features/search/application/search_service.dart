import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/request_context.dart';
import '../../../domain/entities/book.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../source/application/source_runtime_facade.dart';
import 'search_hit_cache_service.dart';
import 'search_system_settings_service.dart';

part 'search_planner.dart';
part 'script_source_search_runner.dart';
part 'search_report_assembler.dart';
part 'search_runtime_profile_service.dart';
part 'search_scheduler.dart';

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

enum SearchPlanScenario { globalSearch, switchSource, autoSwitchSource }

enum SearchExecutionProfile {
  httpLight,
  jsHeavy,
  browserCapable,
  browserHeavy,
}

enum SearchRuntimePlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  web,
  unknown,
}

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
    int? maxConcurrentSources,
    SearchRuntimePlatform? runtimePlatform,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _logger = logger ?? AppLogger.instance,
       _searchHitCacheService =
           searchHitCacheService ?? SearchHitCacheService(),
       _searchSystemSettingsService =
           searchSystemSettingsService ?? SearchSystemSettingsService(),
       _runtimePlatform = runtimePlatform ?? _inferRuntimePlatform(),
       _maxConcurrentSources = SearchService._resolveMaxConcurrentSources(
         maxConcurrentSources,
       ),
       _profileService = _SearchRuntimeProfileService() {
    _planner = _SearchPlanner(
      sourceRuntimeFacade: _sourceRuntimeFacade,
      profileService: _profileService,
    );
    _runner = _ScriptSourceSearchRunner(
      sourceRuntimeFacade: _sourceRuntimeFacade,
    );
    _assembler = _SearchReportAssembler(
      logger: _logger,
      searchHitCacheService: _searchHitCacheService,
      progressAggregationInterval: _progressAggregationInterval,
    );
    _scheduler = _SearchScheduler(
      maxBudgetCap: _maxConcurrentSources,
      runtimePlatform: _runtimePlatform,
    );
  }

  static int _resolveMaxConcurrentSources(int? maxConcurrentSources) {
    return (maxConcurrentSources ??
            SearchSystemSettingsService.defaultMaxConcurrentSources)
        .clamp(
          SearchSystemSettingsService.minMaxConcurrentSources,
          SearchSystemSettingsService.maxMaxConcurrentSources,
        );
  }

  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final AppLogger _logger;
  final SearchHitCacheService _searchHitCacheService;
  final SearchSystemSettingsService _searchSystemSettingsService;
  final SearchRuntimePlatform _runtimePlatform;
  final _SearchRuntimeProfileService _profileService;
  late final _SearchPlanner _planner;
  late final _ScriptSourceSearchRunner _runner;
  late final _SearchReportAssembler _assembler;
  late _SearchScheduler _scheduler;

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
    _scheduler = _SearchScheduler(
      maxBudgetCap: _maxConcurrentSources,
      runtimePlatform: _runtimePlatform,
    );
  }

  Future<SearchExecutionReport> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
    SearchContentMode contentMode = SearchContentMode.novel,
    SearchPlanScenario scenario = SearchPlanScenario.globalSearch,
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

    final sourceIdSet =
        sourceIds
            ?.map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    final plan = await _planner.buildPlan(
      contentMode: contentMode,
      scenario: scenario,
      sourceIds: sourceIdSet,
    );

    if (plan.sources.isEmpty) {
      if (plan.skippedSourceIds.isNotEmpty) {
        _logger.warn(
          'Search sources skipped by cooldown',
          context: <String, Object?>{
            'sourceIds': plan.skippedSourceIds,
            'scenario': scenario.name,
          },
        );
      }
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

    final budget = _scheduler.resolveBudget(scenario);

    _searchDebugInfo(
      'Search started',
      context: {
        'keyword': normalizedKeyword,
        'sourceCount': plan.targets.length,
        'page': page,
        'pageSize': pageSize,
        'budget': budget,
        'contentMode': contentMode.name,
        'scenario': scenario.name,
        'runtimePlatform': _runtimePlatform.name,
        'profileSummary': _profileSummaryToDebugMap(plan.profileSummary),
        'skippedCooldownSources': plan.skippedSourceIds,
        'selectedSourceCount': sourceIdSet?.length ?? 0,
      },
    );

    final booksById = <String, Book>{};
    final failures = <SourceSearchFailure>[];
    var successSourceCount = 0;
    var progressAggregationState = const _ProgressAggregationState();

    await _scheduler.run(
      plan: plan,
      scenario: scenario,
      cancellationToken: cancellationToken,
      onExecute: (source) async {
        final startAt = DateTime.now();

        try {
          final report = await _runner.run(
            source: source.scriptSource,
            keyword: normalizedKeyword,
            allowInteractiveChallenge: plan.allowInteractiveChallenge,
            cancellationToken: cancellationToken,
          );
          if (cancellationToken?.isCancelled ?? false) {
            return;
          }

          successSourceCount++;
          for (final book in report.books) {
            booksById[book.id] = book;
          }

          _searchDebugInfo(
            'Search source success',
            context: {
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
              'profile': source.profile.name,
              'bookCount': report.books.length,
              'requestUrl': report.requestUrl,
              'method': report.method.name,
              'statusCode': report.statusCode,
              'durationMs': DateTime.now().difference(startAt).inMilliseconds,
            },
          );
          _profileService.recordSuccess(sourceId: source.sourceId);
        } on AppException catch (error) {
          if (cancellationToken?.isCancelled ?? false) {
            return;
          }
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
              'profile': source.profile.name,
              'code': error.code.name,
              'stage': error.stage.name,
              'message': error.briefMessage,
              'requestUrl': error.requestUrl,
              'durationMs': DateTime.now().difference(startAt).inMilliseconds,
            },
          );
          _profileService.recordFailure(
            sourceId: source.sourceId,
            profile: source.profile,
            message: error.briefMessage,
            allowInteractiveChallenge: plan.allowInteractiveChallenge,
          );
        } catch (error, stackTrace) {
          if (cancellationToken?.isCancelled ?? false ||
              error is SessionTaskCancelledException) {
            return;
          }
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
              'profile': source.profile.name,
            },
          );
          _profileService.recordFailure(
            sourceId: source.sourceId,
            profile: source.profile,
            message: rawDetail,
            allowInteractiveChallenge: plan.allowInteractiveChallenge,
          );
        }

        progressAggregationState = await _emitProgress(
          keyword: normalizedKeyword,
          sourceCount: plan.targets.length,
          successSourceCount: successSourceCount,
          booksById: booksById,
          failures: failures,
          sourceNames: plan.sourceNames,
          sourceOrderById: plan.sourceOrderById,
          aggregateByTitleAuthor: aggregateByTitleAuthor,
          onProgress: onProgress,
          progressAggregationState: progressAggregationState,
        );
      },
    );

    final finalReport = await _assembler.buildExecutionReport(
      keyword: normalizedKeyword,
      sourceCount: plan.targets.length,
      successSourceCount: successSourceCount,
      booksById: booksById,
      failures: failures,
      sourceNames: plan.sourceNames,
      sourceOrderById: plan.sourceOrderById,
      aggregateByTitleAuthor: aggregateByTitleAuthor,
    );
    await _assembler.persistSearchHitCache(
      books: booksById.values,
      sourceNames: plan.sourceNames,
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

  Future<void> _syncMaxConcurrentSourcesSetting() async {
    try {
      final value =
          await _searchSystemSettingsService.loadMaxConcurrentSources();
      setMaxConcurrentSources(value);
    } catch (_) {}
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
      report = await _assembler.buildExecutionReport(
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

  String _toUserReadableMessage(AppException error) {
    final stageText = _stageLabel(error.stage);
    final detail = _sanitizeDebugMessage(error.briefMessage);

    return switch (error.code) {
      ErrorCode.network => '$stageText网络请求失败，请检查书源地址或网络设置。',
      ErrorCode.validation => '$stageText书源配置不完整：$detail',
      ErrorCode.ruleParse => '$stageText书源解析失败，请检查脚本语法。',
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

  Map<String, int> _profileSummaryToDebugMap(
    Map<SearchExecutionProfile, int> summary,
  ) {
    return <String, int>{
      for (final entry in summary.entries) entry.key.name: entry.value,
    };
  }

  static SearchRuntimePlatform _inferRuntimePlatform() {
    if (kIsWeb) {
      return SearchRuntimePlatform.web;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => SearchRuntimePlatform.android,
      TargetPlatform.iOS => SearchRuntimePlatform.ios,
      TargetPlatform.macOS => SearchRuntimePlatform.macos,
      TargetPlatform.windows => SearchRuntimePlatform.windows,
      TargetPlatform.linux => SearchRuntimePlatform.linux,
      _ => SearchRuntimePlatform.unknown,
    };
  }
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
