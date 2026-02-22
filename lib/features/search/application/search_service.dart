import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_context.dart';
import '../../../core/rule_engine/processors/url_template_resolver.dart';
import '../../../core/source/source_response_processor.dart';
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
  });

  final String sourceId;
  final String sourceName;
  final String message;
  final ErrorCode code;
  final ErrorStage stage;
  final String? requestUrl;
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

class SearchService {
  SearchService({
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    UrlTemplateResolver? urlTemplateResolver,
    SearchResultParser? parser,
    AppLogger? logger,
    SourceResponseProcessor? responseProcessor,
    int maxConcurrentSources = 4,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver(),
       _parser = parser ?? SearchResultParser(),
       _logger = logger ?? AppLogger.instance,
       _responseProcessor =
           responseProcessor ?? const SourceResponseProcessor(),
       _maxConcurrentSources = max(1, maxConcurrentSources);

  final int _maxConcurrentSources;

  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final UrlTemplateResolver _urlTemplateResolver;
  final SearchResultParser _parser;
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

          await _persistSourceHealth(
            source,
            SourceHealthStatus.healthy,
            summary: '搜索成功，命中 ${report.books.length} 条。',
          );

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
          );
          failures.add(failure);

          await _persistSourceHealth(
            source,
            _toHealthStatus(error),
            summary: _toUserReadableMessage(error),
          );

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
          final exception = AppException(
            code: ErrorCode.unknown,
            stage: ErrorStage.search,
            sourceId: source.id,
            briefMessage: '搜索失败：${source.name}',
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
            ),
          );

          await _persistSourceHealth(
            source,
            SourceHealthStatus.unavailable,
            summary: _toUserReadableMessage(exception),
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

    final runtimeContext =
        skipInit
            ? context
            : await _buildRuntimeContext(
              source: source,
              context: context,
              initRule: source.rules.searchInitRule,
            );

    final requestSpec = _parseRequestSpec(rawSearchRule);

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

    final response = await _httpClient.get(
      RequestContext(
        url: requestUrl,
        method: requestSpec.method,
        body: requestBody,
        contentType: contentType,
        headers: requestHeaders,
        maxRetries: 1,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        stage: ErrorStage.search,
        sourceId: source.id,
      ),
    );

    final processedResponse = _responseProcessor.process(
      body: response.body,
      requestUrl: requestUrl,
    );

    final books =
        validateRules
            ? _parseSearchBooks(
              source: source,
              responseBody: processedResponse.body,
              rules: _buildParseRules(source),
            )
            : const <Book>[];

    return _SourceSearchOutput(
      requestUrl: requestUrl,
      method: requestSpec.method,
      statusCode: response.statusCode,
      books: books,
    );
  }

  List<Book> _parseSearchBooks({
    required SourceDefinition source,
    required String responseBody,
    required SearchParseRules rules,
  }) {
    return _parser.parse(
      htmlContent: responseBody,
      sourceId: source.id,
      baseUrl: source.baseUrl,
      rules: rules,
    );
  }

  Future<SearchRequestContext> _buildRuntimeContext({
    required SourceDefinition source,
    required SearchRequestContext context,
    required String? initRule,
  }) async {
    final initVariables = await _loadInitVariables(
      source: source,
      stage: ErrorStage.search,
      initRule: initRule,
      context: context,
    );

    if (initVariables.isEmpty) {
      return context;
    }

    return context.copyWith(
      extraParams: {...context.extraParams, ...initVariables},
    );
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
    final listRule = _normalizeRuleExpression(
      source.rules.searchListRule,
      fallbackExtractor: 'html',
    );

    final listRuleIsJson = listRule?.startsWith('json:') ?? false;
    final fieldPreferJson = listRuleIsJson;

    final titleRule = _normalizeRuleExpression(
      source.rules.searchTitleRule,
      fallbackExtractor: 'text',
      preferJsonShorthand: fieldPreferJson,
    );
    final detailUrlRule = _normalizeRuleExpression(
      source.rules.searchDetailUrlRule,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
      preferJsonShorthand: fieldPreferJson,
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
      titleRule: titleRule,
      detailUrlRule: detailUrlRule,
      authorRule: _normalizeRuleExpression(
        source.rules.searchAuthorRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
      introRule: _normalizeRuleExpression(
        source.rules.searchIntroRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
      coverUrlRule: _normalizeRuleExpression(
        source.rules.searchCoverUrlRule,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
        preferJsonShorthand: fieldPreferJson,
      ),
      latestChapterRule: _normalizeRuleExpression(
        source.rules.searchLatestChapterRule,
        fallbackExtractor: 'text',
        preferJsonShorthand: fieldPreferJson,
      ),
    );
  }

  Future<Map<String, String>> _loadInitVariables({
    required SourceDefinition source,
    required ErrorStage stage,
    required String? initRule,
    required SearchRequestContext context,
  }) async {
    final rawInitRule = initRule?.trim();
    if (rawInitRule == null || rawInitRule.isEmpty) {
      return const {};
    }

    final requestSpec = _parseRequestSpec(rawInitRule);
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

    final response = await _httpClient.get(
      RequestContext(
        url: requestUrl,
        method: requestSpec.method,
        body: requestBody,
        contentType: contentType,
        headers: requestHeaders,
        maxRetries: 1,
        stage: stage,
        sourceId: source.id,
      ),
    );

    final normalizedInitBody =
        _responseProcessor
            .process(body: response.body, requestUrl: requestUrl)
            .body;

    final decoded = _tryDecodeJson(normalizedInitBody);
    if (decoded == null) {
      return const {};
    }

    return _flattenInitVariables(decoded);
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
    final detail = error.briefMessage.trim();

    return switch (error.code) {
      ErrorCode.network => '$stageText网络请求失败，请检查书源地址或网络设置。',
      ErrorCode.validation => '$stageText规则配置不完整：$detail',
      ErrorCode.ruleParse => '$stageText规则解析失败，请检查规则语法。',
      ErrorCode.ruleMatchEmpty => '$stageText未匹配到有效结果，请尝试其他书源。',
      ErrorCode.decode => '$stageText响应解析失败，可能编码或格式不兼容。',
      ErrorCode.unknownSource => '书源不存在或已被删除。',
      ErrorCode.unknown => '$stageText发生未知错误，请稍后重试。',
    };
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

  _SearchRequestSpec _parseRequestSpec(String rawRule) {
    final normalized = rawRule.trim();
    final splitResult = _splitRequestOptions(normalized);
    if (splitResult == null) {
      return _SearchRequestSpec(
        urlTemplate: normalized,
        method: HttpRequestMethod.get,
      );
    }

    final options = _decodeOptionsMap(splitResult.optionsText);
    final methodText = options['method']?.toString().toUpperCase();
    final method =
        methodText == 'POST' ? HttpRequestMethod.post : HttpRequestMethod.get;

    final bodyTemplate = _normalizeBodyTemplate(options['body']);
    final contentType = _asNullableString(
      options['contentType'] ?? options['content-type'],
    );

    final headers = _parseHeaders(options['headers'] ?? options['header']);

    return _SearchRequestSpec(
      urlTemplate: splitResult.urlTemplate,
      method: method,
      bodyTemplate: bodyTemplate,
      contentType: contentType,
      headers: headers,
    );
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

  Map<String, String> _parseHeaders(Object? source) {
    if (source == null) {
      return const {};
    }

    final rawHeaders = source is String ? _decodeOptionsMap(source) : source;

    if (rawHeaders is! Map) {
      return const {};
    }

    final headers = <String, String>{};
    for (final entry in rawHeaders.entries) {
      final key = entry.key.toString().trim();
      final value = entry.value.toString().trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        headers[key] = value;
      }
    }

    return headers;
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

    if (text.startsWith('html:') ||
        text.startsWith('regex:') ||
        text.startsWith('json:')) {
      return text;
    }

    if (text.contains('@js:')) {
      return null;
    }

    if (text.startsWith(r'$.') || text.startsWith(r'$[') || text == r'$') {
      return 'json:$text';
    }

    if (text.contains(r'{{$.') || text.contains(r'{{ $.')) {
      return 'json:\$\n$text';
    }

    final jsonCandidate = _normalizeJsonShorthandExpression(text);

    if (jsonCandidate != null && preferJsonShorthand) {
      return jsonCandidate;
    }

    final firstStage = text.split('&&').first.trim();
    if (firstStage.isEmpty || firstStage.startsWith('js:')) {
      return null;
    }

    final delimiterIndex = firstStage.lastIndexOf('@');
    final String? htmlCandidate = () {
      if (delimiterIndex <= 0 || delimiterIndex >= firstStage.length - 1) {
        return 'html:$firstStage@$fallbackExtractor';
      }

      final selector = firstStage.substring(0, delimiterIndex).trim();
      final extractorToken = firstStage.substring(delimiterIndex + 1).trim();
      if (selector.isEmpty) {
        return null;
      }

      final extractor = _normalizeExtractor(
        extractorToken,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
      );

      return 'html:$selector@$extractor';
    }();

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

  String _normalizeExtractor(
    String extractorToken, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final token = extractorToken.trim();
    if (token.isEmpty) {
      return fallbackExtractor;
    }

    if (token == 'text' || token == 'html') {
      return token;
    }

    if (token.startsWith('attr(') && token.endsWith(')')) {
      return token;
    }

    final attrName = switch (token) {
      'url' => preferredAttribute ?? 'href',
      _ => token,
    };

    final isSimpleAttr = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$').hasMatch(attrName);
    if (isSimpleAttr) {
      return 'attr($attrName)';
    }

    return fallbackExtractor;
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
    this.headers = const {},
  });

  final String urlTemplate;
  final HttpRequestMethod method;
  final Object? bodyTemplate;
  final String? contentType;
  final Map<String, String> headers;
}
