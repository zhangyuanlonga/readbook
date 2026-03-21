import 'dart:async';
import 'dart:convert';

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
import '../../../core/rule_engine/processors/legacy_rule_variable_processor.dart';
import '../../../core/rule_engine/processors/legacy_xpath_compat.dart';
import '../../../core/rule_engine/processors/legacy_link_post_processor.dart';
import '../../../core/rule_engine/processors/legacy_script_rule_fallback.dart';
import '../../../core/rule_engine/processors/source_js_variable_store.dart';
import '../../../core/source/source_response_processor.dart';
import '../../../core/webview/interactive_verification_browser_executor.dart';
import '../../../core/webview/webview_executor.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/search_request_context.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';

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
  BookDetailService({
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    WebViewExecutor? webViewExecutor,
    InteractiveVerificationBrowserExecutor? interactiveVerificationExecutor,
    AppLogger? logger,
    RuleEngine? ruleEngine,
    UrlTemplateResolver? urlTemplateResolver,
    SourceResponseProcessor? responseProcessor,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _webViewExecutor = webViewExecutor ?? WebViewExecutor(),
       _interactiveVerificationExecutor =
           interactiveVerificationExecutor ??
           InteractiveVerificationBrowserExecutor.instance,
       _logger = logger ?? AppLogger.instance,
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver(),
       _responseProcessor =
           responseProcessor ?? const SourceResponseProcessor();

  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final WebViewExecutor _webViewExecutor;
  final InteractiveVerificationBrowserExecutor _interactiveVerificationExecutor;
  final AppLogger _logger;
  final RuleEngine _ruleEngine;
  final UrlTemplateResolver _urlTemplateResolver;
  final SourceResponseProcessor _responseProcessor;

  static final Map<String, BookDetailLoadResult> _detailCache =
      <String, BookDetailLoadResult>{};
  static final Map<String, List<Chapter>> _tocCache = <String, List<Chapter>>{};

  BookDetailLoadResult? peekCached({
    required String sourceId,
    required String detailUrl,
  }) {
    final key = '${sourceId.trim()}|${detailUrl.trim()}';
    final cached = _detailCache[key];
    if (cached == null) {
      return null;
    }
    return BookDetailLoadResult(
      detail: cached.detail,
      chapters: List<Chapter>.unmodifiable(cached.chapters),
      sourceName: cached.sourceName,
      tocFromCache: true,
      tocError: null,
    );
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

    final source = await _getSource(normalizedSourceId);
    final bookVariableUpdates = <String, String>{};
    final runtimeJsVariables = <String, String>{
      ...SourceJsVariableStore.load(source),
      ...SourceJsVariableStore.loadBook(source, bookId: normalizedBookId),
    };

    void collectPutVariables(Map<String, String> variables) {
      if (variables.isEmpty) {
        return;
      }
      bookVariableUpdates.addAll(variables);
      runtimeJsVariables.addAll(
        SourceJsVariableStore.toRuntimeVariables(variables),
      );
    }

    final detailUri = Uri.tryParse(normalizedDetailUrl);
    if (detailUri == null || !detailUri.hasScheme) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        sourceId: normalizedSourceId,
        briefMessage: '详情地址非法：$normalizedDetailUrl',
      );
    }

    final baseKeyword = normalizedFallbackTitle ?? 'detail';
    final templateContext = SearchRequestContext(
      keyword: baseKeyword,
      sourceId: normalizedSourceId,
      extraParams: {'detailUrl': normalizedDetailUrl},
    );
    var bookJsJson = _buildBookJsJson(
      sourceId: normalizedSourceId,
      bookId: normalizedBookId,
      detailUrl: normalizedDetailUrl,
      title: normalizedFallbackTitle,
    );

    final detailInitVariables = await _loadInitVariables(
      source: source,
      stage: ErrorStage.detail,
      initRule: source.rules.detailInitRule,
      context: templateContext,
      jsContext: _buildDetailJsContext(
        source: source,
        runtimeContext: templateContext,
        bookJson: bookJsJson,
        seedVariables: runtimeJsVariables,
        onBridgePutVariables: collectPutVariables,
      ),
    );

    final detailContext =
        detailInitVariables.isEmpty
            ? templateContext
            : templateContext.copyWith(
              extraParams: {
                ...templateContext.extraParams,
                ...detailInitVariables,
              },
            );

    final tocInitVariables = await _loadInitVariables(
      source: source,
      stage: ErrorStage.toc,
      initRule: source.rules.tocInitRule,
      context: detailContext,
      jsContext: _buildDetailJsContext(
        source: source,
        runtimeContext: detailContext,
        bookJson: bookJsJson,
        seedVariables: runtimeJsVariables,
        onBridgePutVariables: collectPutVariables,
      ),
    );

    final runtimeContext =
        tocInitVariables.isEmpty
            ? detailContext
            : detailContext.copyWith(
              extraParams: {...detailContext.extraParams, ...tocInitVariables},
            );

    final detailHtml = await _fetchHtml(
      source: source,
      stage: ErrorStage.detail,
      url: normalizedDetailUrl,
      context: runtimeContext,
    );

    final normalizedDetailHtml =
        _responseProcessor
            .process(body: detailHtml, requestUrl: normalizedDetailUrl)
            .body;

    final detailRules = _buildDetailRules(source);
    final detailVariables = <String, String>{...runtimeContext.extraParams};
    var ruleJsContext = _buildDetailJsContext(
      source: source,
      runtimeContext: runtimeContext,
      bookJson: bookJsJson,
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: collectPutVariables,
    );

    final titleRule = _resolveRuntimeRuleTemplate(
      _resolveDetailRule(detailRules.initRule, detailRules.titleRule),
      normalizedDetailUrl,
      context: runtimeContext,
    );
    final authorRule = _resolveRuntimeRuleTemplate(
      _resolveDetailRule(detailRules.initRule, detailRules.authorRule),
      normalizedDetailUrl,
      context: runtimeContext,
    );
    final introRule = _resolveRuntimeRuleTemplate(
      _resolveDetailRule(detailRules.initRule, detailRules.introRule),
      normalizedDetailUrl,
      context: runtimeContext,
    );
    final coverRule = _resolveRuntimeRuleTemplate(
      _resolveDetailRule(detailRules.initRule, detailRules.coverUrlRule),
      normalizedDetailUrl,
      context: runtimeContext,
    );
    final tocUrlRule = _resolveRuntimeRuleTemplate(
      _resolveDetailRule(detailRules.initRule, detailRules.tocUrlRule),
      normalizedDetailUrl,
      context: runtimeContext,
    );

    await _extractOptionalValue(
      content: normalizedDetailHtml,
      expression: detailRules.initRule,
      rawRule: detailRules.rawInitRule,
      stage: ErrorStage.detail,
      variables: detailVariables,
      fallbackExtractor: 'html',
      jsContext: ruleJsContext,
    );

    final canRename = await _evaluateCanRename(
      content: normalizedDetailHtml,
      stage: ErrorStage.detail,
      expression: detailRules.canRenameRule,
      rawRule: detailRules.rawCanRenameRule,
      variables: detailVariables,
      jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
    );
    final extractedTitle = _normalizeOptionalText(
      await _extractOptionalValue(
        content: normalizedDetailHtml,
        expression: titleRule,
        rawRule: detailRules.rawTitleRule,
        stage: ErrorStage.detail,
        variables: detailVariables,
        fallbackExtractor: 'text',
        jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
      ),
    );
    final title =
        _selectPreferredText(
          preferPrimary: canRename,
          primary: extractedTitle,
          fallback: normalizedFallbackTitle,
        ) ??
        '未命名书籍';
    bookJsJson = _buildBookJsJson(
      sourceId: normalizedSourceId,
      bookId: normalizedBookId,
      detailUrl: normalizedDetailUrl,
      title: title,
    );
    ruleJsContext = _buildDetailJsContext(
      source: source,
      runtimeContext: runtimeContext,
      bookJson: bookJsJson,
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: collectPutVariables,
    );

    final cover = _resolveMaybeUrl(
      pageUrl: normalizedDetailUrl,
      rawUrl: await _extractOptionalValue(
        content: normalizedDetailHtml,
        expression: coverRule,
        rawRule: detailRules.rawCoverUrlRule,
        stage: ErrorStage.detail,
        variables: detailVariables,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
        jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
      ),
    );

    final extractedTocUrl = await _extractOptionalValue(
      content: normalizedDetailHtml,
      expression: tocUrlRule,
      rawRule: detailRules.rawTocUrlRule,
      stage: ErrorStage.detail,
      variables: detailVariables,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
      jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
    );

    final resolvedTocRuleLiteral =
        tocUrlRule == null
            ? null
            : LegacyRuleVariableProcessor.replaceGetTokens(
              tocUrlRule,
              detailVariables,
            );

    final tocCandidate =
        extractedTocUrl ??
        (_looksLikeRequestRule(resolvedTocRuleLiteral)
            ? resolvedTocRuleLiteral
            : null);

    var tocUrl = _resolveMaybeUrl(
      pageUrl: normalizedDetailUrl,
      rawUrl: tocCandidate,
    );

    if (tocUrl == null || tocUrl.isEmpty) {
      tocUrl = normalizedDetailUrl;
    }

    final extractedAuthor = _normalizeOptionalText(
      await _extractOptionalValue(
        content: normalizedDetailHtml,
        expression: authorRule,
        rawRule: detailRules.rawAuthorRule,
        stage: ErrorStage.detail,
        variables: detailVariables,
        fallbackExtractor: 'text',
        jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
      ),
    );
    final detail = BookDetail(
      id: normalizedBookId,
      sourceId: normalizedSourceId,
      title: title,
      detailUrl: normalizedDetailUrl,
      author: _selectPreferredText(
        preferPrimary: canRename,
        primary: extractedAuthor,
        fallback: normalizedFallbackAuthor,
      ),
      intro: await _extractOptionalValue(
        content: normalizedDetailHtml,
        expression: introRule,
        rawRule: detailRules.rawIntroRule,
        stage: ErrorStage.detail,
        variables: detailVariables,
        fallbackExtractor: 'text',
        jsContext: _mergeJsContextVariables(ruleJsContext, detailVariables),
      ),
      coverUrl: cover,
      tocUrl: tocUrl,
    );
    final tocJsContext = _buildDetailJsContext(
      source: source,
      runtimeContext: runtimeContext,
      bookJson: _buildBookJsJson(
        sourceId: normalizedSourceId,
        bookId: normalizedBookId,
        detailUrl: normalizedDetailUrl,
        title: detail.title,
        author: detail.author,
        intro: detail.intro,
        coverUrl: detail.coverUrl,
        tocUrl: detail.tocUrl,
      ),
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: collectPutVariables,
    );

    final tocCacheKey = '$normalizedSourceId|$normalizedDetailUrl';
    if (!forceRefresh && _tocCache.containsKey(tocCacheKey)) {
      final cached = _tocCache[tocCacheKey]!;
      await _persistBookJsVariables(
        source: source,
        bookId: normalizedBookId,
        variables: bookVariableUpdates,
        stage: ErrorStage.detail,
      );
      _detailCache[tocCacheKey] = BookDetailLoadResult(
        detail: detail,
        chapters: List<Chapter>.unmodifiable(cached),
        sourceName: source.name,
        tocFromCache: false,
      );
      return BookDetailLoadResult(
        detail: detail,
        chapters: List.unmodifiable(cached),
        sourceName: source.name,
        tocFromCache: true,
      );
    }

    var chapters = const <Chapter>[];
    AppException? tocError;

    final tocRules = _buildTocRules(source);
    if (tocRules == null) {
      tocError = AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.toc,
        sourceId: normalizedSourceId,
        briefMessage: '书源缺少目录规则（chapterList/chapterName/chapterUrl）。',
      );
    } else {
      try {
        var tocPageHtml = normalizedDetailHtml;
        var tocPageUrl = normalizedDetailUrl;
        chapters = await _parseChapters(
          html: tocPageHtml,
          pageUrl: tocPageUrl,
          rules: tocRules,
          sourceId: normalizedSourceId,
          bookId: normalizedBookId,
          context: runtimeContext,
          seedVariables: detailVariables,
          jsContext: tocJsContext,
        );

        if (chapters.isEmpty && tocUrl != normalizedDetailUrl) {
          final tocHtml = await _fetchHtml(
            source: source,
            stage: ErrorStage.toc,
            url: tocUrl,
            context: runtimeContext,
          );
          final normalizedTocHtml =
              _responseProcessor
                  .process(body: tocHtml, requestUrl: tocUrl)
                  .body;
          tocPageHtml = normalizedTocHtml;
          tocPageUrl = tocUrl;
          chapters = await _parseChapters(
            html: tocPageHtml,
            pageUrl: tocPageUrl,
            rules: tocRules,
            sourceId: normalizedSourceId,
            bookId: normalizedBookId,
            context: runtimeContext,
            seedVariables: detailVariables,
            jsContext: tocJsContext,
          );
        }

        chapters = await _appendNextTocChapters(
          source: source,
          rules: tocRules,
          sourceId: normalizedSourceId,
          bookId: normalizedBookId,
          context: runtimeContext,
          seedVariables: detailVariables,
          jsContext: tocJsContext,
          initialPageHtml: tocPageHtml,
          initialPageUrl: tocPageUrl,
          initialChapters: chapters,
        );

        if (chapters.isEmpty) {
          throw RuleMatchEmptyException(
            briefMessage: '目录解析为空，请检查书源规则。',
            sourceId: normalizedSourceId,
            stage: ErrorStage.toc,
            requestUrl: tocUrl,
          );
        }

        _tocCache[tocCacheKey] = chapters;
      } on AppException catch (error) {
        tocError = error;
        _logger.warn(
          'Book toc load failed',
          context: {
            'sourceId': normalizedSourceId,
            'bookId': normalizedBookId,
            'detailUrl': normalizedDetailUrl,
            'tocUrl': tocUrl,
            'code': error.code.name,
            'stage': error.stage.name,
          },
        );
      } catch (error, stackTrace) {
        tocError = AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.toc,
          sourceId: normalizedSourceId,
          requestUrl: tocUrl,
          briefMessage: '目录加载失败，请稍后重试。',
          cause: error,
          stackTrace: stackTrace,
        );
        _logger.warn(
          'Book toc load failed',
          context: {
            'sourceId': normalizedSourceId,
            'bookId': normalizedBookId,
            'detailUrl': normalizedDetailUrl,
            'tocUrl': tocUrl,
            'error': error.toString(),
          },
        );
      }
    }

    await _persistBookJsVariables(
      source: source,
      bookId: normalizedBookId,
      variables: bookVariableUpdates,
      stage: ErrorStage.detail,
    );
    final result = BookDetailLoadResult(
      detail: detail,
      chapters: chapters,
      sourceName: source.name,
      tocFromCache: false,
      tocError: tocError,
    );
    _detailCache[tocCacheKey] = BookDetailLoadResult(
      detail: detail,
      chapters: List<Chapter>.unmodifiable(chapters),
      sourceName: source.name,
      tocFromCache: false,
    );
    return result;
  }

  Future<SourceDefinition> _getSource(String sourceId) async {
    final sources = await _sourceRepository.getAll();
    for (final source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }

    throw UnknownSourceException(
      briefMessage: '未找到书源：$sourceId',
      sourceId: sourceId,
      stage: ErrorStage.detail,
    );
  }

  Future<void> _persistBookJsVariables({
    required SourceDefinition source,
    required String bookId,
    required Map<String, String> variables,
    required ErrorStage stage,
  }) async {
    if (variables.isEmpty) {
      return;
    }

    final nextSource = SourceJsVariableStore.mergeBook(
      source: source,
      bookId: bookId,
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

  Future<String> _fetchHtml({
    required SourceDefinition source,
    required ErrorStage stage,
    required String url,
    required SearchRequestContext context,
  }) async {
    final requestSpec = _parseRequestSpec(url);
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
      'Book detail fetch',
      context: {
        'sourceId': source.id,
        'sourceName': source.name,
        'stage': stage.name,
        'url': requestUrl,
        'method': requestSpec.method.name,
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

    return response.body;
  }

  Future<_NetworkLoadResult> _executeRequest({
    required SourceDefinition source,
    required ErrorStage stage,
    required _SearchRequestSpec requestSpec,
    required String requestUrl,
    required Object? requestBody,
    required String? contentType,
    required Map<String, String> requestHeaders,
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
            webViewDelay: requestSpec.webViewDelay,
            enabledCookieJar: requestSpec.enabledCookieJar,
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

    try {
      final response = await _httpClient.get(
        RequestContext(
          url: requestUrl,
          method: requestSpec.method,
          body: requestBody,
          contentType: contentType,
          responseCharset: requestSpec.responseCharset,
          headers: requestHeaders,
          maxRetries: requestSpec.maxRetries,
          enabledCookieJar: requestSpec.enabledCookieJar,
          stage: stage,
          sourceId: source.id,
          sourceConcurrentRate: source.concurrentRate,
        ),
      );
      return _NetworkLoadResult(
        statusCode: response.statusCode,
        body: response.body,
      );
    } on AppException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  _DetailParseRules _buildDetailRules(SourceDefinition source) {
    return _DetailParseRules(
      initRule: _normalizeRuleExpression(
        source.rules.detailRule,
        fallbackExtractor: 'html',
      ),
      rawInitRule: source.rules.detailRule,
      titleRule: _normalizeRuleExpression(
        source.rules.detailTitleRule,
        fallbackExtractor: 'text',
      ),
      rawTitleRule: source.rules.detailTitleRule,
      authorRule: _normalizeRuleExpression(
        source.rules.detailAuthorRule,
        fallbackExtractor: 'text',
      ),
      rawAuthorRule: source.rules.detailAuthorRule,
      canRenameRule: _normalizeOptionalText(source.rules.detailCanRenameRule),
      rawCanRenameRule: source.rules.detailCanRenameRule,
      introRule: _normalizeRuleExpression(
        source.rules.detailIntroRule,
        fallbackExtractor: 'text',
      ),
      rawIntroRule: source.rules.detailIntroRule,
      coverUrlRule: _normalizeRuleExpression(
        source.rules.detailCoverUrlRule,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
      ),
      rawCoverUrlRule: source.rules.detailCoverUrlRule,
      tocUrlRule: _normalizeLinkRuleExpression(
        source.rules.detailTocUrlRule,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
      ),
      rawTocUrlRule: source.rules.detailTocUrlRule,
    );
  }

  _TocParseRules? _buildTocRules(SourceDefinition source) {
    final listRuleRaw = _normalizeListRuleReversePrefix(
      source.rules.tocListRule ?? source.rules.tocRule,
    );
    final preferCurrentNodeChunk =
        _isBareCurrentNodeExtractorRule(source.rules.tocTitleRule) ||
        _isBareCurrentNodeExtractorRule(source.rules.tocChapterUrlRule);

    var listRule = _normalizeRuleExpression(
      listRuleRaw.rule,
      fallbackExtractor: preferCurrentNodeChunk ? 'outerhtml' : 'html',
    );
    if (preferCurrentNodeChunk) {
      listRule = _upgradeListRuleToOuterHtml(listRule);
    }
    listRule ??= _buildVariableExpressionFallback(listRuleRaw.rule);
    listRule ??= _buildScriptFallbackExpression(listRuleRaw.rule, list: true);

    var titleRule = _normalizeRuleExpression(
      source.rules.tocTitleRule,
      fallbackExtractor: 'text',
    );
    titleRule ??= _buildVariableExpressionFallback(source.rules.tocTitleRule);
    titleRule ??= _buildScriptFallbackExpression(source.rules.tocTitleRule);

    var chapterUrlRule = _normalizeRuleExpression(
      source.rules.tocChapterUrlRule,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
    );
    chapterUrlRule ??= _buildVariableExpressionFallback(
      source.rules.tocChapterUrlRule,
    );
    chapterUrlRule ??= _buildScriptFallbackExpression(
      source.rules.tocChapterUrlRule,
    );

    var nextUrlRule = _normalizeLinkRuleExpression(
      source.rules.tocNextUrlRule,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
    );
    nextUrlRule ??= _buildVariableExpressionFallback(
      source.rules.tocNextUrlRule,
    );
    nextUrlRule ??= _buildScriptFallbackExpression(source.rules.tocNextUrlRule);

    if (listRule == null || titleRule == null || chapterUrlRule == null) {
      return null;
    }

    return _TocParseRules(
      listRule: listRule,
      titleRule: titleRule,
      chapterUrlRule: chapterUrlRule,
      rawListRule: source.rules.tocListRule ?? source.rules.tocRule,
      rawTitleRule: source.rules.tocTitleRule,
      rawChapterUrlRule: source.rules.tocChapterUrlRule,
      nextUrlRule: nextUrlRule,
      rawNextUrlRule: source.rules.tocNextUrlRule,
      reversed: source.rules.tocReversed || listRuleRaw.reversed,
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
        token == 'alt';
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

  Future<List<Chapter>> _parseChapters({
    required String html,
    required String pageUrl,
    required _TocParseRules rules,
    required String sourceId,
    required String bookId,
    required SearchRequestContext context,
    required Map<String, String> seedVariables,
    required JsExecutionContext jsContext,
  }) async {
    final chunks = await _tryExecuteAll(
      content: html,
      expression: rules.listRule,
      stage: ErrorStage.toc,
      rawRule: rules.rawListRule,
      variables: seedVariables,
      fallbackExtractor: 'html',
      jsContext: _mergeJsContextVariables(jsContext, seedVariables),
    );
    if (chunks.isEmpty) {
      return const [];
    }

    final chapterUrlRule = _resolveRuntimeRuleTemplate(
      rules.chapterUrlRule,
      pageUrl,
      context: context,
    );

    final dedupe = <String, Chapter>{};
    for (final chunk in chunks) {
      final variableState = <String, String>{...seedVariables};
      final chunkJsContext = _buildChapterJsContext(
        jsContext: jsContext,
        bookId: bookId,
        chapterUrl: pageUrl,
        chapterIndex: dedupe.length,
      );
      final title = await _extractOptionalValue(
        content: chunk,
        expression: rules.titleRule,
        stage: ErrorStage.toc,
        rawRule: rules.rawTitleRule,
        variables: variableState,
        fallbackExtractor: 'text',
        jsContext: _mergeJsContextVariables(chunkJsContext, variableState),
      );
      final chapterRuleJsContext = _buildChapterJsContext(
        jsContext: chunkJsContext,
        bookId: bookId,
        chapterUrl: pageUrl,
        chapterIndex: dedupe.length,
        chapterTitle: title,
      );
      final chapterUrlRaw = await _extractOptionalValue(
        content: chunk,
        expression: chapterUrlRule,
        stage: ErrorStage.toc,
        rawRule: rules.rawChapterUrlRule,
        variables: variableState,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
        jsContext: _mergeJsContextVariables(
          chapterRuleJsContext,
          variableState,
        ),
      );

      if (title == null || chapterUrlRaw == null) {
        continue;
      }

      final chapterUrlValue =
          rules.chapterUrlRule == LegacyScriptRuleFallback.fieldExpression ||
                  rules.chapterUrlRule.startsWith('js:') ||
                  rules.chapterUrlRule.startsWith('@js:')
              ? chapterUrlRaw.trim()
              : LegacyLinkPostProcessor.apply(
                value: chapterUrlRaw,
                rawRule: rules.rawChapterUrlRule,
              );
      final chapterUrl = _resolveMaybeUrl(
        pageUrl: pageUrl,
        rawUrl: chapterUrlValue,
      );
      if (chapterUrl == null) {
        continue;
      }

      final chapter = Chapter(
        id: _buildHashId('chapter', '$bookId|$chapterUrl'),
        bookId: bookId,
        title: title,
        chapterUrl: chapterUrl,
        index: dedupe.length,
      );

      final dedupeKey = _buildChapterDedupeKey(
        title: title,
        chapterUrl: chapterUrl,
      );
      dedupe[dedupeKey] = chapter;
    }

    if (dedupe.isEmpty) {
      return const [];
    }

    var ordered = dedupe.values.toList(growable: false);
    if (rules.reversed) {
      ordered = ordered.reversed.toList(growable: false);
    }

    return List<Chapter>.generate(
      ordered.length,
      (index) => Chapter(
        id: ordered[index].id,
        bookId: ordered[index].bookId,
        title: ordered[index].title,
        chapterUrl: ordered[index].chapterUrl,
        index: index,
      ),
      growable: false,
    );
  }

  Future<List<Chapter>> _appendNextTocChapters({
    required SourceDefinition source,
    required _TocParseRules rules,
    required String sourceId,
    required String bookId,
    required SearchRequestContext context,
    required Map<String, String> seedVariables,
    required JsExecutionContext jsContext,
    required String initialPageHtml,
    required String initialPageUrl,
    required List<Chapter> initialChapters,
  }) async {
    final nextRule = rules.nextUrlRule?.trim();
    if (nextRule == null || nextRule.isEmpty || initialChapters.isEmpty) {
      return initialChapters;
    }

    final allChapters = <Chapter>[...initialChapters];
    final dedupeKeys = <String>{
      for (final chapter in initialChapters)
        _buildChapterDedupeKey(
          title: chapter.title,
          chapterUrl: chapter.chapterUrl,
        ),
    };
    final visitedPages = <String>{_stripRequestOptions(initialPageUrl)};
    var currentHtml = initialPageHtml;
    var currentUrl = initialPageUrl;
    var emptyRounds = 0;
    const maxPages = 50;

    for (var page = 0; page < maxPages; page += 1) {
      final nextUrl = await _extractNextTocUrl(
        sourceId: sourceId,
        rules: rules,
        html: currentHtml,
        pageUrl: currentUrl,
        context: context,
        seedVariables: seedVariables,
        jsContext: jsContext,
      );
      if (nextUrl == null || nextUrl.trim().isEmpty) {
        break;
      }

      final normalizedNextUrl = _stripRequestOptions(nextUrl);
      if (!visitedPages.add(normalizedNextUrl)) {
        break;
      }

      final nextHtmlResponse = await _fetchHtml(
        source: source,
        stage: ErrorStage.toc,
        url: nextUrl,
        context: context,
      );
      final normalizedNextHtml =
          _responseProcessor
              .process(body: nextHtmlResponse, requestUrl: nextUrl)
              .body;
      final nextChapters = await _parseChapters(
        html: normalizedNextHtml,
        pageUrl: nextUrl,
        rules: rules,
        sourceId: sourceId,
        bookId: bookId,
        context: context,
        seedVariables: seedVariables,
        jsContext: jsContext,
      );

      if (nextChapters.isEmpty) {
        emptyRounds += 1;
        if (emptyRounds >= 2) {
          break;
        }
      } else {
        emptyRounds = 0;
        for (final chapter in nextChapters) {
          final key = _buildChapterDedupeKey(
            title: chapter.title,
            chapterUrl: chapter.chapterUrl,
          );
          if (dedupeKeys.add(key)) {
            allChapters.add(chapter);
          }
        }
      }

      currentHtml = normalizedNextHtml;
      currentUrl = nextUrl;
    }

    return List<Chapter>.generate(
      allChapters.length,
      (index) => Chapter(
        id: allChapters[index].id,
        bookId: allChapters[index].bookId,
        title: allChapters[index].title,
        chapterUrl: allChapters[index].chapterUrl,
        index: index,
      ),
      growable: false,
    );
  }

  Future<String?> _extractNextTocUrl({
    required String sourceId,
    required _TocParseRules rules,
    required String html,
    required String pageUrl,
    required SearchRequestContext context,
    required Map<String, String> seedVariables,
    required JsExecutionContext jsContext,
  }) async {
    final nextExpression = rules.nextUrlRule?.trim();
    if (nextExpression == null || nextExpression.isEmpty) {
      return null;
    }

    final resolvedExpression = _resolveRuntimeRuleTemplate(
      nextExpression,
      pageUrl,
      context: context,
    );
    final variableState = <String, String>{...seedVariables};
    String? nextRaw;

    if (_looksLikeRequestRule(resolvedExpression)) {
      nextRaw = resolvedExpression;
    } else {
      nextRaw = await _extractOptionalValue(
        content: html,
        expression: resolvedExpression,
        stage: ErrorStage.toc,
        rawRule: rules.rawNextUrlRule,
        variables: variableState,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
        jsContext: _mergeJsContextVariables(jsContext, variableState),
      );
    }

    if (nextRaw == null || nextRaw.trim().isEmpty) {
      return null;
    }

    final shouldBypassPostProcess =
        nextExpression == LegacyScriptRuleFallback.fieldExpression ||
        nextExpression.startsWith('js:') ||
        nextExpression.startsWith('@js:');
    final nextValue =
        shouldBypassPostProcess
            ? nextRaw.trim()
            : LegacyLinkPostProcessor.apply(
              value: nextRaw,
              rawRule: rules.rawNextUrlRule,
            );
    if (nextValue.trim().isEmpty) {
      return null;
    }

    final resolved = _resolveMaybeUrl(pageUrl: pageUrl, rawUrl: nextValue);
    if (resolved == null || resolved.trim().isEmpty) {
      return null;
    }
    _validateResolvedRequestUrl(requestUrl: resolved, sourceId: sourceId);
    return resolved;
  }

  Future<List<String>> _tryExecuteAll({
    required String content,
    required String expression,
    required ErrorStage stage,
    required String fallbackExtractor,
    String? preferredAttribute,
    String? rawRule,
    Map<String, String>? variables,
    JsExecutionContext? jsContext,
  }) async {
    final mutableVariables = variables ?? <String, String>{};

    if (expression == LegacyScriptRuleFallback.listExpression) {
      return LegacyScriptRuleFallback.evaluateListChunks(
        content: content,
        rawRule: rawRule,
      );
    }

    if (LegacyScriptRuleFallback.isScriptOnlyRule(rawRule)) {
      final fallbackValues = LegacyScriptRuleFallback.evaluateListChunks(
        content: content,
        rawRule: rawRule,
      );
      if (fallbackValues.isNotEmpty) {
        return fallbackValues;
      }
    }

    final variableAwareRaw =
        LegacyRuleVariableProcessor.containsVariableSyntax(rawRule)
            ? rawRule!.trim()
            : null;
    if (variableAwareRaw != null) {
      final resolvedRaw =
          await LegacyRuleVariableProcessor.resolveExpressionAsync(
            expression: variableAwareRaw,
            variables: mutableVariables,
            resolvePutValue:
                (valueExpression) => _evaluatePutValue(
                  content: content,
                  stage: stage,
                  valueExpression: valueExpression,
                  fallbackExtractor: fallbackExtractor,
                  preferredAttribute: preferredAttribute,
                  jsContext: _mergeJsContextVariables(
                    jsContext,
                    mutableVariables,
                  ),
                ),
          );

      final values = await _executeAllRuleLikeExpression(
        content: content,
        stage: stage,
        expression: resolvedRaw,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
        jsContext: _mergeJsContextVariables(jsContext, mutableVariables),
      );
      if (values.isNotEmpty) {
        return values;
      }
    }

    final resolvedExpression = LegacyRuleVariableProcessor.replaceGetTokens(
      expression,
      mutableVariables,
    );

    for (final candidate in _splitFallbackExpressions(resolvedExpression)) {
      try {
        final values = await _ruleEngine.executeAll(
          content: content,
          expression: candidate,
          stage: stage,
          jsContext: _mergeJsContextVariables(jsContext, mutableVariables),
        );
        if (values.isNotEmpty) {
          return values;
        }
      } on AppException {
        continue;
      }
    }

    return const [];
  }

  Future<String?> _extractOptionalValue({
    required String content,
    required String? expression,
    required ErrorStage stage,
    required String fallbackExtractor,
    required Map<String, String> variables,
    String? preferredAttribute,
    String? rawRule,
    JsExecutionContext? jsContext,
  }) async {
    final variableAwareRaw =
        LegacyRuleVariableProcessor.containsVariableSyntax(rawRule)
            ? rawRule!.trim()
            : null;

    if (variableAwareRaw != null) {
      final resolvedRaw =
          await LegacyRuleVariableProcessor.resolveExpressionAsync(
            expression: variableAwareRaw,
            variables: variables,
            resolvePutValue:
                (valueExpression) => _evaluatePutValue(
                  content: content,
                  stage: stage,
                  valueExpression: valueExpression,
                  fallbackExtractor: fallbackExtractor,
                  preferredAttribute: preferredAttribute,
                  jsContext: _mergeJsContextVariables(jsContext, variables),
                ),
          );

      final variableRawValue = await _executeRuleLikeExpression(
        content: content,
        stage: stage,
        expression: resolvedRaw,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
        treatLiteralAsValue: true,
        jsContext: _mergeJsContextVariables(jsContext, variables),
      );
      if (variableRawValue != null) {
        return variableRawValue;
      }
    }

    if (expression == null || expression.trim().isEmpty) {
      return LegacyScriptRuleFallback.evaluateFieldValue(
        content: content,
        rawRule: rawRule,
      );
    }

    final resolvedExpression = LegacyRuleVariableProcessor.replaceGetTokens(
      expression,
      variables,
    );

    if (resolvedExpression == LegacyScriptRuleFallback.fieldExpression) {
      return LegacyScriptRuleFallback.evaluateFieldValue(
        content: content,
        rawRule: rawRule,
      );
    }

    for (final candidate in _splitFallbackExpressions(resolvedExpression)) {
      try {
        final value = await _ruleEngine.executeFirst(
          content: content,
          expression: candidate,
          stage: stage,
          jsContext: _mergeJsContextVariables(jsContext, variables),
        );
        final normalized = value.trim();
        if (normalized.isNotEmpty) {
          return normalized;
        }
      } on AppException {
        continue;
      }
    }

    return LegacyScriptRuleFallback.evaluateFieldValue(
      content: content,
      rawRule: rawRule,
    );
  }

  Future<String?> _evaluatePutValue({
    required String content,
    required ErrorStage stage,
    required String valueExpression,
    required String fallbackExtractor,
    String? preferredAttribute,
    JsExecutionContext? jsContext,
  }) async {
    final text = valueExpression.trim();
    if (text.isEmpty) {
      return null;
    }

    return _executeRuleLikeExpression(
      content: content,
      stage: stage,
      expression: text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
      treatLiteralAsValue: true,
      jsContext: jsContext,
    );
  }

  Future<bool> _evaluateCanRename({
    required String content,
    required ErrorStage stage,
    required String? expression,
    required Map<String, String> variables,
    String? rawRule,
    JsExecutionContext? jsContext,
  }) async {
    final normalizedExpression = _normalizeOptionalText(expression);
    if (normalizedExpression == null) {
      return true;
    }

    final literal = _parseBooleanLike(normalizedExpression);
    if (literal != null) {
      return literal;
    }

    final resolvedExpression = LegacyRuleVariableProcessor.replaceGetTokens(
      normalizedExpression,
      variables,
    );
    final resolvedLiteral = _parseBooleanLike(resolvedExpression);
    if (resolvedLiteral != null) {
      return resolvedLiteral;
    }

    final dynamicValue = _normalizeOptionalText(
      await _executeRuleLikeExpression(
        content: content,
        stage: stage,
        expression: resolvedExpression,
        fallbackExtractor: 'text',
        treatLiteralAsValue: true,
        jsContext: _mergeJsContextVariables(jsContext, variables),
      ),
    );

    final fallbackValue =
        dynamicValue ??
        _normalizeOptionalText(
          LegacyScriptRuleFallback.evaluateFieldValue(
            content: content,
            rawRule: rawRule,
          ),
        );
    if (fallbackValue == null) {
      return false;
    }

    final parsed = _parseBooleanLike(fallbackValue);
    return parsed ?? true;
  }

  String? _selectPreferredText({
    required bool preferPrimary,
    required String? primary,
    required String? fallback,
  }) {
    final normalizedPrimary = _normalizeOptionalText(primary);
    final normalizedFallback = _normalizeOptionalText(fallback);
    if (preferPrimary) {
      return normalizedPrimary ?? normalizedFallback;
    }
    return normalizedFallback ?? normalizedPrimary;
  }

  bool? _parseBooleanLike(String? value) {
    final text = _normalizeOptionalText(value)?.toLowerCase();
    if (text == null) {
      return null;
    }

    if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
      return true;
    }
    if (text == 'false' ||
        text == '0' ||
        text == 'no' ||
        text == 'off' ||
        text == 'null' ||
        text == 'undefined' ||
        text == 'nan') {
      return false;
    }

    final numeric = num.tryParse(text);
    if (numeric != null) {
      return numeric != 0;
    }

    return null;
  }

  String? _normalizeOptionalText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  Future<List<String>> _executeAllRuleLikeExpression({
    required String content,
    required ErrorStage stage,
    required String expression,
    required String fallbackExtractor,
    String? preferredAttribute,
    JsExecutionContext? jsContext,
  }) async {
    final text = expression.trim();
    if (text.isEmpty) {
      return const [];
    }

    final normalizedExpression = _normalizeVariableRuleExpression(
      text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (normalizedExpression == null || normalizedExpression.isEmpty) {
      return const [];
    }

    for (final candidate in _splitFallbackExpressions(normalizedExpression)) {
      try {
        final values = await _ruleEngine.executeAll(
          content: content,
          expression: candidate,
          stage: stage,
          jsContext: jsContext,
        );
        if (values.isNotEmpty) {
          return values;
        }
      } on AppException {
        continue;
      }
    }

    return const [];
  }

  Future<String?> _executeRuleLikeExpression({
    required String content,
    required ErrorStage stage,
    required String expression,
    required String fallbackExtractor,
    String? preferredAttribute,
    bool treatLiteralAsValue = false,
    JsExecutionContext? jsContext,
  }) async {
    final text = expression.trim();
    if (text.isEmpty) {
      return null;
    }

    if (treatLiteralAsValue && !_looksLikeRuleExpression(text)) {
      return text;
    }

    final normalizedExpression = _normalizeVariableRuleExpression(
      text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (normalizedExpression == null || normalizedExpression.isEmpty) {
      if (treatLiteralAsValue && !_looksLikeRuleExpression(text)) {
        return text;
      }
      return null;
    }

    for (final candidate in _splitFallbackExpressions(normalizedExpression)) {
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

    return null;
  }

  String? _normalizeVariableRuleExpression(
    String expression, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final text = expression.trim();
    if (text.isEmpty) {
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

    if (staticRule.startsWith('@json:')) {
      final candidate = staticRule.substring(6).trim();
      if (candidate.isNotEmpty) {
        return 'json:$candidate';
      }
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

    if (staticRule.contains('{{@@') ||
        staticRule.contains('{{@css:') ||
        staticRule.contains('{{@json:') ||
        staticRule.contains('{{@xpath:') ||
        staticRule.contains('{{@js:')) {
      return staticRule;
    }

    return LegacyRuleCompat.buildHtmlRuleExpression(
      expression: staticRule,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
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
        text.startsWith('@json:') ||
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

  String? _resolveMaybeUrl({required String pageUrl, required String? rawUrl}) {
    final text = rawUrl?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final requestSplit = _splitRequestOptions(text);
    final rawUrlPart = requestSplit?.urlTemplate ?? text;
    final urlPart = _normalizeCandidateUrl(rawUrlPart);
    if (urlPart == null ||
        _isInvalidChapterUrl(urlPart) ||
        _looksLikeHtmlFragment(urlPart) ||
        _looksLikeEncodedHtmlFragment(urlPart)) {
      return null;
    }

    final resolvedUrl = _resolveAbsoluteHttpUrl(
      pageUrl: pageUrl,
      rawUrl: urlPart,
    );
    if (resolvedUrl == null) {
      return null;
    }

    if (requestSplit == null) {
      return resolvedUrl;
    }

    return '$resolvedUrl,${requestSplit.optionsText}';
  }

  String? _normalizeCandidateUrl(String rawUrl) {
    var normalized = rawUrl.trim();
    if (normalized.isEmpty) {
      return null;
    }

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }

    return normalized.isEmpty ? null : normalized;
  }

  bool _isInvalidChapterUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('about:blank') ||
        lower.startsWith('data:') ||
        lower.startsWith('mailto:') ||
        lower == '#' ||
        lower.startsWith('#')) {
      return true;
    }

    return false;
  }

  bool _looksLikeHtmlFragment(String value) {
    final normalized = value.trimLeft().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }

    if (normalized.startsWith('<!doctype') ||
        normalized.startsWith('<html') ||
        normalized.startsWith('<body') ||
        normalized.startsWith('<div') ||
        normalized.startsWith('<p') ||
        normalized.startsWith('<span') ||
        normalized.startsWith('<script')) {
      return true;
    }

    return RegExp(r'^<[^>]+>').hasMatch(normalized);
  }

  bool _looksLikeEncodedHtmlFragment(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final decoded = Uri.decodeFull(normalized).trimLeft().toLowerCase();
    if (decoded.isEmpty) {
      return false;
    }

    return decoded.startsWith('<') ||
        decoded.contains('<div') ||
        decoded.contains('<html') ||
        decoded.contains('<body');
  }

  void _validateResolvedRequestUrl({
    required String requestUrl,
    required String sourceId,
  }) {
    final normalized = requestUrl.trim();
    final uri = Uri.tryParse(normalized);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    final isHttpUrl =
        uri != null && uri.hasScheme && (scheme == 'http' || scheme == 'https');
    if (isHttpUrl &&
        !_looksLikeHtmlFragment(normalized) &&
        !_looksLikeEncodedHtmlFragment(normalized)) {
      return;
    }

    throw AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.toc,
      sourceId: sourceId,
      briefMessage: '目录分页地址非法：$normalized',
    );
  }

  String? _resolveAbsoluteHttpUrl({
    required String pageUrl,
    required String rawUrl,
  }) {
    Uri? parsed = Uri.tryParse(rawUrl);

    if (parsed == null) {
      final encoded = Uri.encodeFull(rawUrl);
      parsed = Uri.tryParse(encoded);
      if (parsed == null) {
        return null;
      }
    }

    if (parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return null;
      }
      return parsed.toString();
    }

    final pageUri = Uri.tryParse(pageUrl);
    if (pageUri == null || !pageUri.hasScheme) {
      return null;
    }

    if (rawUrl.startsWith('//')) {
      return '${pageUri.scheme}:$rawUrl';
    }

    try {
      final resolved = pageUri.resolveUri(parsed);
      final scheme = resolved.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return null;
      }
      return resolved.toString();
    } on FormatException {
      return null;
    }
  }

  String? _resolveDetailRule(String? initRule, String? fieldRule) {
    if (fieldRule == null || fieldRule.trim().isEmpty) {
      return null;
    }

    final normalizedField = fieldRule.trim();
    if (initRule == null || initRule.trim().isEmpty) {
      return normalizedField;
    }

    if (!normalizedField.startsWith('json:') ||
        !initRule.startsWith('json:') ||
        normalizedField.contains('||') ||
        initRule.contains('||')) {
      return normalizedField;
    }

    final initExpression = initRule.substring(5).trim();
    final fieldExpression = normalizedField.substring(5).trim();
    return 'json:$initExpression\n$fieldExpression';
  }

  String? _resolveRuntimeRuleTemplate(
    String? expression,
    String baseUrl, {
    required SearchRequestContext context,
  }) {
    if (expression == null || expression.trim().isEmpty) {
      return expression;
    }

    var replaced = expression;

    replaced = replaced.replaceAllMapped(
      RegExp(
        "\\{\\{\\s*baseUrl\\.replace\\((['\"])(.+?)\\1\\s*,\\s*(['\"])(.+?)\\3\\)\\s*\\}\\}",
      ),
      (match) {
        final from = match.group(2) ?? '';
        final to = match.group(4) ?? '';
        return baseUrl.replaceAll(from, to);
      },
    );

    replaced = replaced.replaceAllMapped(
      RegExp(r'\{\{\s*baseUrl\.match\(/(.+?)\/\)\[(\d+)\]\s*\}\}'),
      (match) {
        final pattern = match.group(1) ?? '';
        final groupIndex = int.tryParse(match.group(2) ?? '0') ?? 0;

        try {
          final result = _matchBaseUrlPattern(
            baseUrl: baseUrl,
            pattern: pattern,
          );
          if (result == null || groupIndex > result.groupCount) {
            return '';
          }
          return result.group(groupIndex) ?? '';
        } on FormatException {
          return '';
        }
      },
    );

    final protected = _protectJsonPlaceholders(replaced);
    final resolved = _urlTemplateResolver.resolve(
      template: protected.template,
      context: context,
      encodeKeywordByDefault: false,
    );

    return _restoreProtectedPlaceholders(resolved, protected.placeholders);
  }

  _ProtectedTemplate _protectJsonPlaceholders(String expression) {
    var index = 0;
    final placeholders = <String, String>{};

    final template = expression.replaceAllMapped(
      RegExp(r'\{\{\s*\$[^}]*\}\}'),
      (match) {
        final marker = '__json_placeholder_${index}_';
        index += 1;
        placeholders[marker] = match.group(0)!;
        return marker;
      },
    );

    return _ProtectedTemplate(template: template, placeholders: placeholders);
  }

  String _restoreProtectedPlaceholders(
    String expression,
    Map<String, String> placeholders,
  ) {
    var restored = expression;
    for (final entry in placeholders.entries) {
      restored = restored.replaceAll(entry.key, entry.value);
    }
    return restored;
  }

  RegExpMatch? _matchBaseUrlPattern({
    required String baseUrl,
    required String pattern,
  }) {
    final tried = <String>{};
    final candidates = <String>[pattern];

    var normalized = pattern;
    const escapedSlash = r'\\';
    const slash = r'\';

    for (var i = 0; i < 3; i += 1) {
      final next = normalized
          .replaceAll(r'\/', '/')
          .replaceAll(escapedSlash, slash);
      if (next == normalized) {
        break;
      }
      candidates.add(next);
      normalized = next;
    }

    for (final candidate in candidates) {
      if (candidate.isEmpty || !tried.add(candidate)) {
        continue;
      }

      final regex = RegExp(candidate);
      final result = regex.firstMatch(baseUrl);
      if (result != null) {
        return result;
      }
    }

    return null;
  }

  List<String> _splitFallbackExpressions(String expression) {
    return expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  bool _looksLikeRequestRule(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) {
      return false;
    }

    if (_splitRequestOptions(text) != null) {
      return true;
    }

    if (text.startsWith('http://') || text.startsWith('https://')) {
      return true;
    }

    if (text.startsWith('//')) {
      return false;
    }

    if (text.startsWith('/')) {
      return true;
    }

    return false;
  }

  String _buildChapterDedupeKey({
    required String title,
    required String chapterUrl,
  }) {
    final normalizedTitle = title.trim().toLowerCase();
    final normalizedUrl = chapterUrl.trim();
    if (normalizedUrl.isNotEmpty) {
      return normalizedUrl;
    }
    return 'title:$normalizedTitle';
  }

  JsExecutionContext _buildDetailJsContext({
    required SourceDefinition source,
    required SearchRequestContext runtimeContext,
    required Map<String, dynamic> bookJson,
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
      stage: ErrorStage.detail,
      baseUrl: source.baseUrl,
      variables: variables,
      sourceJson: _buildSourceJsJson(source),
      bookJson: bookJson,
      jsLibScript: source.jsLib,
      onBridgePutVariables: collectPutVariables,
      onWebViewBridgeCall:
          (request) => _executeJsWebViewBridge(
            source: source,
            stage: ErrorStage.detail,
            request: request,
          ),
    );
  }

  Future<JsWebViewBridgeResponse> _executeJsWebViewBridge({
    required SourceDefinition source,
    required ErrorStage stage,
    required JsWebViewBridgeRequest request,
  }) async {
    final candidateUrl = request.url.trim();
    final fallbackUrl = source.baseUrl.trim();
    final targetUrl =
        candidateUrl.isNotEmpty
            ? candidateUrl
            : (fallbackUrl.isNotEmpty ? fallbackUrl : 'about:blank');
    final bridgeCall = request.bridgeCall.trim().toLowerCase();
    final webViewRequest = WebViewRequestPayload(
      url: targetUrl,
      headers: source.headers,
      html: request.html,
      webJs: request.js,
      sourceRegex: request.sourceRegex,
      overrideUrlRegex: request.overrideUrlRegex,
      stage: stage,
      sourceId: source.id,
    );

    WebViewResponsePayload response;
    if (bridgeCall == 'startbrowser' || bridgeCall == 'startbrowserawait') {
      try {
        response = await _interactiveVerificationExecutor.open(
          request: webViewRequest,
          awaitUserResult: bridgeCall == 'startbrowserawait',
          title: request.title,
          refetchAfterSuccess: request.refetchAfterSuccess ?? true,
        );
      } catch (error) {
        final allowFallback =
            error is StateError &&
            error.toString().contains('Navigator is unavailable');
        if (!allowFallback) {
          rethrow;
        }
        _logger.warn(
          'Interactive verification failed and fallback to headless WebView',
          context: <String, Object?>{
            'sourceId': source.id,
            'stage': stage.name,
            'bridgeCall': bridgeCall,
            'url': targetUrl,
            'briefMessage': error.toString(),
            'diagnostic': 'webview_interactive_fallback_headless',
          },
        );
        response = await _webViewExecutor.load(request: webViewRequest);
      }
    } else {
      response = await _webViewExecutor.load(request: webViewRequest);
    }

    return JsWebViewBridgeResponse(
      statusCode: response.statusCode,
      body: response.body,
      finalUrl: response.finalUrl,
      matchedResourceUrl: response.matchedResourceUrl,
      matchedOverrideUrl: response.matchedOverrideUrl,
      scriptResult: response.scriptResult,
    );
  }

  JsExecutionContext _buildChapterJsContext({
    required JsExecutionContext jsContext,
    required String bookId,
    required String chapterUrl,
    int? chapterIndex,
    String? chapterTitle,
  }) {
    return jsContext.copyWith(
      chapterJson: _buildChapterJsJson(
        bookId: bookId,
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
      ),
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

  Map<String, dynamic> _buildBookJsJson({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? title,
    String? author,
    String? intro,
    String? coverUrl,
    String? tocUrl,
  }) {
    final output = <String, dynamic>{
      'id': bookId,
      'bookId': bookId,
      'sourceId': sourceId,
      'detailUrl': detailUrl,
      'bookUrl': detailUrl,
      'url': detailUrl,
    };

    final normalizedTitle = title?.trim() ?? '';
    if (normalizedTitle.isNotEmpty) {
      output['title'] = normalizedTitle;
      output['name'] = normalizedTitle;
    }

    final normalizedAuthor = author?.trim() ?? '';
    if (normalizedAuthor.isNotEmpty) {
      output['author'] = normalizedAuthor;
    }

    final normalizedIntro = intro?.trim() ?? '';
    if (normalizedIntro.isNotEmpty) {
      output['intro'] = normalizedIntro;
    }

    final normalizedCover = coverUrl?.trim() ?? '';
    if (normalizedCover.isNotEmpty) {
      output['coverUrl'] = normalizedCover;
    }

    final normalizedToc = tocUrl?.trim() ?? '';
    if (normalizedToc.isNotEmpty) {
      output['tocUrl'] = normalizedToc;
    }

    return output;
  }

  Map<String, dynamic> _buildChapterJsJson({
    required String bookId,
    required String chapterUrl,
    int? chapterIndex,
    String? chapterTitle,
  }) {
    final output = <String, dynamic>{
      'bookId': bookId,
      'chapterUrl': chapterUrl,
      'url': chapterUrl,
    };

    if (chapterIndex != null) {
      output['index'] = chapterIndex;
    }

    final normalizedTitle = chapterTitle?.trim() ?? '';
    if (normalizedTitle.isNotEmpty) {
      output['title'] = normalizedTitle;
      output['name'] = normalizedTitle;
    }

    return output;
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

    final requestSpec = _parseRequestSpec(initParts.requestRule!);
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

  _SearchRequestSpec _parseRequestSpec(String rawRule) {
    final normalized = rawRule.trim();
    final parsedRule = UrlOptionParser.parseRule(normalized);
    if (parsedRule == null) {
      return _SearchRequestSpec(
        urlTemplate: normalized,
        method: HttpRequestMethod.get,
        maxRetries: 1,
      );
    }

    final option = parsedRule.options;

    return _SearchRequestSpec(
      urlTemplate: parsedRule.urlTemplate,
      method: option.method,
      bodyTemplate: _normalizeBodyTemplate(option.body),
      contentType: option.contentType,
      responseCharset: option.responseCharset,
      headers: option.headers,
      maxRetries: option.retry ?? 1,
      useWebView: option.webView,
      webViewDelay: option.webViewDelay,
      enabledCookieJar: option.enabledCookieJar ?? false,
      webJs: option.webJs,
      sourceRegex: option.sourceRegex,
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

  String _stripRequestOptions(String url) {
    final split = _splitRequestOptions(url.trim());
    return split?.urlTemplate ?? url.trim();
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
      resolved[entry.key] = _urlTemplateResolver.resolve(
        template: entry.value,
        context: context,
        encodeKeywordByDefault: false,
      );
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

      final text = value.toString().trim();
      if (text.isEmpty || path.isEmpty) {
        return;
      }

      result[path] = text;
      result['\$.$path'] = text;
    }

    walk(source, '');
    return result;
  }

  String? _normalizeLinkRuleExpression(
    String? rawRule, {
    required String fallbackExtractor,
    String? preferredAttribute,
  }) {
    final text = rawRule?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final containsJsonTemplate =
        text.contains(r'{{$.') ||
        text.contains(r'{{ $.') ||
        text.contains(r'{{\$.') ||
        text.contains(r'{{ \$.');

    if (_looksLikeRequestRule(text) && !containsJsonTemplate) {
      return text;
    }

    return _normalizeRuleExpression(
      text,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
  }

  String? _normalizeRuleExpression(
    String? rawRule, {
    required String fallbackExtractor,
    String? preferredAttribute,
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

    final jsonCandidate = _normalizeJsonShorthandExpression(staticRule);

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

  String _buildHashId(String prefix, String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    final text = hash.toRadixString(16).padLeft(8, '0');
    return '${prefix}_$text';
  }
}

class _ProtectedTemplate {
  const _ProtectedTemplate({
    required this.template,
    required this.placeholders,
  });

  final String template;
  final Map<String, String> placeholders;
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
    this.webViewDelay,
    this.enabledCookieJar = false,
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
  final Duration? webViewDelay;
  final bool enabledCookieJar;
  final String? webJs;
  final String? sourceRegex;
}

class _DetailParseRules {
  const _DetailParseRules({
    this.initRule,
    this.rawInitRule,
    this.titleRule,
    this.rawTitleRule,
    this.authorRule,
    this.rawAuthorRule,
    this.canRenameRule,
    this.rawCanRenameRule,
    this.introRule,
    this.rawIntroRule,
    this.coverUrlRule,
    this.rawCoverUrlRule,
    this.tocUrlRule,
    this.rawTocUrlRule,
  });

  final String? initRule;
  final String? rawInitRule;
  final String? titleRule;
  final String? rawTitleRule;
  final String? authorRule;
  final String? rawAuthorRule;
  final String? canRenameRule;
  final String? rawCanRenameRule;
  final String? introRule;
  final String? rawIntroRule;
  final String? coverUrlRule;
  final String? rawCoverUrlRule;
  final String? tocUrlRule;
  final String? rawTocUrlRule;
}

class _TocParseRules {
  const _TocParseRules({
    required this.listRule,
    required this.titleRule,
    required this.chapterUrlRule,
    required this.rawListRule,
    required this.rawTitleRule,
    required this.rawChapterUrlRule,
    this.nextUrlRule,
    this.rawNextUrlRule,
    required this.reversed,
  });

  final String listRule;
  final String titleRule;
  final String chapterUrlRule;
  final String? rawListRule;
  final String? rawTitleRule;
  final String? rawChapterUrlRule;
  final String? nextUrlRule;
  final String? rawNextUrlRule;
  final bool reversed;
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
