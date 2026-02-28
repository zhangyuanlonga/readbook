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
import '../../../core/rule_engine/processors/replace_regex_executor.dart';
import '../../../core/rule_engine/processors/source_js_variable_store.dart';
import '../../../core/source/source_response_processor.dart';
import '../../../core/webview/webview_executor.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/search_request_context.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import 'content_text_cleaner.dart';

class ChapterContentResult {
  const ChapterContentResult({
    required this.content,
    required this.fromCache,
    this.imageUrls = const [],
    this.imageHeaders = const {},
  });

  final String content;
  final bool fromCache;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;

  bool get isImageContent => imageUrls.isNotEmpty;
}

class ChapterContentService {
  ChapterContentService({
    AppDatabase? database,
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    WebViewExecutor? webViewExecutor,
    RuleEngine? ruleEngine,
    ContentTextCleaner? cleaner,
    ReplaceRegexExecutor? replaceRegexExecutor,
    AppLogger? logger,
    UrlTemplateResolver? urlTemplateResolver,
    SourceResponseProcessor? responseProcessor,
  }) : _database = database ?? AppDatabase.instance,
       _sourceRepository =
           sourceRepository ??
           SourceRepositoryImpl(database ?? AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _webViewExecutor = webViewExecutor ?? WebViewExecutor(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _cleaner = cleaner ?? const ContentTextCleaner(),
       _replaceRegexExecutor = replaceRegexExecutor ?? ReplaceRegexExecutor(),
       _logger = logger ?? AppLogger.instance,
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver(),
       _responseProcessor =
           responseProcessor ?? const SourceResponseProcessor();

  final AppDatabase _database;
  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final WebViewExecutor _webViewExecutor;
  final RuleEngine _ruleEngine;
  final ContentTextCleaner _cleaner;
  final ReplaceRegexExecutor _replaceRegexExecutor;
  final AppLogger _logger;
  final UrlTemplateResolver _urlTemplateResolver;
  final SourceResponseProcessor _responseProcessor;

  static final Map<String, String> _chapterCache = <String, String>{};
  static const String _imageCachePrefix = '__appread_image_payload__:';

  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
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

    final source = await _findSource(normalizedSourceId);
    final normalizedBookId = bookId?.trim() ?? '';
    final sourceVariableUpdates = <String, String>{};
    final bookVariableUpdates = <String, String>{};
    final runtimeJsVariables = <String, String>{
      ...SourceJsVariableStore.load(source),
      if (normalizedBookId.isNotEmpty)
        ...SourceJsVariableStore.loadBook(source, bookId: normalizedBookId),
    };

    void collectPutVariables(Map<String, String> variables) {
      if (variables.isEmpty) {
        return;
      }
      if (normalizedBookId.isEmpty) {
        sourceVariableUpdates.addAll(variables);
      } else {
        bookVariableUpdates.addAll(variables);
      }
      runtimeJsVariables.addAll(
        SourceJsVariableStore.toRuntimeVariables(variables),
      );
    }

    var contentRule = _normalizeRuleExpression(
      source.rules.contentRule,
      fallbackExtractor: 'html',
    );
    contentRule ??= _buildVariableExpressionFallback(source.rules.contentRule);
    contentRule ??= _buildFallbackContentRule(source.rules.contentDecryptRule);

    if (contentRule == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
        briefMessage: '书源缺少正文规则（ruleContent）。',
      );
    }

    final templateContext = SearchRequestContext(
      keyword: 'content',
      sourceId: normalizedSourceId,
      extraParams: {'chapterUrl': normalizedChapterUrl},
    );
    final initialJsContext = _buildContentJsContext(
      source: source,
      runtimeContext: templateContext,
      bookId: normalizedBookId,
      chapterUrl: normalizedChapterUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: collectPutVariables,
    );

    final initVariables = await _loadInitVariables(
      source: source,
      initRule: source.rules.contentInitRule,
      context: templateContext,
      jsContext: initialJsContext,
    );

    final runtimeContext =
        initVariables.isEmpty
            ? templateContext
            : templateContext.copyWith(
              extraParams: {...templateContext.extraParams, ...initVariables},
            );

    final normalizedChapterRequest = _normalizeChapterRequestInput(
      normalizedChapterUrl,
    );
    final requestSpec = _parseChapterRequestSpec(
      chapterUrl: normalizedChapterRequest,
    );
    final requestUrl = _resolveContentRequestUrl(
      source: source,
      template: requestSpec.urlTemplate,
      context: runtimeContext,
    );
    _validateResolvedRequestUrl(
      requestUrl: requestUrl,
      sourceId: normalizedSourceId,
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
      'Chapter content request',
      context: {
        'sourceId': normalizedSourceId,
        'sourceName': source.name,
        'chapterUrl': normalizedChapterUrl,
        'method': requestSpec.method.name,
        'url': requestUrl,
      },
    );

    final response = await _executeRequest(
      source: source,
      requestSpec: requestSpec,
      requestUrl: requestUrl,
      requestBody: requestBody,
      contentType: contentType,
      requestHeaders: requestHeaders,
      stage: ErrorStage.content,
      sourceId: normalizedSourceId,
    );

    final normalizedResponseBody =
        _responseProcessor
            .process(
              body: response.body,
              requestUrl: requestUrl,
              fallbackUrl: normalizedChapterUrl,
              decryptRule: source.rules.contentDecryptRule,
            )
            .body;

    final variableState = <String, String>{...runtimeContext.extraParams};
    final runtimeJsContext = _buildContentJsContext(
      source: source,
      runtimeContext: runtimeContext,
      bookId: normalizedBookId,
      chapterUrl: normalizedChapterUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      requestUrl: requestUrl,
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: collectPutVariables,
    );

    final contentExpression = _resolveRuntimeRuleTemplate(
      expression: contentRule,
      context: runtimeContext,
    );
    final resolvedContentExpression = await _resolveLegacyVariableExpression(
      content: normalizedResponseBody,
      expression: contentExpression,
      rawRule: source.rules.contentRule,
      stage: ErrorStage.content,
      variables: variableState,
      fallbackExtractor: 'html',
      jsContext: _mergeJsContextVariables(runtimeJsContext, variableState),
    );

    final extractedSegments =
        _looksLikeRuleExpression(resolvedContentExpression)
            ? await _executeAllWithFallback(
              content: normalizedResponseBody,
              expression: resolvedContentExpression,
              stage: ErrorStage.content,
              jsContext: _mergeJsContextVariables(
                runtimeJsContext,
                variableState,
              ),
            )
            : <String>[
              resolvedContentExpression.trim(),
            ].where((item) => item.isNotEmpty).toList(growable: false);

    final imageUrls = _extractImageUrls(
      extractedSegments: extractedSegments,
      responseBody: normalizedResponseBody,
      source: source,
      chapterUrl: normalizedChapterUrl,
    );
    final imageHeaders = _buildImageRequestHeaders(
      source: source,
      chapterUrl: normalizedChapterUrl,
      requestUrl: requestUrl,
      requestHeaders: requestHeaders,
    );

    if (extractedSegments.isEmpty && imageUrls.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '正文解析为空，请检查正文规则。',
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
      );
    }

    if (imageUrls.isNotEmpty) {
      final payload = _encodeImageCachePayload(
        imageUrls,
        imageHeaders: imageHeaders,
      );
      _chapterCache[cacheKey] = payload;

      if (normalizedBookId.isNotEmpty && chapterIndex != null) {
        try {
          await _database.upsertChapterCache(
            cacheKey: cacheKey,
            bookId: normalizedBookId,
            sourceId: normalizedSourceId,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            chapterUrl: normalizedChapterUrl,
            content: payload,
          );
        } catch (error) {
          _logger.warn(
            'Chapter cache persist failed',
            context: {
              'sourceId': normalizedSourceId,
              'chapterUrl': normalizedChapterUrl,
              'bookId': normalizedBookId,
              'error': error.toString(),
            },
          );
        }
      }

      await _persistJsVariables(
        source: source,
        bookId: normalizedBookId,
        sourceVariables: sourceVariableUpdates,
        bookVariables: bookVariableUpdates,
      );
      return ChapterContentResult(
        content: '',
        fromCache: false,
        imageUrls: imageUrls,
        imageHeaders: imageHeaders,
      );
    }

    final extracted = extractedSegments
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('\n\n');

    var cleaned = _cleaner.clean(extracted);
    cleaned = await _applyContentReplaceRegex(
      content: cleaned,
      source: source,
      sourceId: normalizedSourceId,
    );

    cleaned = await _appendNextContentPages(
      source: source,
      sourceId: normalizedSourceId,
      initialContent: cleaned,
      initialPageHtml: normalizedResponseBody,
      initialPageUrl: requestUrl,
      requestContext: runtimeContext,
      contentExpression: contentRule,
      variableState: variableState,
      runtimeJsVariables: runtimeJsVariables,
      bookId: normalizedBookId,
      chapterUrl: normalizedChapterUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      nextChapterUrl: nextChapterUrl,
      onBridgePutVariables: collectPutVariables,
    );

    if (cleaned.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '正文清洗后为空，请检查正文规则。',
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
      );
    }

    _chapterCache[cacheKey] = cleaned;

    if (normalizedBookId.isNotEmpty && chapterIndex != null) {
      try {
        await _database.upsertChapterCache(
          cacheKey: cacheKey,
          bookId: normalizedBookId,
          sourceId: normalizedSourceId,
          chapterIndex: chapterIndex,
          chapterTitle: chapterTitle,
          chapterUrl: normalizedChapterUrl,
          content: cleaned,
        );
      } catch (error) {
        _logger.warn(
          'Chapter cache persist failed',
          context: {
            'sourceId': normalizedSourceId,
            'chapterUrl': normalizedChapterUrl,
            'bookId': normalizedBookId,
            'error': error.toString(),
          },
        );
      }
    }

    await _persistJsVariables(
      source: source,
      bookId: normalizedBookId,
      sourceVariables: sourceVariableUpdates,
      bookVariables: bookVariableUpdates,
    );
    return ChapterContentResult(content: cleaned, fromCache: false);
  }

  Future<void> preload({
    required String sourceId,
    required List<String> chapterUrls,
  }) async {
    if (sourceId.trim().isEmpty || chapterUrls.isEmpty) {
      return;
    }

    for (final chapterUrl in chapterUrls) {
      if (chapterUrl.trim().isEmpty) {
        continue;
      }

      try {
        await load(sourceId: sourceId, chapterUrl: chapterUrl);
      } on AppException catch (error) {
        _logger.warn(
          'Chapter preload skipped',
          context: {
            'sourceId': sourceId,
            'chapterUrl': chapterUrl,
            'code': error.code.name,
            'message': error.briefMessage,
          },
        );
      } catch (error) {
        _logger.warn(
          'Chapter preload crashed',
          context: {
            'sourceId': sourceId,
            'chapterUrl': chapterUrl,
            'error': error.toString(),
          },
        );
      }
    }
  }

  Future<SourceDefinition> _findSource(String sourceId) async {
    final sources = await _sourceRepository.getAll();
    for (final source in sources) {
      if (source.id == sourceId) {
        return source;
      }
    }

    throw UnknownSourceException(
      briefMessage: '未找到书源：$sourceId',
      sourceId: sourceId,
      stage: ErrorStage.content,
    );
  }

  Future<void> _persistJsVariables({
    required SourceDefinition source,
    required String bookId,
    required Map<String, String> sourceVariables,
    required Map<String, String> bookVariables,
  }) async {
    await _persistSourceJsVariables(source: source, variables: sourceVariables);
    await _persistBookJsVariables(
      source: source,
      bookId: bookId,
      variables: bookVariables,
    );
  }

  Future<void> _persistSourceJsVariables({
    required SourceDefinition source,
    required Map<String, String> variables,
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
          'stage': ErrorStage.content.name,
          'error': error.toString(),
        },
      );
    }
  }

  Future<void> _persistBookJsVariables({
    required SourceDefinition source,
    required String bookId,
    required Map<String, String> variables,
  }) async {
    if (bookId.trim().isEmpty || variables.isEmpty) {
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
        'Persist book js variables failed',
        context: <String, Object?>{
          'sourceId': source.id,
          'sourceName': source.name,
          'bookId': bookId,
          'stage': ErrorStage.content.name,
          'error': error.toString(),
        },
      );
    }
  }

  Future<String> _applyContentReplaceRegex({
    required String content,
    required SourceDefinition source,
    required String sourceId,
  }) async {
    final replaceRule = source.rules.contentReplaceRegex?.trim();
    if (replaceRule == null || replaceRule.isEmpty || content.isEmpty) {
      return content;
    }
    return _replaceRegexExecutor.execute(
      content: content,
      replaceRegex: replaceRule,
      sourceId: sourceId,
    );
  }

  Future<String> _appendNextContentPages({
    required SourceDefinition source,
    required String sourceId,
    required String initialContent,
    required String initialPageHtml,
    required String initialPageUrl,
    required SearchRequestContext requestContext,
    required String contentExpression,
    required Map<String, String> variableState,
    required Map<String, String> runtimeJsVariables,
    required String bookId,
    required String chapterUrl,
    required int? chapterIndex,
    required String? chapterTitle,
    required String? nextChapterUrl,
    JsBridgePutCallback? onBridgePutVariables,
  }) async {
    final normalizedInitial = initialContent.trim();
    if (normalizedInitial.isEmpty) {
      return initialContent;
    }

    final rawNextRule = source.rules.contentNextUrlRule;
    final nextRuleExpression = _normalizeNextContentRuleExpression(rawNextRule);
    if (nextRuleExpression == null || nextRuleExpression.trim().isEmpty) {
      return initialContent;
    }

    final contentParts = <String>[normalizedInitial];
    final rollingVariables = <String, String>{...variableState};
    final visitedUrls = <String>{_stripRequestOptions(initialPageUrl)};
    var currentHtml = initialPageHtml;
    var currentUrl = initialPageUrl;
    const maxPages = 30;

    for (var page = 0; page < maxPages; page += 1) {
      final pageContext = requestContext.copyWith(
        extraParams: {
          ...requestContext.extraParams,
          ...rollingVariables,
          'chapterUrl': currentUrl,
        },
      );
      final pageJsContext = _buildContentJsContext(
        source: source,
        runtimeContext: pageContext,
        bookId: bookId,
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        requestUrl: currentUrl,
        seedVariables: runtimeJsVariables,
        onBridgePutVariables: onBridgePutVariables,
      );

      final nextUrl = await _extractNextContentUrl(
        sourceId: sourceId,
        pageHtml: currentHtml,
        pageUrl: currentUrl,
        context: pageContext,
        nextRuleExpression: nextRuleExpression,
        rawNextRule: rawNextRule,
        variables: rollingVariables,
        jsContext: _mergeJsContextVariables(pageJsContext, rollingVariables),
      );
      if (nextUrl == null || nextUrl.trim().isEmpty) {
        break;
      }
      if (_isNextChapterUrl(nextUrl: nextUrl, nextChapterUrl: nextChapterUrl)) {
        break;
      }

      final normalizedNextUrl = _stripRequestOptions(nextUrl);
      if (!visitedUrls.add(normalizedNextUrl)) {
        break;
      }

      final nextRequestInput = _normalizeChapterRequestInput(nextUrl);
      final nextSpec = _parseChapterRequestSpec(chapterUrl: nextRequestInput);
      final nextRequestContext = pageContext.copyWith(
        extraParams: {...pageContext.extraParams, 'chapterUrl': nextUrl},
      );
      final nextRequestUrl = _resolveContentRequestUrl(
        source: source,
        template: nextSpec.urlTemplate,
        context: nextRequestContext,
      );
      _validateResolvedRequestUrl(
        requestUrl: nextRequestUrl,
        sourceId: sourceId,
      );

      final nextContentType = _resolveContentType(nextSpec);
      final nextBody = _resolveBodyTemplate(
        nextSpec.bodyTemplate,
        context: nextRequestContext,
        encodeKeywordByDefault: _shouldEncodeKeywordInBody(
          bodyTemplate: nextSpec.bodyTemplate,
          contentType: nextContentType,
        ),
      );
      final nextHeaders = _resolveRequestHeaders(
        sourceHeaders: source.headers,
        requestHeaders: nextSpec.headers,
        context: nextRequestContext,
      );

      final nextResponse = await _executeRequest(
        source: source,
        requestSpec: nextSpec,
        requestUrl: nextRequestUrl,
        requestBody: nextBody,
        contentType: nextContentType,
        requestHeaders: nextHeaders,
        stage: ErrorStage.content,
        sourceId: sourceId,
      );
      final normalizedNextHtml =
          _responseProcessor
              .process(
                body: nextResponse.body,
                requestUrl: nextRequestUrl,
                fallbackUrl: nextUrl,
                decryptRule: source.rules.contentDecryptRule,
              )
              .body;

      final nextChunk = await _extractContentFromPage(
        source: source,
        sourceId: sourceId,
        content: normalizedNextHtml,
        contentExpression: contentExpression,
        context: nextRequestContext,
        variables: rollingVariables,
        bookId: bookId,
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        requestUrl: nextRequestUrl,
        runtimeJsVariables: runtimeJsVariables,
        onBridgePutVariables: onBridgePutVariables,
      );
      if (nextChunk.isEmpty) {
        break;
      }
      if (_isDuplicateContent(contentParts.last, nextChunk)) {
        break;
      }

      contentParts.add(nextChunk);
      currentHtml = normalizedNextHtml;
      currentUrl = nextRequestUrl;
    }

    variableState.addAll(rollingVariables);
    return contentParts.join('\n\n');
  }

  Future<String?> _extractNextContentUrl({
    required String sourceId,
    required String pageHtml,
    required String pageUrl,
    required SearchRequestContext context,
    required String nextRuleExpression,
    required String? rawNextRule,
    required Map<String, String> variables,
    JsExecutionContext? jsContext,
  }) async {
    final resolvedExpression = _resolveRuntimeRuleTemplate(
      expression: nextRuleExpression,
      context: context,
    );

    String? nextRaw;
    if (_looksLikeRequestRule(resolvedExpression)) {
      nextRaw = resolvedExpression;
    } else {
      final resolvedValue = await _resolveLegacyVariableExpression(
        content: pageHtml,
        expression: resolvedExpression,
        rawRule: rawNextRule,
        stage: ErrorStage.content,
        variables: variables,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
        jsContext: _mergeJsContextVariables(jsContext, variables),
      );
      if (_looksLikeRuleExpression(resolvedValue)) {
        final candidates = await _executeAllWithFallback(
          content: pageHtml,
          expression: resolvedValue,
          stage: ErrorStage.content,
          jsContext: _mergeJsContextVariables(jsContext, variables),
        );
        if (candidates.isNotEmpty) {
          nextRaw = candidates.first.trim();
        }
      } else {
        nextRaw = resolvedValue.trim();
      }
    }

    if (nextRaw == null || nextRaw.trim().isEmpty) {
      return null;
    }

    final shouldBypassPostProcess =
        nextRuleExpression == LegacyScriptRuleFallback.fieldExpression ||
        nextRuleExpression.startsWith('js:') ||
        nextRuleExpression.startsWith('@js:');
    final nextValue =
        shouldBypassPostProcess
            ? nextRaw.trim()
            : LegacyLinkPostProcessor.apply(
              value: nextRaw,
              rawRule: rawNextRule,
            );
    if (nextValue.trim().isEmpty) {
      return null;
    }

    final resolvedUrl = _resolveMaybeUrl(pageUrl: pageUrl, rawUrl: nextValue);
    if (resolvedUrl == null || resolvedUrl.trim().isEmpty) {
      return null;
    }
    _validateResolvedRequestUrl(requestUrl: resolvedUrl, sourceId: sourceId);
    return resolvedUrl;
  }

  Future<String> _extractContentFromPage({
    required SourceDefinition source,
    required String sourceId,
    required String content,
    required String contentExpression,
    required SearchRequestContext context,
    required Map<String, String> variables,
    required String bookId,
    required String chapterUrl,
    required int? chapterIndex,
    required String? chapterTitle,
    required String requestUrl,
    required Map<String, String> runtimeJsVariables,
    JsBridgePutCallback? onBridgePutVariables,
  }) async {
    final runtimeJsContext = _buildContentJsContext(
      source: source,
      runtimeContext: context,
      bookId: bookId,
      chapterUrl: chapterUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      requestUrl: requestUrl,
      seedVariables: runtimeJsVariables,
      onBridgePutVariables: onBridgePutVariables,
    );
    final contentRule = _resolveRuntimeRuleTemplate(
      expression: contentExpression,
      context: context,
    );
    final resolvedContentExpression = await _resolveLegacyVariableExpression(
      content: content,
      expression: contentRule,
      rawRule: source.rules.contentRule,
      stage: ErrorStage.content,
      variables: variables,
      fallbackExtractor: 'html',
      jsContext: _mergeJsContextVariables(runtimeJsContext, variables),
    );
    final extractedSegments =
        _looksLikeRuleExpression(resolvedContentExpression)
            ? await _executeAllWithFallback(
              content: content,
              expression: resolvedContentExpression,
              stage: ErrorStage.content,
              jsContext: _mergeJsContextVariables(runtimeJsContext, variables),
            )
            : <String>[
              resolvedContentExpression.trim(),
            ].where((item) => item.isNotEmpty).toList(growable: false);
    if (extractedSegments.isEmpty) {
      return '';
    }

    final rawContent = extractedSegments
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('\n\n');
    if (rawContent.isEmpty) {
      return '';
    }

    final cleaned = _cleaner.clean(rawContent);
    return _applyContentReplaceRegex(
      content: cleaned,
      source: source,
      sourceId: sourceId,
    );
  }

  String _normalizeChapterRequestInput(String chapterUrl) {
    final normalized = LegacyLinkPostProcessor.apply(value: chapterUrl);
    final candidate =
        normalized.trim().isEmpty ? chapterUrl.trim() : normalized;

    if (LegacyScriptRuleFallback.isScriptOnlyRule(candidate)) {
      final evaluated = LegacyScriptRuleFallback.evaluateFieldValue(
        content: '',
        rawRule: candidate,
      );
      if (evaluated != null && evaluated.trim().isNotEmpty) {
        return evaluated;
      }
    }

    return candidate;
  }

  String? _normalizeNextContentRuleExpression(String? rawRule) {
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
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
    );
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
    return lower.startsWith('javascript:') ||
        lower.startsWith('about:blank') ||
        lower.startsWith('data:') ||
        lower.startsWith('mailto:') ||
        lower == '#' ||
        lower.startsWith('#');
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

  String _stripRequestOptions(String url) {
    final split = _splitRequestOptions(url.trim());
    return split?.urlTemplate ?? url.trim();
  }

  bool _isNextChapterUrl({required String nextUrl, String? nextChapterUrl}) {
    final normalizedNext = _stripRequestOptions(nextUrl);
    final normalizedChapter = _stripRequestOptions(
      nextChapterUrl?.trim() ?? '',
    );
    if (normalizedChapter.isEmpty) {
      return false;
    }
    return normalizedNext == normalizedChapter;
  }

  bool _isDuplicateContent(String lastPart, String nextPart) {
    final normalizedLast = _normalizeContentForDuplicate(lastPart);
    final normalizedNext = _normalizeContentForDuplicate(nextPart);
    if (normalizedLast.isEmpty || normalizedNext.isEmpty) {
      return false;
    }
    if (normalizedLast == normalizedNext) {
      return true;
    }
    return normalizedLast.contains(normalizedNext) ||
        normalizedNext.contains(normalizedLast);
  }

  String _normalizeContentForDuplicate(String content) {
    return content.replaceAll(RegExp(r'\s+'), '').trim();
  }

  String _resolveContentRequestUrl({
    required SourceDefinition source,
    required String template,
    required SearchRequestContext context,
  }) {
    try {
      return _urlTemplateResolver.resolve(
        template: template,
        context: context,
        baseUrl: source.baseUrl,
      );
    } on AppException catch (error, stackTrace) {
      throw AppException(
        code: error.code,
        stage: ErrorStage.content,
        sourceId: source.id,
        briefMessage: error.briefMessage,
        requestUrl: error.requestUrl,
        cause: error,
        stackTrace: stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        sourceId: source.id,
        briefMessage: '正文请求地址非法：${template.trim()}',
        cause: error,
        stackTrace: stackTrace,
      );
    }
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
      stage: ErrorStage.content,
      sourceId: sourceId,
      briefMessage: '正文请求地址非法：$normalized',
    );
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

  _ContentRequestSpec _parseChapterRequestSpec({required String chapterUrl}) {
    final normalized = chapterUrl.trim();
    final parsedRule = UrlOptionParser.parseRule(normalized);
    if (parsedRule == null) {
      return _ContentRequestSpec(
        urlTemplate: normalized,
        method: HttpRequestMethod.get,
        maxRetries: 1,
      );
    }

    final option = parsedRule.options;

    return _ContentRequestSpec(
      urlTemplate: parsedRule.urlTemplate,
      method: option.method,
      headers: option.headers,
      bodyTemplate: _normalizeBodyTemplate(option.body),
      contentType: option.contentType,
      responseCharset: option.responseCharset,
      maxRetries: option.retry ?? 1,
      useWebView: option.webView,
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
        text.startsWith('/');
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

  JsExecutionContext _buildContentJsContext({
    required SourceDefinition source,
    required SearchRequestContext runtimeContext,
    required String bookId,
    required String chapterUrl,
    int? chapterIndex,
    String? chapterTitle,
    String? requestUrl,
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
      bookJson: _buildBookJsJson(sourceId: source.id, bookId: bookId),
      chapterJson: _buildChapterJsJson(
        bookId: bookId,
        chapterUrl: chapterUrl,
        chapterIndex: chapterIndex,
        chapterTitle: chapterTitle,
        requestUrl: requestUrl,
      ),
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

  Map<String, dynamic> _buildBookJsJson({
    required String sourceId,
    required String bookId,
  }) {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return <String, dynamic>{'sourceId': sourceId};
    }

    return <String, dynamic>{
      'id': normalizedBookId,
      'bookId': normalizedBookId,
      'sourceId': sourceId,
    };
  }

  Map<String, dynamic> _buildChapterJsJson({
    required String bookId,
    required String chapterUrl,
    int? chapterIndex,
    String? chapterTitle,
    String? requestUrl,
  }) {
    final payload = <String, dynamic>{
      'bookId': bookId.trim(),
      'chapterUrl': chapterUrl,
      'url': chapterUrl,
    };

    final normalizedRequest = requestUrl?.trim() ?? '';
    if (normalizedRequest.isNotEmpty) {
      payload['requestUrl'] = normalizedRequest;
    }

    if (chapterIndex != null) {
      payload['index'] = chapterIndex;
    }

    final normalizedTitle = chapterTitle?.trim() ?? '';
    if (normalizedTitle.isNotEmpty) {
      payload['title'] = normalizedTitle;
      payload['name'] = normalizedTitle;
    }

    return payload;
  }

  Future<Map<String, String>> _loadInitVariables({
    required SourceDefinition source,
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

    final requestSpec = _parseChapterRequestSpec(
      chapterUrl: initParts.requestRule!,
    );
    final requestUrl = _resolveContentRequestUrl(
      source: source,
      template: requestSpec.urlTemplate,
      context: context,
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
      requestSpec: requestSpec,
      requestUrl: requestUrl,
      requestBody: requestBody,
      contentType: contentType,
      requestHeaders: requestHeaders,
      stage: ErrorStage.content,
      sourceId: source.id,
    );

    final normalizedInitBody =
        _responseProcessor
            .process(
              body: response.body,
              requestUrl: requestUrl,
              fallbackUrl: initParts.requestRule,
              decryptRule: source.rules.contentDecryptRule,
            )
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
            stage: ErrorStage.content,
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

  Future<_NetworkLoadResult> _executeRequest({
    required SourceDefinition source,
    required _ContentRequestSpec requestSpec,
    required String requestUrl,
    required Object? requestBody,
    required String? contentType,
    required Map<String, String> requestHeaders,
    required ErrorStage stage,
    required String sourceId,
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
            sourceId: sourceId,
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
            'sourceId': sourceId,
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
        stage: stage,
        sourceId: sourceId,
        sourceConcurrentRate: source.concurrentRate,
      ),
    );
    return _NetworkLoadResult(
      statusCode: response.statusCode,
      body: response.body,
    );
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

  String? _resolveContentType(_ContentRequestSpec requestSpec) {
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

  String? _buildFallbackContentRule(String? decryptRule) {
    final normalized = decryptRule?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    return r'regex:[\s\S]+';
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

  List<String> _extractImageUrls({
    required List<String> extractedSegments,
    required String responseBody,
    required SourceDefinition source,
    required String chapterUrl,
  }) {
    final urls = <String>[];

    void addUrl(String? value) {
      final normalized = _normalizeImageUrl(
        value,
        baseUrl: source.baseUrl,
        chapterUrl: chapterUrl,
      );
      if (normalized == null) {
        return;
      }
      if (!urls.contains(normalized)) {
        urls.add(normalized);
      }
    }

    final imageRuleHint =
        source.sourceType == 2 ||
        (source.rules.contentRule?.toLowerCase().contains('@src') ?? false);

    for (final segment in extractedSegments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (_looksLikeImageUrl(trimmed)) {
        addUrl(trimmed);
        continue;
      }

      if (_looksLikeJsonPayload(trimmed)) {
        _extractImageUrlsFromJsonBlob(trimmed, addUrl);
      }

      for (final match in _extractImageUrlRegex(trimmed)) {
        addUrl(match);
      }
    }

    if (urls.isNotEmpty || !imageRuleHint) {
      return List.unmodifiable(urls);
    }

    if (_looksLikeJsonPayload(responseBody)) {
      _extractImageUrlsFromJsonBlob(responseBody, addUrl);
    }

    for (final match in _extractImageUrlRegex(responseBody)) {
      addUrl(match);
    }

    return List.unmodifiable(urls);
  }

  Iterable<String> _extractImageUrlRegex(String source) sync* {
    const imageExt = '(?:jpg|jpeg|png|webp|gif|bmp|avif)';

    final imageAttrPattern = RegExp(
      "<img[^>]+(?:src|data-src|data-original|data-lazy|data-echo)\\s*=\\s*['\"]([^'\"]+)['\"]",
      caseSensitive: false,
    );
    for (final match in imageAttrPattern.allMatches(source)) {
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        yield value;
      }
    }

    final srcsetPattern = RegExp(
      "<img[^>]+srcset\\s*=\\s*['\"]([^'\"]+)['\"]",
      caseSensitive: false,
    );
    for (final match in srcsetPattern.allMatches(source)) {
      final srcset = match.group(1)?.trim();
      if (srcset == null || srcset.isEmpty) {
        continue;
      }
      for (final candidate in _extractFromSrcset(srcset)) {
        yield candidate;
      }
    }

    final styleBackgroundPattern = RegExp(
      "background-image\\s*:\\s*url\\(([^)]+)\\)",
      caseSensitive: false,
    );
    for (final match in styleBackgroundPattern.allMatches(source)) {
      final value = match.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        yield value;
      }
    }

    final patterns = <RegExp>[
      RegExp(
        "https?://[^\\s'\"]+\\.(?:$imageExt)(?:\\?[^\\s'\"]*)?",
        caseSensitive: false,
      ),
      RegExp(
        "//[^\\s'\"]+\\.(?:$imageExt)(?:\\?[^\\s'\"]*)?",
        caseSensitive: false,
      ),
      RegExp(
        "['\"]((?:\\/|/)[^'\"]+\\.(?:$imageExt)(?:\\?[^'\"]*)?)['\"]",
        caseSensitive: false,
      ),
      RegExp(
        "['\"]((?:https?:)?\\/\\/[^'\"]+\\.(?:$imageExt)(?:\\?[^'\"]*)?)['\"]",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      for (final match in pattern.allMatches(source)) {
        final value = match.groupCount > 0 ? match.group(1) : match.group(0);
        final normalized = value?.trim();
        if (normalized != null && normalized.isNotEmpty) {
          yield normalized;
        }
      }
    }
  }

  Iterable<String> _extractFromSrcset(String srcset) sync* {
    final candidates = srcset.split(',');
    for (final candidate in candidates) {
      final normalized = candidate.trim();
      if (normalized.isEmpty) {
        continue;
      }

      final pieces = normalized.split(RegExp(r'\s+'));
      if (pieces.isNotEmpty && pieces.first.trim().isNotEmpty) {
        yield pieces.first.trim();
      }
    }
  }

  bool _looksLikeJsonPayload(String source) {
    final trimmed = source.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  void _extractImageUrlsFromJsonBlob(
    String source,
    void Function(String? value) addUrl,
  ) {
    final decoded = _tryDecodeJson(source);
    if (decoded != null) {
      _collectImageUrlsFromJsonValue(decoded, addUrl);
      return;
    }

    final embeddedPayloadPatterns = <RegExp>[RegExp(r'([\[{][\s\S]*[\]}])')];

    for (final pattern in embeddedPayloadPatterns) {
      for (final match in pattern.allMatches(source)) {
        final candidate = match.group(1)?.trim();
        if (candidate == null || candidate.isEmpty) {
          continue;
        }
        final embedded = _tryDecodeJson(candidate);
        if (embedded != null) {
          _collectImageUrlsFromJsonValue(embedded, addUrl);
        }
      }
    }
  }

  void _collectImageUrlsFromJsonValue(
    dynamic value,
    void Function(String? value) addUrl,
  ) {
    if (value == null) {
      return;
    }

    if (value is List) {
      for (final item in value) {
        _collectImageUrlsFromJsonValue(item, addUrl);
      }
      return;
    }

    if (value is Map) {
      for (final item in value.values) {
        _collectImageUrlsFromJsonValue(item, addUrl);
      }
      return;
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return;
    }

    if (_looksLikeImageUrl(text)) {
      addUrl(text);
      return;
    }

    for (final match in _extractImageUrlRegex(text)) {
      addUrl(match);
    }
  }

  bool _looksLikeImageUrl(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('data:image/')) {
      return true;
    }

    return normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.png') ||
        normalized.contains('.webp') ||
        normalized.contains('.gif') ||
        normalized.contains('.bmp') ||
        normalized.contains('.avif');
  }

  String? _normalizeImageUrl(
    String? value, {
    required String baseUrl,
    required String chapterUrl,
  }) {
    final normalized = _normalizeImageCandidate(value);
    if (normalized == null) {
      return null;
    }

    if (normalized.startsWith('data:image/')) {
      return normalized;
    }

    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();
      if (scheme == 'http' || scheme == 'https') {
        return uri.toString();
      }
      return null;
    }

    if (normalized.startsWith('//')) {
      return 'https:$normalized';
    }

    final chapterRequest = _splitRequestOptions(chapterUrl);
    final chapterTemplate = chapterRequest?.urlTemplate ?? chapterUrl;
    final chapterUri = Uri.tryParse(chapterTemplate);
    if (chapterUri != null && chapterUri.hasScheme) {
      return chapterUri.resolve(normalized).toString();
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri != null && baseUri.hasScheme) {
      return baseUri.resolve(normalized).toString();
    }

    return null;
  }

  String? _normalizeImageCandidate(String? value) {
    var normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    normalized = normalized.replaceAll(r'\/', '/').replaceAll('&amp;', '&');

    if (normalized.startsWith('url(') && normalized.endsWith(')')) {
      normalized = normalized.substring(4, normalized.length - 1).trim();
    }

    if ((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }

    if (normalized.isEmpty ||
        normalized.startsWith('javascript:') ||
        normalized.startsWith('about:blank') ||
        normalized == '#') {
      return null;
    }

    final srcsetParts = normalized.split(RegExp(r'\s+'));
    if (srcsetParts.length > 1 && _looksLikeImageUrl(srcsetParts.first)) {
      normalized = srcsetParts.first;
    }

    return normalized;
  }

  Map<String, String> _buildImageRequestHeaders({
    required SourceDefinition source,
    required String chapterUrl,
    required String requestUrl,
    required Map<String, String> requestHeaders,
  }) {
    final mergedHeaders = <String, String>{
      ...source.headers,
      ...requestHeaders,
    };

    final referer =
        _sanitizeHeaderUrl(_readHeaderIgnoreCase(mergedHeaders, 'referer')) ??
        _sanitizeHeaderUrl(requestUrl) ??
        _sanitizeHeaderUrl(chapterUrl) ??
        _sanitizeHeaderUrl(source.baseUrl);

    final origin =
        _sanitizeOrigin(_readHeaderIgnoreCase(mergedHeaders, 'origin')) ??
        _deriveOrigin(referer) ??
        _deriveOrigin(source.baseUrl);

    final userAgent =
        _readHeaderIgnoreCase(mergedHeaders, 'user-agent')?.trim() ??
        'flutter_appread/0.1';

    final imageHeaders = <String, String>{'User-Agent': userAgent};
    if (referer != null) {
      imageHeaders['Referer'] = referer;
    }
    if (origin != null) {
      imageHeaders['Origin'] = origin;
    }

    return imageHeaders;
  }

  String? _readHeaderIgnoreCase(Map<String, String> headers, String key) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) {
        final value = entry.value.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  String? _sanitizeHeaderUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final requestSpec = _splitRequestOptions(normalized);
    final urlPart = requestSpec?.urlTemplate.trim() ?? normalized;

    final uri = Uri.tryParse(urlPart);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    return uri.toString();
  }

  String? _sanitizeOrigin(String? value) {
    final uriValue = _sanitizeHeaderUrl(value);
    return _deriveOrigin(uriValue);
  }

  String? _deriveOrigin(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }

    return uri.origin;
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

  Future<List<String>> _executeAllWithFallback({
    required String content,
    required String expression,
    required ErrorStage stage,
    JsExecutionContext? jsContext,
  }) async {
    for (final candidate in _splitFallbackExpressions(expression)) {
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
      } on AppException catch (error) {
        if (candidate.startsWith('json:') && error.code == ErrorCode.decode) {
          final repaired = _repairJsonControlCharacters(content);
          if (repaired != content) {
            try {
              final repairedValues = await _ruleEngine.executeAll(
                content: repaired,
                expression: candidate,
                stage: stage,
                jsContext: jsContext,
              );
              if (repairedValues.isNotEmpty) {
                return repairedValues;
              }
            } on AppException {
              // Keep fallback flow and try next candidate.
            }
          }
        }

        continue;
      }
    }

    return const [];
  }

  Future<String> _resolveLegacyVariableExpression({
    required String content,
    required String expression,
    required ErrorStage stage,
    required Map<String, String> variables,
    required String fallbackExtractor,
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
                (valueExpression) => _evaluateLegacyPutValue(
                  content: content,
                  stage: stage,
                  valueExpression: valueExpression,
                  fallbackExtractor: fallbackExtractor,
                  preferredAttribute: preferredAttribute,
                  jsContext: _mergeJsContextVariables(jsContext, variables),
                ),
          );

      final rawLiteral = resolvedRaw.trim();
      if (rawLiteral.isNotEmpty && !_looksLikeRuleExpression(rawLiteral)) {
        return rawLiteral;
      }

      final normalizedRaw = _normalizeRuleExpression(
        resolvedRaw,
        fallbackExtractor: fallbackExtractor,
        preferredAttribute: preferredAttribute,
      );
      if (normalizedRaw != null && normalizedRaw.trim().isNotEmpty) {
        return LegacyRuleVariableProcessor.replaceGetTokens(
          normalizedRaw,
          variables,
        );
      }
    }

    return LegacyRuleVariableProcessor.replaceGetTokens(expression, variables);
  }

  Future<String?> _evaluateLegacyPutValue({
    required String content,
    required ErrorStage stage,
    required String valueExpression,
    required String fallbackExtractor,
    String? preferredAttribute,
    JsExecutionContext? jsContext,
  }) async {
    final normalizedRule = _normalizeRuleExpression(
      valueExpression,
      fallbackExtractor: fallbackExtractor,
      preferredAttribute: preferredAttribute,
    );
    if (normalizedRule != null && normalizedRule.trim().isNotEmpty) {
      final values = await _executeAllWithFallback(
        content: content,
        expression: normalizedRule,
        stage: stage,
        jsContext: jsContext,
      );
      if (values.isNotEmpty) {
        return values.first.trim();
      }
    }

    final literal = valueExpression.trim();
    if (literal.isEmpty || _looksLikeRuleExpression(literal)) {
      return null;
    }
    return literal;
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

    if (text.contains('@') ||
        text.contains('##') ||
        text.contains('||') ||
        text.contains('&&') ||
        text.contains('%%') ||
        text.contains('{{@@') ||
        text.contains('{{@css:') ||
        text.contains('{{@json:') ||
        text.contains('{{@xpath:') ||
        text.contains('{{@js:')) {
      return true;
    }

    return false;
  }

  String _repairJsonControlCharacters(String source) {
    final buffer = StringBuffer();
    var inString = false;
    var escaped = false;

    for (var index = 0; index < source.length; index += 1) {
      final char = source[index];

      if (inString) {
        if (escaped) {
          buffer.write(char);
          escaped = false;
          continue;
        }

        if (char == r'\') {
          buffer.write(char);
          escaped = true;
          continue;
        }

        if (char == '"') {
          buffer.write(char);
          inString = false;
          continue;
        }

        if (char == '\n') {
          buffer.write(r'\n');
          continue;
        }

        if (char == '\r') {
          buffer.write(r'\r');
          continue;
        }

        if (char == '\t') {
          buffer.write(r'\t');
          continue;
        }

        buffer.write(char);
        continue;
      }

      if (char == '"') {
        inString = true;
      }

      buffer.write(char);
    }

    return buffer.toString();
  }

  List<String> _splitFallbackExpressions(String expression) {
    return expression
        .split('||')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _resolveRuntimeRuleTemplate({
    required String expression,
    required SearchRequestContext context,
  }) {
    final baseUrl = context.extraParams['chapterUrl'] ?? '';

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

    if (staticRule.contains('{{@@') ||
        staticRule.contains('{{@css:') ||
        staticRule.contains('{{@json:') ||
        staticRule.contains('{{@xpath:') ||
        staticRule.contains('{{@js:')) {
      return staticRule;
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
}

class _ProtectedTemplate {
  const _ProtectedTemplate({
    required this.template,
    required this.placeholders,
  });

  final String template;
  final Map<String, String> placeholders;
}

class _DecodedChapterCache {
  const _DecodedChapterCache({
    required this.content,
    this.imageUrls = const [],
    this.imageHeaders = const {},
  });

  final String content;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
}

class _RequestRuleSplit {
  const _RequestRuleSplit({
    required this.urlTemplate,
    required this.optionsText,
  });

  final String urlTemplate;
  final String optionsText;
}

class _NetworkLoadResult {
  const _NetworkLoadResult({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

class _ContentRequestSpec {
  const _ContentRequestSpec({
    required this.urlTemplate,
    required this.method,
    this.headers = const {},
    this.bodyTemplate,
    this.contentType,
    this.responseCharset,
    this.maxRetries = 1,
    this.useWebView = false,
    this.webJs,
    this.sourceRegex,
  });

  final String urlTemplate;
  final HttpRequestMethod method;
  final Map<String, String> headers;
  final Object? bodyTemplate;
  final String? contentType;
  final String? responseCharset;
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
