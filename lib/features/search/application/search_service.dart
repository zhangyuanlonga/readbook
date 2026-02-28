import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_context.dart';
import '../../../core/network/url_option.dart';
import '../../../core/rule_engine/executors/js_executor.dart';
import '../../../core/rule_engine/rule_engine.dart';
import '../../../core/rule_engine/processors/url_template_resolver.dart';
import '../../../core/rule_engine/processors/legacy_rule_compat.dart';
import '../../../core/rule_engine/processors/legacy_xpath_compat.dart';
import '../../../core/rule_engine/processors/legacy_rule_variable_processor.dart';
import '../../../core/rule_engine/processors/legacy_script_rule_fallback.dart';
import '../../../core/rule_engine/processors/source_js_variable_store.dart';
import '../../../core/source/source_response_processor.dart';
import '../../../core/webview/webview_executor.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book.dart';
import '../../../domain/entities/search_request_context.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import 'search_result_parser.dart';

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
  });

  final String keyword;
  final int sourceCount;
  final int successSourceCount;
  final List<Book> books;
  final List<SourceSearchFailure> failures;
  final Map<String, String> sourceNames;

  int get failedSourceCount => failures.length;
  int get processedSourceCount => successSourceCount + failedSourceCount;
}

typedef SearchProgressCallback = void Function(SearchExecutionReport report);

enum SearchContentMode { novel, manga }

class SearchCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class SourceConnectivityTestReport {
  const SourceConnectivityTestReport({
    required this.sourceId,
    required this.sourceName,
    required this.keyword,
    required this.method,
    required this.matchedBookCount,
    this.requestUrl,
    this.statusCode,
    this.error,
    this.probeOnly = false,
  });

  final String sourceId;
  final String sourceName;
  final String keyword;
  final HttpRequestMethod method;
  final int matchedBookCount;
  final String? requestUrl;
  final int? statusCode;
  final AppException? error;
  final bool probeOnly;

  bool get isSuccess => error == null;
}

class SingleSourceSearchResult {
  const SingleSourceSearchResult({
    required this.sourceId,
    required this.sourceName,
    required this.keyword,
    required this.requestUrl,
    required this.method,
    required this.statusCode,
    required this.books,
  });

  final String sourceId;
  final String sourceName;
  final String keyword;
  final String requestUrl;
  final HttpRequestMethod method;
  final int statusCode;
  final List<Book> books;
}

class SearchService {
  SearchService({
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    WebViewExecutor? webViewExecutor,
    UrlTemplateResolver? urlTemplateResolver,
    SearchResultParser? parser,
    RuleEngine? ruleEngine,
    AppLogger? logger,
    SourceResponseProcessor? responseProcessor,
    int maxConcurrentSources = 4,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _webViewExecutor = webViewExecutor ?? WebViewExecutor(),
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver(),
       _parser = parser ?? SearchResultParser(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _logger = logger ?? AppLogger.instance,
       _responseProcessor =
           responseProcessor ?? const SourceResponseProcessor(),
       _maxConcurrentSources = max(1, maxConcurrentSources);

  final int _maxConcurrentSources;

  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final WebViewExecutor _webViewExecutor;
  final UrlTemplateResolver _urlTemplateResolver;
  final SearchResultParser _parser;
  final RuleEngine _ruleEngine;
  final AppLogger _logger;
  final SourceResponseProcessor _responseProcessor;

  Future<SearchExecutionReport> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
    SearchContentMode contentMode = SearchContentMode.novel,
    List<String>? sourceIds,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: '搜索关键词不能为空。',
      );
    }

    final allSources = await _sourceRepository.getAll();
    var enabledSources = allSources
        .where(
          (source) =>
              source.enabled && _matchesContentMode(source, contentMode),
        )
        .toList(growable: false);

    final sourceIdSet =
        sourceIds
            ?.map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    if (sourceIdSet != null && sourceIdSet.isNotEmpty) {
      enabledSources = enabledSources
          .where((source) => sourceIdSet.contains(source.id))
          .toList(growable: false);
    }

    if (enabledSources.isEmpty) {
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

    final concurrency = min(_maxConcurrentSources, enabledSources.length);

    _logger.info(
      'Search started',
      context: {
        'keyword': normalizedKeyword,
        'sourceCount': enabledSources.length,
        'page': page,
        'pageSize': pageSize,
        'concurrency': concurrency,
        'contentMode': contentMode.name,
        'selectedSourceCount': sourceIdSet?.length ?? 0,
      },
    );

    final sourceNames = <String, String>{
      for (final source in enabledSources) source.id: source.name,
    };

    final booksById = <String, Book>{};
    final failures = <SourceSearchFailure>[];
    var successSourceCount = 0;

    final pendingSources = Queue<SourceDefinition>.from(enabledSources);
    final workerCount = min(concurrency, pendingSources.length);

    Future<void> worker() async {
      while (true) {
        if (cancellationToken?.isCancelled ?? false) {
          return;
        }

        if (pendingSources.isEmpty) {
          return;
        }

        final source = pendingSources.removeFirst();
        final startAt = DateTime.now();

        try {
          final report = await _searchSingleSource(
            source: source,
            context: SearchRequestContext(
              keyword: normalizedKeyword,
              page: page,
              pageSize: pageSize,
              sourceId: source.id,
            ),
          );

          successSourceCount++;
          for (final book in report.books) {
            booksById[book.id] = book;
          }

          _logger.info(
            'Search source success',
            context: {
              'sourceId': source.id,
              'sourceName': source.name,
              'bookCount': report.books.length,
              'requestUrl': report.requestUrl,
              'method': report.method.name,
              'statusCode': report.statusCode,
              'durationMs': DateTime.now().difference(startAt).inMilliseconds,
            },
          );
        } on AppException catch (error) {
          final failure = SourceSearchFailure(
            sourceId: source.id,
            sourceName: source.name,
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
              'sourceId': source.id,
              'sourceName': source.name,
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
            sourceId: source.id,
            briefMessage: rawDetail.isEmpty ? '搜索失败：${source.name}' : rawDetail,
            cause: error,
            stackTrace: stackTrace,
          );
          failures.add(
            SourceSearchFailure(
              sourceId: source.id,
              sourceName: source.name,
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
            context: {'sourceId': source.id, 'sourceName': source.name},
          );
        }

        _emitProgress(
          keyword: normalizedKeyword,
          sourceCount: enabledSources.length,
          successSourceCount: successSourceCount,
          booksById: booksById,
          failures: failures,
          sourceNames: sourceNames,
          onProgress: onProgress,
        );
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));

    final finalReport = _buildExecutionReport(
      keyword: normalizedKeyword,
      sourceCount: enabledSources.length,
      successSourceCount: successSourceCount,
      booksById: booksById,
      failures: failures,
      sourceNames: sourceNames,
    );

    if (cancellationToken?.isCancelled ?? false) {
      _logger.info(
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

    _logger.info(
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

  SearchExecutionReport _buildExecutionReport({
    required String keyword,
    required int sourceCount,
    required int successSourceCount,
    required Map<String, Book> booksById,
    required List<SourceSearchFailure> failures,
    required Map<String, String> sourceNames,
  }) {
    return SearchExecutionReport(
      keyword: keyword,
      sourceCount: sourceCount,
      successSourceCount: successSourceCount,
      books: booksById.values.toList(growable: false),
      failures: List.unmodifiable(failures),
      sourceNames: Map.unmodifiable(sourceNames),
    );
  }

  void _emitProgress({
    required String keyword,
    required int sourceCount,
    required int successSourceCount,
    required Map<String, Book> booksById,
    required List<SourceSearchFailure> failures,
    required Map<String, String> sourceNames,
    required SearchProgressCallback? onProgress,
  }) {
    if (onProgress == null) {
      return;
    }

    try {
      onProgress(
        _buildExecutionReport(
          keyword: keyword,
          sourceCount: sourceCount,
          successSourceCount: successSourceCount,
          booksById: booksById,
          failures: failures,
          sourceNames: sourceNames,
        ),
      );
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
    }
  }

  AppException? validateSearchConfig({
    required SourceDefinition source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '测试关键词不能为空。',
      );
    }

    final rawSearchRule = source.rules.searchRule?.trim();
    if (rawSearchRule == null || rawSearchRule.isEmpty) {
      return AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '书源缺少 searchUrl/ruleSearchUrl。',
      );
    }

    try {
      final context = SearchRequestContext(
        keyword: normalizedKeyword,
        page: page,
        pageSize: pageSize,
        sourceId: source.id,
      );

      final requestSpec = _parseRequestSpec(
        rawSearchRule,
        sourceBaseUrl: source.baseUrl,
      );
      _urlTemplateResolver.resolve(
        template: requestSpec.urlTemplate,
        context: context,
        baseUrl: source.baseUrl,
      );
      _buildParseRules(source);

      return null;
    } on AppException catch (error) {
      return error;
    } catch (error, stackTrace) {
      return AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '搜索规则静态校验失败：$error',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<SourceConnectivityTestReport> testSingleSource({
    required SourceDefinition source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool validateRules = true,
    bool skipInit = false,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '测试关键词不能为空。',
      );
    }

    final startAt = DateTime.now();

    try {
      final output = await _searchSingleSource(
        source: source,
        context: SearchRequestContext(
          keyword: normalizedKeyword,
          page: page,
          pageSize: pageSize,
          sourceId: source.id,
        ),
        validateRules: validateRules,
        skipInit: skipInit,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
      );

      final probeOnly = !validateRules;
      final successSummary =
          probeOnly ? '连通性测试通过，网络可达。' : '连通性测试通过，命中 ${output.books.length} 条。';

      await _persistSourceHealth(
        source,
        SourceHealthStatus.healthy,
        summary: successSummary,
      );

      _logger.info(
        'Source connectivity test success',
        context: {
          'sourceId': source.id,
          'sourceName': source.name,
          'keyword': normalizedKeyword,
          'requestUrl': output.requestUrl,
          'statusCode': output.statusCode,
          'method': output.method.name,
          'matchCount': output.books.length,
          'probeOnly': probeOnly,
          'durationMs': DateTime.now().difference(startAt).inMilliseconds,
        },
      );

      return SourceConnectivityTestReport(
        sourceId: source.id,
        sourceName: source.name,
        keyword: normalizedKeyword,
        requestUrl: output.requestUrl,
        method: output.method,
        statusCode: output.statusCode,
        matchedBookCount: output.books.length,
        probeOnly: probeOnly,
      );
    } on AppException catch (error) {
      await _persistSourceHealth(
        source,
        _toHealthStatus(error),
        summary: _toUserReadableMessage(error),
      );

      _logger.warn(
        'Source connectivity test failed',
        context: {
          'sourceId': source.id,
          'sourceName': source.name,
          'keyword': normalizedKeyword,
          'code': error.code.name,
          'stage': error.stage.name,
          'message': error.briefMessage,
          'requestUrl': error.requestUrl,
          'durationMs': DateTime.now().difference(startAt).inMilliseconds,
        },
      );

      return SourceConnectivityTestReport(
        sourceId: source.id,
        sourceName: source.name,
        keyword: normalizedKeyword,
        requestUrl: error.requestUrl,
        method: HttpRequestMethod.get,
        matchedBookCount: 0,
        error: error,
        probeOnly: !validateRules,
      );
    } catch (error, stackTrace) {
      final exception = AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '连通性测试失败：${source.name}',
        cause: error,
        stackTrace: stackTrace,
      );

      await _persistSourceHealth(
        source,
        SourceHealthStatus.unavailable,
        summary: _toUserReadableMessage(exception),
      );

      _logger.error(
        'Source connectivity test crashed',
        exception: exception,
        context: {'sourceId': source.id, 'sourceName': source.name},
      );

      return SourceConnectivityTestReport(
        sourceId: source.id,
        sourceName: source.name,
        keyword: normalizedKeyword,
        requestUrl: exception.requestUrl,
        method: HttpRequestMethod.get,
        matchedBookCount: 0,
        error: exception,
        probeOnly: !validateRules,
      );
    }
  }

  Future<SingleSourceSearchResult> searchSingleSource({
    required SourceDefinition source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool validateRules = true,
    bool skipInit = false,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '搜索关键词不能为空。',
      );
    }

    final output = await _searchSingleSource(
      source: source,
      context: SearchRequestContext(
        keyword: normalizedKeyword,
        page: page,
        pageSize: pageSize,
        sourceId: source.id,
      ),
      validateRules: validateRules,
      skipInit: skipInit,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
    );

    return SingleSourceSearchResult(
      sourceId: source.id,
      sourceName: source.name,
      keyword: normalizedKeyword,
      requestUrl: output.requestUrl,
      method: output.method,
      statusCode: output.statusCode,
      books: output.books,
    );
  }

  Future<_SourceSearchOutput> _searchSingleSource({
    required SourceDefinition source,
    required SearchRequestContext context,
    bool validateRules = true,
    bool skipInit = false,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final rawSearchRule = source.rules.searchRule?.trim();
    if (rawSearchRule == null || rawSearchRule.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '书源缺少 searchUrl/ruleSearchUrl。',
      );
    }

    final sourceVariableUpdates = <String, String>{};
    final runtimeJsVariables = <String, String>{
      ...SourceJsVariableStore.load(source),
    };

    void collectPutVariables(Map<String, String> variables) {
      if (variables.isEmpty) {
        return;
      }
      sourceVariableUpdates.addAll(variables);
      runtimeJsVariables.addAll(
        SourceJsVariableStore.toRuntimeVariables(variables),
      );
    }

    try {
      final initJsContext = _buildSourceJsContext(
        source: source,
        runtimeContext: context,
        seedVariables: runtimeJsVariables,
        onBridgePutVariables: collectPutVariables,
      );

      final runtimeContext =
          skipInit
              ? context
              : await _buildRuntimeContext(
                source: source,
                context: context,
                initRule: source.rules.searchInitRule,
                jsContext: initJsContext,
              );

      final requestSpec = _parseRequestSpec(
        rawSearchRule,
        sourceBaseUrl: source.baseUrl,
      );

      final requestUrl = _urlTemplateResolver.resolve(
        template: requestSpec.urlTemplate,
        context: runtimeContext,
        baseUrl: source.baseUrl,
      );

      final contentType = _resolveContentType(requestSpec);
      final requestBody = _resolveBodyTemplate(
        requestSpec.bodyTemplate,
        context: runtimeContext,
        encodeKeywordByDefault: _shouldEncodeKeywordInBody(
          bodyTemplate: requestSpec.bodyTemplate,
          contentType: contentType,
        ),
      );

      final requestHeaders = _resolveRequestHeaders(
        sourceHeaders: source.headers,
        requestHeaders: requestSpec.headers,
        context: runtimeContext,
      );

      _logger.info(
        'Search source request',
        context: {
          'sourceId': source.id,
          'sourceName': source.name,
          'method': requestSpec.method.name,
          'requestUrl': requestUrl,
          if (requestBody != null) 'requestBody': requestBody,
        },
      );

      final response = await _executeRequest(
        source: source,
        stage: ErrorStage.search,
        requestSpec: requestSpec,
        requestUrl: requestUrl,
        requestBody: requestBody,
        contentType: contentType,
        requestHeaders: requestHeaders,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
      );

      final processedResponse = _responseProcessor.process(
        body: response.body,
        requestUrl: requestUrl,
      );

      final parseRules = validateRules ? _buildParseRules(source) : null;
      final parseJsContext = _buildSourceJsContext(
        source: source,
        runtimeContext: runtimeContext,
        seedVariables: runtimeJsVariables,
        onBridgePutVariables: collectPutVariables,
      );

      final books =
          validateRules
              ? await _parseSearchBooks(
                source: source,
                responseBody: processedResponse.body,
                rules: parseRules!,
                jsContext: parseJsContext,
              )
              : const <Book>[];

      return _SourceSearchOutput(
        requestUrl: requestUrl,
        method: requestSpec.method,
        statusCode: response.statusCode,
        books: books,
      );
    } finally {
      await _persistSourceJsVariables(
        source: source,
        variables: sourceVariableUpdates,
        stage: ErrorStage.search,
      );
    }
  }

  Future<List<Book>> _parseSearchBooks({
    required SourceDefinition source,
    required String responseBody,
    required SearchParseRules rules,
    required JsExecutionContext jsContext,
  }) {
    return _parser.parse(
      htmlContent: responseBody,
      sourceId: source.id,
      baseUrl: source.baseUrl,
      rules: rules,
      jsContext: jsContext,
    );
  }

  Future<_NetworkLoadResult> _executeRequest({
    required SourceDefinition source,
    required ErrorStage stage,
    required _SearchRequestSpec requestSpec,
    required String requestUrl,
    required Object? requestBody,
    required String? contentType,
    required Map<String, String> requestHeaders,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    if (requestSpec.useWebView) {
      try {
        final webViewResponse = await _webViewExecutor.load(
          request: WebViewRequestPayload(
            url: requestUrl,
            method: requestSpec.method,
            headers: requestHeaders,
            body: requestBody,
            contentType: contentType,
            webJs: requestSpec.webJs,
            sourceRegex: requestSpec.sourceRegex,
            stage: stage,
            sourceId: source.id,
          ),
        );
        final matchedResourceUrl =
            webViewResponse.matchedResourceUrl?.trim() ?? '';
        final shouldUseMatchedResourceUrl =
            requestSpec.sourceRegex != null &&
            requestSpec.sourceRegex!.trim().isNotEmpty &&
            matchedResourceUrl.isNotEmpty;
        return _NetworkLoadResult(
          statusCode: webViewResponse.statusCode,
          body:
              shouldUseMatchedResourceUrl
                  ? matchedResourceUrl
                  : webViewResponse.body,
        );
      } catch (error) {
        _logger.warn(
          'WebView request failed and fallback to HTTP',
          context: <String, Object?>{
            'sourceId': source.id,
            'stage': stage.name,
            'url': requestUrl,
            'briefMessage': error.toString(),
            'diagnostic': 'webview_fallback_http',
          },
        );
      }
    }

    final response = await _httpClient.get(
      RequestContext(
        url: requestUrl,
        method: requestSpec.method,
        body: requestBody,
        contentType: contentType,
        responseCharset: requestSpec.responseCharset,
        headers: requestHeaders,
        maxRetries: requestSpec.maxRetries,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        stage: stage,
        sourceId: source.id,
        sourceConcurrentRate: source.concurrentRate,
      ),
    );
    return _NetworkLoadResult(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  Future<SearchRequestContext> _buildRuntimeContext({
    required SourceDefinition source,
    required SearchRequestContext context,
    required String? initRule,
    JsExecutionContext? jsContext,
  }) async {
    final initVariables = await _loadInitVariables(
      source: source,
      stage: ErrorStage.search,
      initRule: initRule,
      context: context,
      jsContext: jsContext,
    );

    if (initVariables.isEmpty) {
      return context;
    }

    return context.copyWith(
      extraParams: {...context.extraParams, ...initVariables},
    );
  }

  Future<void> _persistSourceJsVariables({
    required SourceDefinition source,
    required Map<String, String> variables,
    required ErrorStage stage,
  }) async {
    if (variables.isEmpty) {
      return;
    }

    final nextSource = SourceJsVariableStore.merge(
      source: source,
      updates: variables,
    );
    try {
      await _sourceRepository.upsertAll([nextSource]);
    } catch (error) {
      _logger.warn(
        'Persist source js variables failed',
        context: <String, Object?>{
          'sourceId': source.id,
          'sourceName': source.name,
          'stage': stage.name,
          'error': error.toString(),
        },
      );
    }
  }

  Future<void> _persistSourceHealth(
    SourceDefinition source,
    SourceHealthStatus status, {
    String? summary,
  }) async {
    try {
      await _sourceRepository.upsertAll([
        source.copyWith(
          lastCheckStatus: status,
          lastCheckedAt: DateTime.now(),
          lastCheckMessage: summary,
          clearLastCheckMessage: summary == null || summary.trim().isEmpty,
        ),
      ]);
    } catch (error) {
      _logger.warn(
        'Persist source health failed',
        context: {
          'sourceId': source.id,
          'sourceName': source.name,
          'status': status.name,
          'error': error.toString(),
        },
      );
    }
  }

  SourceHealthStatus _toHealthStatus(AppException error) {
    return switch (error.code) {
      ErrorCode.network => SourceHealthStatus.unavailable,
      ErrorCode.ruleParse ||
      ErrorCode.ruleMatchEmpty ||
      ErrorCode.decode ||
      ErrorCode.validation => SourceHealthStatus.degraded,
      ErrorCode.unknownSource ||
      ErrorCode.unknown => SourceHealthStatus.unavailable,
    };
  }

  SearchParseRules _buildParseRules(SourceDefinition source) {
    final listRuleRaw = _normalizeListRuleReversePrefix(
      source.rules.searchListRule,
    );
    final preferCurrentNodeChunk =
        _isBareCurrentNodeExtractorRule(source.rules.searchTitleRule) ||
        _isBareCurrentNodeExtractorRule(source.rules.searchDetailUrlRule);

    var listRule = _normalizeRuleExpression(
      listRuleRaw.rule,
      fallbackExtractor: preferCurrentNodeChunk ? 'outerhtml' : 'html',
    );
    if (preferCurrentNodeChunk) {
      listRule = _upgradeListRuleToOuterHtml(listRule);
    }
    listRule = _appendListRuleOuterHtmlFallback(listRule);
    listRule ??= _buildVariableExpressionFallback(listRuleRaw.rule);
    listRule ??= _buildScriptFallbackExpression(listRuleRaw.rule, list: true);

    final listRuleIsJson = listRule?.startsWith('json:') ?? false;
    final fieldPreferJson = listRuleIsJson;

    var titleRule = _normalizeRuleExpression(
      source.rules.searchTitleRule,
      fallbackExtractor: 'text',
      preferJsonShorthand: fieldPreferJson,
    );
    titleRule ??= _buildVariableExpressionFallback(
      source.rules.searchTitleRule,
    );
    titleRule ??= _buildScriptFallbackExpression(source.rules.searchTitleRule);

    var detailUrlRule = _normalizeRuleExpression(
      source.rules.searchDetailUrlRule,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
      preferJsonShorthand: fieldPreferJson,
    );
    detailUrlRule ??= _buildVariableExpressionFallback(
      source.rules.searchDetailUrlRule,
    );
    detailUrlRule ??= _buildScriptFallbackExpression(
      source.rules.searchDetailUrlRule,
    );

    if (listRule == null || titleRule == null || detailUrlRule == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        sourceId: source.id,
        briefMessage: '书源缺少搜索解析规则（列表/标题/详情链接）。',
      );
    }

    return SearchParseRules(
      listRule: listRule,
      listReversed: listRuleRaw.reversed,
      titleRule: titleRule,
      detailUrlRule: detailUrlRule,
      rawListRule: source.rules.searchListRule,
      rawTitleRule: source.rules.searchTitleRule,
      rawDetailUrlRule: source.rules.searchDetailUrlRule,
      authorRule: _normalizeRuleExpression(
        source.rules.searchAuthorRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
      rawAuthorRule: source.rules.searchAuthorRule,
      introRule: _normalizeRuleExpression(
        source.rules.searchIntroRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
      rawIntroRule: source.rules.searchIntroRule,
      coverUrlRule: _normalizeRuleExpression(
        source.rules.searchCoverUrlRule,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
        preferJsonShorthand: fieldPreferJson,
      ),
      rawCoverUrlRule: source.rules.searchCoverUrlRule,
      latestChapterRule: _normalizeRuleExpression(
        source.rules.searchLatestChapterRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
      rawLatestChapterRule: source.rules.searchLatestChapterRule,
    );
  }

  _ListRuleNormalization _normalizeListRuleReversePrefix(String? rawRule) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return const _ListRuleNormalization();
    }
    if (!text.startsWith('-')) {
      return _ListRuleNormalization(rule: text);
    }

    final normalized = text.substring(1).trim();
    return _ListRuleNormalization(
      rule: normalized.isEmpty ? null : normalized,
      reversed: true,
    );
  }

  String? _buildScriptFallbackExpression(String? rawRule, {bool list = false}) {
    if (!LegacyScriptRuleFallback.isScriptOnlyRule(rawRule)) {
      return null;
    }

    return list
        ? LegacyScriptRuleFallback.listExpression
        : LegacyScriptRuleFallback.fieldExpression;
  }

  String? _buildVariableExpressionFallback(String? rawRule) {
    if (!LegacyRuleVariableProcessor.containsVariableSyntax(rawRule)) {
      return null;
    }

    final value = rawRule?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  bool _isBareCurrentNodeExtractorRule(String? rawRule) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    if (text.startsWith('html:') ||
        text.startsWith('json:') ||
        text.startsWith('regex:') ||
        text.startsWith(r'$') ||
        text.contains('||') ||
        text.contains('&&') ||
        text.contains('@')) {
      return false;
    }

    final token = text.split('##').first.trim().toLowerCase();
    return token == 'text' ||
        token == 'textnodes' ||
        token == 'href' ||
        token == 'url' ||
        token == 'src' ||
        token == 'title' ||
        token == 'alt' ||
        token == 'name';
  }

  String? _upgradeListRuleToOuterHtml(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return text;
    }

    final upgraded = text
        .split('||')
        .map((item) {
          final candidate = item.trim();
          if (!candidate.startsWith('html:') || !candidate.endsWith('@html')) {
            return candidate;
          }
          return '${candidate.substring(0, candidate.length - 5)}@outerhtml';
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (upgraded.isEmpty) {
      return null;
    }

    return upgraded.join('||');
  }

  String? _appendListRuleOuterHtmlFallback(String? expression) {
    final text = expression?.trim();
    if (text == null || text.isEmpty) {
      return text;
    }

    final base = text
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (base.isEmpty) {
      return null;
    }

    final appended = <String>[...base];
    for (final candidate in base) {
      if (!candidate.startsWith('html:') || !candidate.endsWith('@html')) {
        continue;
      }
      final outer = '${candidate.substring(0, candidate.length - 5)}@outerhtml';
      if (!appended.contains(outer)) {
        appended.add(outer);
      }
    }

    return appended.join('||');
  }

  Future<Map<String, String>> _loadInitVariables({
    required SourceDefinition source,
    required ErrorStage stage,
    required String? initRule,
    required SearchRequestContext context,
    JsExecutionContext? jsContext,
  }) async {
    final rawInitRule = initRule?.trim();
    if (rawInitRule == null || rawInitRule.isEmpty) {
      return const {};
    }

    final initParts = _splitInitRuleParts(rawInitRule);
    if (initParts.requestRule == null || initParts.requestRule!.isEmpty) {
      return const {};
    }

    final requestSpec = _parseRequestSpec(
      initParts.requestRule!,
      sourceBaseUrl: source.baseUrl,
    );
    final requestUrl = _urlTemplateResolver.resolve(
      template: requestSpec.urlTemplate,
      context: context,
      baseUrl: source.baseUrl,
    );

    final contentType = _resolveContentType(requestSpec);
    final requestBody = _resolveBodyTemplate(
      requestSpec.bodyTemplate,
      context: context,
      encodeKeywordByDefault: _shouldEncodeKeywordInBody(
        bodyTemplate: requestSpec.bodyTemplate,
        contentType: contentType,
      ),
    );

    final requestHeaders = _resolveRequestHeaders(
      sourceHeaders: source.headers,
      requestHeaders: requestSpec.headers,
      context: context,
    );

    _logger.info(
      'Init request',
      context: {
        'sourceId': source.id,
        'sourceName': source.name,
        'stage': stage.name,
        'requestUrl': requestUrl,
      },
    );

    final response = await _executeRequest(
      source: source,
      stage: stage,
      requestSpec: requestSpec,
      requestUrl: requestUrl,
      requestBody: requestBody,
      contentType: contentType,
      requestHeaders: requestHeaders,
    );

    final normalizedInitBody =
        _responseProcessor
            .process(body: response.body, requestUrl: requestUrl)
            .body;

    final jsonVariables = () {
      final decoded = _tryDecodeJson(normalizedInitBody);
      if (decoded == null) {
        return const <String, String>{};
      }
      return _flattenInitVariables(decoded);
    }();

    final putVariables = await _extractInitPutVariables(
      content: normalizedInitBody,
      stage: stage,
      parseRule: initParts.parseRule,
      context: context,
      jsContext: jsContext,
    );

    if (jsonVariables.isEmpty && putVariables.isEmpty) {
      return const {};
    }

    return {...jsonVariables, ...putVariables};
  }

  _InitRuleParts _splitInitRuleParts(String rawInitRule) {
    final normalized = rawInitRule.trim();
    if (normalized.isEmpty) {
      return const _InitRuleParts();
    }

    final putIndex = normalized.indexOf('@put:');
    if (putIndex > 0) {
      final request = normalized.substring(0, putIndex).trim();
      final parse = normalized.substring(putIndex).trim();
      if (_looksLikeRequestRule(request)) {
        return _InitRuleParts(
          requestRule: request,
          parseRule: parse.isEmpty ? null : parse,
        );
      }
    }

    if (_looksLikeRequestRule(normalized)) {
      return _InitRuleParts(requestRule: normalized);
    }

    return _InitRuleParts(parseRule: normalized);
  }

  Future<Map<String, String>> _extractInitPutVariables({
    required String content,
    required ErrorStage stage,
    required String? parseRule,
    required SearchRequestContext context,
    JsExecutionContext? jsContext,
  }) async {
    if (!LegacyRuleVariableProcessor.containsVariableSyntax(parseRule)) {
      return const {};
    }

    final working = <String, String>{...context.toVariables()};
    final baseline = Map<String, String>.from(working);

    await LegacyRuleVariableProcessor.resolveExpressionAsync(
      expression: parseRule!.trim(),
      variables: working,
      resolvePutValue:
          (valueExpression) => _evaluateInitPutValue(
            content: content,
            stage: stage,
            valueExpression: valueExpression,
            jsContext: _mergeJsContextVariables(jsContext, working),
          ),
    );

    final output = <String, String>{};
    for (final entry in working.entries) {
      if (baseline[entry.key] == entry.value) {
        continue;
      }
      if (entry.value.trim().isEmpty) {
        continue;
      }
      output[entry.key] = entry.value;
    }

    return output;
  }

  Future<String?> _evaluateInitPutValue({
    required String content,
    required ErrorStage stage,
    required String valueExpression,
    JsExecutionContext? jsContext,
  }) async {
    final text = valueExpression.trim();
    if (text.isEmpty) {
      return null;
    }

    final normalizedRule = _normalizeRuleExpression(
      text,
      fallbackExtractor: 'text',
    );

    if (normalizedRule != null) {
      for (final candidate in _splitFallbackExpressions(normalizedRule)) {
        try {
          final value = await _ruleEngine.executeFirst(
            content: content,
            expression: candidate,
            stage: stage,
            jsContext: jsContext,
          );
          final normalized = value.trim();
          if (normalized.isNotEmpty) {
            return normalized;
          }
        } on AppException {
          continue;
        }
      }
    }

    if (_looksLikeRuleExpression(text)) {
      return null;
    }

    return text;
  }

  JsExecutionContext _buildSourceJsContext({
    required SourceDefinition source,
    required SearchRequestContext runtimeContext,
    Map<String, String> seedVariables = const <String, String>{},
    JsBridgePutCallback? onBridgePutVariables,
  }) {
    final variables = <String, String>{
      ...seedVariables,
      ...runtimeContext.extraParams,
    };

    void collectPutVariables(Map<String, String> updates) {
      if (updates.isEmpty) {
        return;
      }
      variables.addAll(SourceJsVariableStore.toRuntimeVariables(updates));
      onBridgePutVariables?.call(updates);
    }

    return JsExecutionContext(
      sourceId: source.id,
      baseUrl: source.baseUrl,
      variables: variables,
      sourceJson: _buildSourceJsJson(source),
      jsLibScript: source.jsLib,
      onBridgePutVariables: collectPutVariables,
    );
  }

  JsExecutionContext? _mergeJsContextVariables(
    JsExecutionContext? jsContext,
    Map<String, String>? variables,
  ) {
    if (jsContext == null || variables == null || variables.isEmpty) {
      return jsContext;
    }

    return jsContext.copyWith(
      variables: <String, String>{...jsContext.variables, ...variables},
    );
  }

  Map<String, dynamic> _buildSourceJsJson(SourceDefinition source) {
    final payload = <String, dynamic>{...?source.originalSource};
    payload.putIfAbsent('id', () => source.id);
    payload.putIfAbsent('name', () => source.name);
    payload.putIfAbsent('bookSourceName', () => source.name);
    payload.putIfAbsent('baseUrl', () => source.baseUrl);
    payload.putIfAbsent('bookSourceUrl', () => source.baseUrl);
    payload.putIfAbsent('sourceType', () => source.sourceType);
    payload.putIfAbsent('enabled', () => source.enabled);
    return payload;
  }

  bool _looksLikeRuleExpression(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      return false;
    }

    if (text.startsWith('html:') ||
        text.startsWith('json:') ||
        text.startsWith('regex:') ||
        text.startsWith('xpath:') ||
        text.startsWith('@xpath:') ||
        text.startsWith('js:') ||
        text.startsWith('@js:') ||
        text.startsWith(r'$.') ||
        text.startsWith(r'$[') ||
        text.startsWith('//')) {
      return true;
    }

    if (LegacyRuleCompat.looksLikeAllInOneRegexExpression(text) ||
        LegacyRuleCompat.looksLikeRegexGroupReference(text)) {
      return true;
    }

    return text.contains('@') ||
        text.contains('##') ||
        text.contains('||') ||
        text.contains('&&') ||
        text.contains('%%') ||
        text.contains('{{@@') ||
        text.contains('{{@css:') ||
        text.contains('{{@json:') ||
        text.contains('{{@xpath:') ||
        text.contains('{{@js:');
  }

  List<String> _splitFallbackExpressions(String expression) {
    return expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  dynamic _tryDecodeJson(String source) {
    try {
      return jsonDecode(source);
    } on FormatException {
      return null;
    }
  }

  Map<String, String> _flattenInitVariables(dynamic source) {
    final result = <String, String>{};

    void walk(dynamic value, String path) {
      if (value == null) {
        return;
      }

      if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString();
          if (key.isEmpty) {
            continue;
          }

          final nextPath = path.isEmpty ? key : '$path.$key';
          walk(entry.value, nextPath);
        }
        return;
      }

      if (value is List) {
        for (var index = 0; index < value.length; index += 1) {
          walk(value[index], '$path[$index]');
        }
        return;
      }

      final text = value.toString();
      if (text.trim().isEmpty) {
        return;
      }

      if (path.isNotEmpty) {
        result[path] = text;
        result['\$.$path'] = text;
      }
    }

    walk(source, '');
    return result;
  }

  bool _matchesContentMode(SourceDefinition source, SearchContentMode mode) {
    return switch (mode) {
      SearchContentMode.novel => !source.isMangaSource,
      SearchContentMode.manga => source.isMangaSource,
    };
  }

  String _toUserReadableMessage(AppException error) {
    final stageText = _stageLabel(error.stage);
    final detail = _sanitizeDebugMessage(error.briefMessage);

    return switch (error.code) {
      ErrorCode.network => '$stageText网络请求失败，请检查书源地址或网络设置。',
      ErrorCode.validation => '$stageText规则配置不完整：$detail',
      ErrorCode.ruleParse => '$stageText规则解析失败，请检查规则语法。',
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

  _SearchRequestSpec _parseRequestSpec(
    String rawRule, {
    String? sourceBaseUrl,
  }) {
    final normalized = rawRule.trim();

    final legacyScriptSpec = _tryParseLegacyScriptRequestSpec(
      normalized,
      sourceBaseUrl: sourceBaseUrl,
    );
    if (legacyScriptSpec != null) {
      return legacyScriptSpec;
    }

    final splitResult = _splitRequestOptions(normalized);
    if (splitResult == null) {
      final urlTemplate = _normalizeLegacyUrlTemplate(normalized);
      _ensureResolvedRequestUrlTemplate(urlTemplate);
      return _SearchRequestSpec(
        urlTemplate: urlTemplate,
        method: HttpRequestMethod.get,
        maxRetries: 1,
      );
    }

    final options = _decodeOptionsMap(splitResult.optionsText);
    final option = UrlOption.fromMap(options);
    var urlTemplate = _normalizeLegacyUrlTemplate(splitResult.urlTemplate);
    if (_looksLikeUnresolvedDynamicRequestTemplate(urlTemplate) &&
        _isUsableBaseUrl(sourceBaseUrl) &&
        options.isNotEmpty) {
      urlTemplate = sourceBaseUrl!.trim();
    }
    _ensureResolvedRequestUrlTemplate(urlTemplate);

    return _SearchRequestSpec(
      urlTemplate: urlTemplate,
      method: option.method,
      bodyTemplate: _normalizeBodyTemplate(option.body),
      contentType: option.contentType,
      responseCharset: option.responseCharset,
      headers: option.headers,
      maxRetries: option.retry ?? 1,
      useWebView: option.webView,
      webJs: option.webJs,
      sourceRegex: option.sourceRegex,
    );
  }

  _SearchRequestSpec? _tryParseLegacyScriptRequestSpec(
    String rawRule, {
    String? sourceBaseUrl,
  }) {
    if (!_looksLikeLegacyScriptRule(rawRule)) {
      return null;
    }

    final script = _stripLegacyScriptWrapper(rawRule);
    if (script.isEmpty) {
      return null;
    }

    final variables = _collectLegacyScriptStringVariables(script);
    var legacyUrl =
        _extractLegacyJsUrlTemplate(script, variables) ??
        _extractLegacyUrlTemplate(script);

    final options = _extractLegacyJsOptionsMap(script, variables);
    if ((legacyUrl == null || legacyUrl.trim().isEmpty) &&
        _isUsableBaseUrl(sourceBaseUrl) &&
        options.isNotEmpty) {
      legacyUrl = sourceBaseUrl!.trim();
    }

    if (legacyUrl == null || legacyUrl.trim().isEmpty) {
      return null;
    }

    final option = UrlOption.fromMap(options);

    var urlTemplate = _normalizeLegacyUrlTemplate(legacyUrl);
    if (_looksLikeUnresolvedDynamicRequestTemplate(urlTemplate) &&
        _isUsableBaseUrl(sourceBaseUrl) &&
        options.isNotEmpty) {
      urlTemplate = sourceBaseUrl!.trim();
    }

    _ensureResolvedRequestUrlTemplate(urlTemplate);

    return _SearchRequestSpec(
      urlTemplate: urlTemplate,
      method: option.method,
      bodyTemplate: _normalizeBodyTemplate(option.body),
      contentType: option.contentType,
      responseCharset: option.responseCharset,
      headers: option.headers,
      maxRetries: option.retry ?? 1,
      useWebView: option.webView,
      webJs: option.webJs,
      sourceRegex: option.sourceRegex,
    );
  }

  bool _looksLikeLegacyScriptRule(String rule) {
    final normalized = rule.trim();
    if (normalized.isEmpty) {
      return false;
    }

    return normalized.startsWith('@js:') ||
        normalized.startsWith('<js>') ||
        normalized.contains('@js:') ||
        normalized.contains('<js>') ||
        normalized.contains('JSON.stringify(') ||
        normalized.contains('java.put(') ||
        normalized.contains(r'${');
  }

  void _ensureResolvedRequestUrlTemplate(String template) {
    final normalized = template.trim();
    if (normalized.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'searchUrl 解析失败：URL 为空。',
      );
    }

    if (_looksLikeUnresolvedDynamicRequestTemplate(normalized)) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.search,
        briefMessage: 'searchUrl 为动态 JS 脚本，当前无法静态解析，请改为固定 URL 或模板规则。',
      );
    }
  }

  bool _isUsableBaseUrl(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  bool _looksLikeUnresolvedDynamicRequestTemplate(String template) {
    final normalized = template.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final lower = normalized.toLowerCase();
    return lower.startsWith('@js:') ||
        lower.startsWith('<js>') ||
        lower.contains('\n@js:') ||
        lower.contains('\r@js:') ||
        lower.contains('org.jsoup') ||
        lower.contains('java.ajax(') ||
        lower.contains('java.connect(') ||
        lower.contains('eval(') ||
        lower.contains('source.key') ||
        lower.contains('source.getkey()');
  }

  String _stripLegacyScriptWrapper(String rawRule) {
    var script = rawRule.trim();
    if (script.startsWith('@js:')) {
      script = script.substring(4).trim();
    }

    if (script.toLowerCase().startsWith('<js>')) {
      script = script.substring(4).trim();
    }
    if (script.toLowerCase().endsWith('</js>')) {
      script = script.substring(0, script.length - 5).trim();
    }

    return script;
  }

  Map<String, String> _collectLegacyScriptStringVariables(String script) {
    final statements = script
        .split(RegExp(r'[;\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final variables = <String, String>{};

    for (var pass = 0; pass < 3; pass += 1) {
      var changed = false;
      for (final statement in statements) {
        final match = RegExp(
          r'^(?:var\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$',
        ).firstMatch(statement);
        if (match == null) {
          continue;
        }

        final name = match.group(1)!;
        final expression = match.group(2)!.trim();
        final resolved = _evaluateLegacyConcatExpression(expression, variables);
        if (resolved == null) {
          continue;
        }

        if (variables[name] != resolved) {
          variables[name] = resolved;
          changed = true;
        }
      }

      if (!changed) {
        break;
      }
    }

    return variables;
  }

  String? _extractLegacyJsUrlTemplate(
    String script,
    Map<String, String> variables,
  ) {
    final stringifyIndex = script.indexOf('JSON.stringify(');
    if (stringifyIndex < 0) {
      return null;
    }

    final statementBoundaryCandidates = <int>[
      script.lastIndexOf(';', stringifyIndex),
      script.lastIndexOf('\n', stringifyIndex),
      script.lastIndexOf('\r', stringifyIndex),
    ];
    final statementStart = statementBoundaryCandidates.reduce(max) + 1;

    var prefix = script.substring(statementStart, stringifyIndex).trim();
    if (prefix.isEmpty) {
      return null;
    }

    final assignIndex = _findTopLevelAssignmentIndex(prefix);
    if (assignIndex >= 0) {
      prefix = prefix.substring(assignIndex + 1).trim();
    }

    while (prefix.endsWith('+')) {
      prefix = prefix.substring(0, prefix.length - 1).trimRight();
    }

    final resolved = _evaluateLegacyConcatExpression(prefix, variables);
    if (resolved == null || resolved.trim().isEmpty) {
      return null;
    }

    return _normalizeLegacyUrlTemplate(resolved);
  }

  int _findTopLevelAssignmentIndex(String expression) {
    var depthParen = 0;
    var depthBrace = 0;
    var depthBracket = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = 0; index < expression.length; index += 1) {
      final char = expression[index];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        continue;
      }
      if (char == '{') {
        depthBrace += 1;
        continue;
      }
      if (char == '}' && depthBrace > 0) {
        depthBrace -= 1;
        continue;
      }
      if (char == '[') {
        depthBracket += 1;
        continue;
      }
      if (char == ']' && depthBracket > 0) {
        depthBracket -= 1;
        continue;
      }

      if (depthParen == 0 &&
          depthBrace == 0 &&
          depthBracket == 0 &&
          char == '=') {
        final previous = index > 0 ? expression[index - 1] : '';
        final next = index + 1 < expression.length ? expression[index + 1] : '';
        if (previous != '=' && previous != '!' && next != '=') {
          return index;
        }
      }
    }

    return -1;
  }

  Map<String, dynamic> _extractLegacyJsOptionsMap(
    String script,
    Map<String, String> variables,
  ) {
    final argument = _extractJsonStringifyArgument(script);
    if (argument == null || argument.trim().isEmpty) {
      return const {};
    }

    final objectText = _resolveLegacyObjectExpression(argument, script);
    if (objectText == null || objectText.trim().isEmpty) {
      return const {};
    }

    return _parseLegacyObjectLiteralToMap(objectText, variables);
  }

  String? _extractJsonStringifyArgument(String script) {
    final callIndex = script.indexOf('JSON.stringify(');
    if (callIndex < 0) {
      return null;
    }

    final openIndex = script.indexOf('(', callIndex);
    if (openIndex < 0) {
      return null;
    }

    final closeIndex = _findMatchingBracket(
      script,
      openIndex,
      openChar: '(',
      closeChar: ')',
    );
    if (closeIndex <= openIndex + 1) {
      return null;
    }

    return script.substring(openIndex + 1, closeIndex).trim();
  }

  String? _resolveLegacyObjectExpression(String rawArg, String script) {
    final argument = rawArg.trim();
    if (argument.isEmpty) {
      return null;
    }

    if (argument.startsWith('{')) {
      return argument;
    }

    final variableMatch = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*$',
    ).firstMatch(argument);
    if (variableMatch == null) {
      return null;
    }

    return _extractAssignedObjectLiteral(script, argument);
  }

  String? _extractAssignedObjectLiteral(String script, String variableName) {
    final assignPattern = RegExp(
      '(?:var\\s+)?${RegExp.escape(variableName)}\\s*=\\s*',
      multiLine: true,
    );
    final match = assignPattern.firstMatch(script);
    if (match == null) {
      return null;
    }

    var openIndex = match.end;
    while (openIndex < script.length &&
        RegExp(r'\s').hasMatch(script[openIndex])) {
      openIndex += 1;
    }

    if (openIndex >= script.length || script[openIndex] != '{') {
      return null;
    }

    final closeIndex = _findMatchingBracket(
      script,
      openIndex,
      openChar: '{',
      closeChar: '}',
    );
    if (closeIndex <= openIndex) {
      return null;
    }

    return script.substring(openIndex, closeIndex + 1);
  }

  Map<String, dynamic> _parseLegacyObjectLiteralToMap(
    String objectText,
    Map<String, String> variables,
  ) {
    final text = objectText.trim();
    if (!text.startsWith('{') || !text.endsWith('}')) {
      return const {};
    }

    final body = text.substring(1, text.length - 1);
    final entries = _splitTopLevelByComma(body);
    final result = <String, dynamic>{};

    for (final rawEntry in entries) {
      final entry = rawEntry.trim();
      if (entry.isEmpty) {
        continue;
      }

      final colonIndex = _findTopLevelColon(entry);
      if (colonIndex <= 0 || colonIndex >= entry.length - 1) {
        continue;
      }

      final rawKey = entry.substring(0, colonIndex).trim();
      final key = _normalizeLegacyObjectKey(rawKey);
      if (key.isEmpty) {
        continue;
      }

      final valueExpression = entry.substring(colonIndex + 1).trim();
      if (valueExpression.isEmpty) {
        continue;
      }

      switch (key) {
        case 'method':
        case 'contentType':
        case 'content-type':
        case 'charset':
        case 'responseCharset':
        case 'response-charset':
          final value = _evaluateLegacyScriptValue(valueExpression, variables);
          if (value is String && value.trim().isNotEmpty) {
            result[key] = value.trim();
          }
          break;
        case 'body':
          final value = _evaluateLegacyScriptValue(valueExpression, variables);
          if (value != null) {
            result[key] = value;
          }
          break;
        case 'headers':
        case 'header':
          final resolved = _evaluateLegacyScriptValue(
            valueExpression,
            variables,
          );
          if (resolved is Map<String, String> && resolved.isNotEmpty) {
            result[key] = resolved;
          }
          break;
        case 'webView':
        case 'webview':
          final resolved = _evaluateLegacyScriptValue(
            valueExpression,
            variables,
          );
          final parsed = _asNullableBool(resolved);
          if (parsed != null) {
            result[key] = parsed;
          }
          break;
        case 'js':
        case 'webJs':
        case 'webjs':
        case 'sourceRegex':
        case 'source_regex':
          final resolved = _evaluateLegacyScriptValue(
            valueExpression,
            variables,
          );
          final text = _asNullableString(resolved);
          if (text != null) {
            result[key] = text;
          }
          break;
        case 'retry':
          final resolved = _evaluateLegacyScriptValue(
            valueExpression,
            variables,
          );
          final parsed =
              int.tryParse((resolved ?? '').toString().trim()) ??
              int.tryParse(valueExpression.trim());
          if (parsed != null && parsed >= 0) {
            result[key] = parsed;
          }
          break;
      }
    }

    return result;
  }

  List<String> _splitTopLevelByComma(String text) {
    if (text.trim().isEmpty) {
      return const [];
    }

    final items = <String>[];
    var buffer = StringBuffer();
    var depthParen = 0;
    var depthBrace = 0;
    var depthBracket = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = 0; index < text.length; index += 1) {
      final char = text[index];

      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        buffer.write(char);
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '{') {
        depthBrace += 1;
        buffer.write(char);
        continue;
      }
      if (char == '}' && depthBrace > 0) {
        depthBrace -= 1;
        buffer.write(char);
        continue;
      }
      if (char == '[') {
        depthBracket += 1;
        buffer.write(char);
        continue;
      }
      if (char == ']' && depthBracket > 0) {
        depthBracket -= 1;
        buffer.write(char);
        continue;
      }

      if (char == ',' &&
          depthParen == 0 &&
          depthBrace == 0 &&
          depthBracket == 0) {
        items.add(buffer.toString());
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    items.add(buffer.toString());
    return items;
  }

  int _findTopLevelColon(String entry) {
    var depthParen = 0;
    var depthBrace = 0;
    var depthBracket = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = 0; index < entry.length; index += 1) {
      final char = entry[index];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        continue;
      }
      if (char == '{') {
        depthBrace += 1;
        continue;
      }
      if (char == '}' && depthBrace > 0) {
        depthBrace -= 1;
        continue;
      }
      if (char == '[') {
        depthBracket += 1;
        continue;
      }
      if (char == ']' && depthBracket > 0) {
        depthBracket -= 1;
        continue;
      }

      if (char == ':' &&
          depthParen == 0 &&
          depthBrace == 0 &&
          depthBracket == 0) {
        return index;
      }
    }

    return -1;
  }

  String _normalizeLegacyObjectKey(String rawKey) {
    final quoted = _unquoteLegacyString(rawKey);
    if (quoted != null) {
      return quoted.trim();
    }
    return rawKey.trim();
  }

  dynamic _evaluateLegacyScriptValue(
    String expression,
    Map<String, String> variables,
  ) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.startsWith('{') && text.endsWith('}')) {
      final headerMap = _parseLegacyHeaderObject(text, variables);
      if (headerMap.isNotEmpty) {
        return headerMap;
      }
    }

    final asString = _evaluateLegacyConcatExpression(text, variables);
    if (asString != null) {
      return asString;
    }

    if (text.startsWith('{') || text.startsWith('[')) {
      final decoded = _decodeOptionsMap(_normalizePseudoJson(text));
      if (decoded.isNotEmpty) {
        return decoded;
      }
    }

    final unquoted = _unquoteLegacyString(text);
    if (unquoted != null) {
      return unquoted;
    }

    return null;
  }

  Map<String, String> _parseLegacyHeaderObject(
    String objectText,
    Map<String, String> variables,
  ) {
    final text = objectText.trim();
    if (!text.startsWith('{') || !text.endsWith('}')) {
      return const {};
    }

    final body = text.substring(1, text.length - 1);
    final entries = _splitTopLevelByComma(body);
    final headers = <String, String>{};

    for (final rawEntry in entries) {
      final entry = rawEntry.trim();
      if (entry.isEmpty) {
        continue;
      }

      final colonIndex = _findTopLevelColon(entry);
      if (colonIndex <= 0 || colonIndex >= entry.length - 1) {
        continue;
      }

      final key = _normalizeLegacyObjectKey(entry.substring(0, colonIndex));
      if (key.isEmpty) {
        continue;
      }

      final value = _evaluateLegacyScriptValue(
        entry.substring(colonIndex + 1),
        variables,
      );
      final normalized = value?.toString().trim();
      if (normalized != null && normalized.isNotEmpty) {
        headers[key] = normalized;
      }
    }

    return headers;
  }

  String? _evaluateLegacyConcatExpression(
    String expression,
    Map<String, String> variables,
  ) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    final tokens = _splitLegacyConcatTokens(text);
    if (tokens.isEmpty) {
      return null;
    }

    final resolved = <String>[];
    for (final token in tokens) {
      final value = _evaluateLegacyAtomToken(token, variables);
      if (value == null) {
        return null;
      }
      resolved.add(value);
    }

    return resolved.join();
  }

  List<String> _splitLegacyConcatTokens(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      return const [];
    }

    final tokens = <String>[];
    var buffer = StringBuffer();
    var depthParen = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = 0; index < text.length; index += 1) {
      final char = text[index];

      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        buffer.write(char);
        continue;
      }

      if (char == '(') {
        depthParen += 1;
        buffer.write(char);
        continue;
      }
      if (char == ')' && depthParen > 0) {
        depthParen -= 1;
        buffer.write(char);
        continue;
      }

      if (char == '+' && depthParen == 0) {
        final token = buffer.toString().trim();
        if (token.isNotEmpty) {
          tokens.add(token);
        }
        buffer = StringBuffer();
        continue;
      }

      buffer.write(char);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      tokens.add(tail);
    }

    return tokens;
  }

  String? _evaluateLegacyAtomToken(
    String token,
    Map<String, String> variables,
  ) {
    var text = token.trim();
    if (text.isEmpty) {
      return '';
    }

    if (text.endsWith(',')) {
      text = text.substring(0, text.length - 1).trimRight();
    }

    final quoted = _unquoteLegacyString(text);
    if (quoted != null) {
      return quoted;
    }

    if (text.startsWith('String(') && text.endsWith(')')) {
      final inner = text.substring(7, text.length - 1).trim();
      return _evaluateLegacyAtomToken(inner, variables) ?? variables[inner];
    }

    if (text == 'source.getKey()' || text == 'source.key') {
      return '';
    }

    if (text == 'baseUrl') {
      return '';
    }

    if (text == 'key' || text == 'keyword' || text == 'page') {
      return '{{$text}}';
    }

    final variableValue = variables[text];
    if (variableValue != null) {
      return variableValue;
    }

    final wrapped =
        text.startsWith('(') && text.endsWith(')')
            ? text.substring(1, text.length - 1).trim()
            : null;
    if (wrapped != null && wrapped.isNotEmpty && wrapped != text) {
      return _evaluateLegacyAtomToken(wrapped, variables);
    }

    return null;
  }

  String? _unquoteLegacyString(String token) {
    final text = token.trim();
    if (text.length < 2) {
      return null;
    }

    final quote = text[0];
    final isQuoted =
        (quote == '"' || quote == "'" || quote == '`') && text.endsWith(quote);
    if (!isQuoted) {
      return null;
    }

    final value = text.substring(1, text.length - 1);
    return _normalizeLegacyJsTemplateExpressions(value);
  }

  String _normalizeLegacyJsTemplateExpressions(String value) {
    return value.replaceAllMapped(RegExp(r'\$\{([^\}]+)\}'), (match) {
      final expression = match.group(1)?.trim() ?? '';
      final normalized = _normalizeLegacyTemplateTokenExpression(expression);
      if (normalized == null || normalized.isEmpty) {
        return '';
      }
      return '{{$normalized}}';
    });
  }

  String? _normalizeLegacyTemplateTokenExpression(String expression) {
    final normalized = expression.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    final lower = compact.toLowerCase();

    if (lower == 'java.encodeuri(key)' ||
        lower == 'encodeuri(key)' ||
        lower == 'java.encodeuricomponent(key)' ||
        lower == 'encodeuricomponent(key)') {
      return 'key|encode';
    }

    if (lower == 'java.encodeuri(keyword)' ||
        lower == 'encodeuri(keyword)' ||
        lower == 'java.encodeuricomponent(keyword)' ||
        lower == 'encodeuricomponent(keyword)') {
      return 'keyword|encode';
    }

    final parseIntMatch = RegExp(
      r'^parseint\((page(?:[+-]\d+)?)\)$',
      caseSensitive: false,
    ).firstMatch(lower);
    if (parseIntMatch != null) {
      return parseIntMatch.group(1);
    }

    return compact;
  }

  int _findMatchingBracket(
    String source,
    int openIndex, {
    required String openChar,
    required String closeChar,
  }) {
    if (openIndex < 0 || openIndex >= source.length) {
      return -1;
    }

    var depth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = openIndex; index < source.length; index += 1) {
      final char = source[index];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'" || char == '`') {
        inString = true;
        quote = char;
        continue;
      }

      if (char == openChar) {
        depth += 1;
        continue;
      }

      if (char == closeChar) {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }

    return -1;
  }

  _RequestRuleSplit? _splitRequestOptions(String normalizedRule) {
    final objectStart = _findTrailingObjectStart(normalizedRule);
    if (objectStart == null || objectStart <= 0) {
      return null;
    }

    var commaIndex = objectStart - 1;
    while (commaIndex >= 0 &&
        RegExp(r'\s').hasMatch(normalizedRule[commaIndex])) {
      commaIndex -= 1;
    }

    if (commaIndex < 0 || normalizedRule[commaIndex] != ',') {
      return null;
    }

    final urlTemplate = normalizedRule.substring(0, commaIndex).trim();
    if (urlTemplate.isEmpty) {
      return null;
    }

    final optionsText = normalizedRule.substring(objectStart).trim();
    if (optionsText.isEmpty) {
      return null;
    }

    return _RequestRuleSplit(
      urlTemplate: urlTemplate,
      optionsText: optionsText,
    );
  }

  int? _findTrailingObjectStart(String value) {
    var end = value.length - 1;
    while (end >= 0 && RegExp(r'\s').hasMatch(value[end])) {
      end -= 1;
    }
    if (end < 0 || value[end] != '}') {
      return null;
    }

    var depth = 0;
    var inString = false;
    var quote = '';
    var escaped = false;

    for (var index = end; index >= 0; index -= 1) {
      final char = value[index];

      if (inString) {
        if (escaped) {
          escaped = false;
          continue;
        }
        if (char == r'\') {
          escaped = true;
          continue;
        }
        if (char == quote) {
          inString = false;
          quote = '';
        }
        continue;
      }

      if (char == '"' || char == "'") {
        inString = true;
        quote = char;
        continue;
      }

      if (char == '}') {
        depth += 1;
        continue;
      }

      if (char == '{') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }

    return null;
  }

  String _normalizeLegacyUrlTemplate(String template) {
    final preprocessed = _stripLegacySideEffectPrelude(template);
    final seed = preprocessed.trim().isEmpty ? template : preprocessed;
    final normalized = _normalizeLegacyJsTemplateExpressions(seed.trim());
    if (normalized.isEmpty) {
      return normalized;
    }

    final trimmedRaw =
        normalized.endsWith(',')
            ? normalized.substring(0, normalized.length - 1).trimRight()
            : normalized;

    if (_looksLikeRequestUrlTemplate(trimmedRaw) &&
        !_containsLegacyScriptSignals(trimmedRaw)) {
      return trimmedRaw;
    }

    final extracted = _extractLegacyUrlTemplate(trimmedRaw);
    if (extracted == null || extracted.isEmpty) {
      return trimmedRaw;
    }

    return _normalizeLegacyJsTemplateExpressions(extracted);
  }

  String _stripLegacySideEffectPrelude(String template) {
    var remaining = template.trim();
    var changed = false;

    while (remaining.startsWith('{{')) {
      final closeIndex = _findClosingTemplateToken(remaining, 0);
      if (closeIndex < 0) {
        break;
      }

      final block = remaining.substring(2, closeIndex).trim();
      if (!_looksLikeLegacySideEffectTemplate(block)) {
        break;
      }

      remaining = remaining.substring(closeIndex + 2).trimLeft();
      changed = true;
    }

    final jsPrefix = RegExp(
      r'^<js>[\s\S]*?</js>',
      caseSensitive: false,
      dotAll: true,
    );
    if (jsPrefix.hasMatch(remaining)) {
      remaining = remaining.replaceFirst(jsPrefix, '').trimLeft();
      changed = true;
    }

    return changed ? remaining : template.trim();
  }

  int _findClosingTemplateToken(String source, int startIndex) {
    final open = source.indexOf('{{', startIndex);
    if (open < 0) {
      return -1;
    }

    return source.indexOf('}}', open + 2);
  }

  bool _looksLikeLegacySideEffectTemplate(String block) {
    final normalized = block.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('http://') || lower.contains('https://')) {
      return false;
    }

    if (RegExp(r'''["'`]\s*/[^"'`]+''').hasMatch(normalized)) {
      return false;
    }

    if (lower.contains('source.getkey()') ||
        lower.contains('source.key') ||
        lower.contains('source.getvariable()') ||
        lower.contains('cookie.') ||
        lower.contains('java.') ||
        lower.contains('org.jsoup') ||
        lower.contains('eval(') ||
        lower.contains('url=')) {
      return true;
    }

    return normalized.contains(';');
  }

  bool _looksLikeRequestUrlTemplate(String template) {
    return template.startsWith('http://') ||
        template.startsWith('https://') ||
        template.startsWith('/') ||
        _looksLikeSearchEndpoint(template);
  }

  bool _looksLikeRequestRule(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return false;
    }

    if (_splitRequestOptions(text) != null) {
      return true;
    }

    if (text.startsWith('//')) {
      return false;
    }

    return text.startsWith('http://') ||
        text.startsWith('https://') ||
        text.startsWith('/') ||
        _looksLikeSearchEndpoint(text);
  }

  bool _containsLegacyScriptSignals(String template) {
    final normalized = template.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final lower = normalized.toLowerCase();
    return lower.contains('@js:') ||
        lower.contains('<js>') ||
        lower.contains('</js>') ||
        lower.contains('java.') ||
        lower.contains('org.jsoup') ||
        lower.contains('eval(') ||
        normalized.contains('\n') ||
        normalized.contains('\r');
  }

  String? _extractLegacyUrlTemplate(String template) {
    String? pickHttp(String source) {
      final direct = RegExp(r'''https?://[^\s"'`<>()]+''').firstMatch(source);
      if (direct == null) {
        return null;
      }

      return _sanitizeLegacyExtractedUrl(direct.group(0));
    }

    String? pickRelative(String source) {
      final direct = RegExp(
        r'''/(?:[^\s"'`<>()]|\{\{[^\}]+\}\})+''',
      ).firstMatch(source);
      if (direct == null) {
        return null;
      }

      return _sanitizeLegacyExtractedUrl(direct.group(0));
    }

    final javaPutMatch = RegExp(
      r'''java\.put\([^,]+,\s*[`"']([^`"']+)[`"']\s*\)''',
      caseSensitive: false,
    ).firstMatch(template);
    if (javaPutMatch != null) {
      final captured = javaPutMatch.group(1)?.trim();
      if (captured != null && captured.isNotEmpty) {
        return _normalizeLegacyJsTemplateExpressions(captured);
      }
    }

    final lines = template
        .split(RegExp(r'[\r\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    for (final line in lines) {
      final normalizedLine =
          line
              .replaceAll('"', ' ')
              .replaceAll("'", ' ')
              .replaceAll('`', ' ')
              .trim();

      final http = pickHttp(normalizedLine);
      if (http != null) {
        return http;
      }

      final relative = pickRelative(normalizedLine);
      if (relative != null && _looksLikeSearchEndpoint(relative)) {
        return relative;
      }

      final loose = _extractLooseRelativeSearchEndpoint(normalizedLine);
      if (loose != null) {
        return loose;
      }
    }

    final fromTemplate = pickHttp(template);
    if (fromTemplate != null) {
      return fromTemplate;
    }

    final relative = pickRelative(template);
    if (relative != null && _looksLikeSearchEndpoint(relative)) {
      return relative;
    }

    return _extractLooseRelativeSearchEndpoint(template);
  }

  String? _sanitizeLegacyExtractedUrl(String? value) {
    var normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    while (normalized.endsWith(')') ||
        normalized.endsWith(';') ||
        normalized.endsWith(',')) {
      normalized = normalized.substring(0, normalized.length - 1).trimRight();
    }

    return normalized.isEmpty
        ? null
        : _normalizeLegacyJsTemplateExpressions(normalized);
  }

  String? _extractLooseRelativeSearchEndpoint(String source) {
    final direct = RegExp(
      r'''(?:^|[\s=+])([A-Za-z0-9_\-/]+\.(?:php|asp|aspx|html)(?:\?[^\s"'`<>()]*)?)''',
      caseSensitive: false,
    ).firstMatch(source);
    if (direct == null) {
      return null;
    }

    final candidate = _sanitizeLegacyExtractedUrl(direct.group(1));
    if (candidate == null || !_looksLikeSearchEndpoint(candidate)) {
      return null;
    }

    return candidate;
  }

  bool _looksLikeSearchEndpoint(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    if (normalized.contains('search') ||
        normalized.contains('query') ||
        normalized.contains('find') ||
        normalized.contains('keyword=') ||
        normalized.contains('searchkey=') ||
        normalized.contains('wd=') ||
        normalized.contains('q=')) {
      return true;
    }

    return normalized.endsWith('.php') ||
        normalized.endsWith('.asp') ||
        normalized.endsWith('.aspx') ||
        normalized.endsWith('.html');
  }

  Map<String, String> _resolveRequestHeaders({
    required Map<String, String> sourceHeaders,
    required Map<String, String> requestHeaders,
    required SearchRequestContext context,
  }) {
    final merged = <String, String>{...sourceHeaders, ...requestHeaders};

    if (merged.isEmpty) {
      return const {};
    }

    final resolved = <String, String>{};
    for (final entry in merged.entries) {
      final resolvedValue = _urlTemplateResolver.resolve(
        template: entry.value,
        context: context,
        encodeKeywordByDefault: false,
      );
      resolved[entry.key] = resolvedValue;
    }

    return resolved;
  }

  Object? _resolveBodyTemplate(
    Object? bodyTemplate, {
    required SearchRequestContext context,
    required bool encodeKeywordByDefault,
  }) {
    if (bodyTemplate == null) {
      return null;
    }

    if (bodyTemplate is String) {
      return _urlTemplateResolver.resolve(
        template: bodyTemplate,
        context: context,
        encodeKeywordByDefault: encodeKeywordByDefault,
      );
    }

    if (bodyTemplate is Map) {
      return bodyTemplate.map(
        (key, value) => MapEntry(
          key.toString(),
          _resolveBodyTemplate(
            value,
            context: context,
            encodeKeywordByDefault: encodeKeywordByDefault,
          ),
        ),
      );
    }

    if (bodyTemplate is List) {
      return bodyTemplate
          .map(
            (item) => _resolveBodyTemplate(
              item,
              context: context,
              encodeKeywordByDefault: encodeKeywordByDefault,
            ),
          )
          .toList(growable: false);
    }

    return bodyTemplate;
  }

  String? _resolveContentType(_SearchRequestSpec requestSpec) {
    final contentType = requestSpec.contentType?.trim();
    if (contentType != null && contentType.isNotEmpty) {
      return contentType;
    }

    if (requestSpec.method != HttpRequestMethod.post ||
        requestSpec.bodyTemplate == null) {
      return null;
    }

    if (requestSpec.bodyTemplate is Map || requestSpec.bodyTemplate is List) {
      return 'application/json';
    }

    return 'application/x-www-form-urlencoded';
  }

  bool _shouldEncodeKeywordInBody({
    required Object? bodyTemplate,
    required String? contentType,
  }) {
    if (bodyTemplate == null) {
      return false;
    }

    if (bodyTemplate is Map || bodyTemplate is List) {
      return false;
    }

    final normalizedType = contentType?.toLowerCase() ?? '';
    if (normalizedType.isEmpty ||
        normalizedType.contains('x-www-form-urlencoded')) {
      return true;
    }

    return false;
  }

  Object? _normalizeBodyTemplate(Object? value) {
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) {
        return null;
      }
      return text;
    }
    return value;
  }

  Map<String, dynamic> _decodeOptionsMap(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      // fall through
    }

    final normalized = _normalizePseudoJson(source);
    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } on FormatException {
      return const {};
    }

    return const {};
  }

  String _normalizePseudoJson(String source) {
    return source.replaceAllMapped(RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"), (
      match,
    ) {
      final inner = match.group(1) ?? '';
      final escaped = inner
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"')
          .replaceAll('\n', r'\n');
      return '"$escaped"';
    });
  }

  bool? _asNullableBool(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is bool) {
      return value;
    }

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) {
      return null;
    }
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return null;
  }

  String? _asNullableString(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  String? _normalizeRuleExpression(
    String? rawRule, {
    required String fallbackExtractor,
    String? preferredAttribute,
    bool preferJsonShorthand = false,
  }) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    if (text.startsWith('js:') || text.startsWith('@js:')) {
      return text;
    }

    final staticRule = LegacyRuleCompat.extractStaticRuleExpression(text);
    if (staticRule == null || staticRule.isEmpty) {
      return null;
    }

    if (staticRule.startsWith('html:') ||
        staticRule.startsWith('regex:') ||
        staticRule.startsWith('json:') ||
        staticRule.startsWith('js:') ||
        staticRule.startsWith('@js:')) {
      return staticRule;
    }

    final xpathCandidate = LegacyXPathCompat.buildNativeRuleExpression(
      expression: staticRule,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (xpathCandidate != null) {
      return xpathCandidate;
    }

    if (staticRule.startsWith(r'$.') ||
        staticRule.startsWith(r'$[') ||
        staticRule == r'$') {
      return 'json:$staticRule';
    }

    if (LegacyRuleCompat.looksLikeAllInOneRegexExpression(staticRule) ||
        LegacyRuleCompat.looksLikeRegexGroupReference(staticRule)) {
      return staticRule;
    }

    if (staticRule.contains(r'{{$.') ||
        staticRule.contains(r'{{ $.') ||
        staticRule.contains(r'{{\$.') ||
        staticRule.contains(r'{{ \$.')) {
      return 'json:\$\n$staticRule';
    }

    if (staticRule.contains('{{@@') ||
        staticRule.contains('{{@css:') ||
        staticRule.contains('{{@json:') ||
        staticRule.contains('{{@xpath:') ||
        staticRule.contains('{{@js:')) {
      return staticRule;
    }

    final jsonCandidate = _normalizeJsonShorthandExpression(staticRule);

    if (jsonCandidate != null && preferJsonShorthand) {
      return jsonCandidate;
    }

    final htmlCandidate = LegacyRuleCompat.buildHtmlRuleExpression(
      expression: staticRule,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );

    if (jsonCandidate != null) {
      if (htmlCandidate == null || htmlCandidate == jsonCandidate) {
        return jsonCandidate;
      }

      return '$jsonCandidate||$htmlCandidate';
    }

    return htmlCandidate;
  }

  String? _normalizeJsonShorthandExpression(String expression) {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (text.contains('@') || text.startsWith('js:')) {
      return null;
    }

    final segments = text
        .split('&&')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return null;
    }

    final normalizedSegments = <String>[];
    for (final segment in segments) {
      final normalized = _normalizeJsonShorthandSegment(segment);
      if (normalized == null) {
        return null;
      }
      normalizedSegments.add(normalized);
    }

    if (normalizedSegments.length == 1) {
      return 'json:${normalizedSegments.first}';
    }

    final template = normalizedSegments
        .map((segment) => '{{$segment}}')
        .join(' ');
    return 'json:\$\n$template';
  }

  String? _normalizeJsonShorthandSegment(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final replaceIndex = trimmed.indexOf('##');
    final pathPart =
        replaceIndex >= 0 ? trimmed.substring(0, replaceIndex) : trimmed;
    final replacePart =
        replaceIndex >= 0 ? trimmed.substring(replaceIndex) : '';

    final normalizedPath = _normalizeJsonShorthandPath(pathPart.trim());
    if (normalizedPath == null) {
      return null;
    }

    return '$normalizedPath$replacePart';
  }

  String? _normalizeJsonShorthandPath(String token) {
    if (token.isEmpty) {
      return null;
    }

    final unescaped =
        token.startsWith(r'\$') ? token.substring(1).trim() : token;

    if (unescaped == r'$' ||
        unescaped.startsWith(r'$.') ||
        unescaped.startsWith(r'$[')) {
      return unescaped;
    }

    if (unescaped == '*') {
      return r'$[*]';
    }

    if (unescaped.startsWith('[')) {
      return '\$$unescaped';
    }

    final isJsonShorthand = RegExp(
      r'^[a-zA-Z_][a-zA-Z0-9_]*(?:\[[^\]]+\])*(?:\.[a-zA-Z_][a-zA-Z0-9_]*(?:\[[^\]]+\])*)*$',
    ).hasMatch(unescaped);
    if (!isJsonShorthand) {
      return null;
    }

    return '\$.$unescaped';
  }
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

class _NetworkLoadResult {
  const _NetworkLoadResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _RequestRuleSplit {
  const _RequestRuleSplit({
    required this.urlTemplate,
    required this.optionsText,
  });

  final String urlTemplate;
  final String optionsText;
}

class _SearchRequestSpec {
  const _SearchRequestSpec({
    required this.urlTemplate,
    required this.method,
    this.bodyTemplate,
    this.contentType,
    this.responseCharset,
    this.headers = const {},
    this.maxRetries = 1,
    this.useWebView = false,
    this.webJs,
    this.sourceRegex,
  });

  final String urlTemplate;
  final HttpRequestMethod method;
  final Object? bodyTemplate;
  final String? contentType;
  final String? responseCharset;
  final Map<String, String> headers;
  final int maxRetries;
  final bool useWebView;
  final String? webJs;
  final String? sourceRegex;
}

class _InitRuleParts {
  const _InitRuleParts({this.requestRule, this.parseRule});

  final String? requestRule;
  final String? parseRule;
}

class _ListRuleNormalization {
  const _ListRuleNormalization({this.rule, this.reversed = false});

  final String? rule;
  final bool reversed;
}
