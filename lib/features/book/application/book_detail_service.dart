import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/request_context.dart';
import '../../../core/rule_engine/rule_engine.dart';
import '../../../core/rule_engine/processors/url_template_resolver.dart';
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
  });

  final BookDetail detail;
  final List<Chapter> chapters;
  final String sourceName;
  final bool tocFromCache;
}

class BookDetailService {
  BookDetailService({
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    AppLogger? logger,
    RuleEngine? ruleEngine,
    UrlTemplateResolver? urlTemplateResolver,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _logger = logger ?? AppLogger.instance,
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver();

  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final AppLogger _logger;
  final RuleEngine _ruleEngine;
  final UrlTemplateResolver _urlTemplateResolver;

  static final Map<String, List<Chapter>> _tocCache = <String, List<Chapter>>{};

  Future<BookDetailLoadResult> load({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    bool forceRefresh = false,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final normalizedBookId = bookId.trim();
    final normalizedDetailUrl = detailUrl.trim();

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
    final detailUri = Uri.tryParse(normalizedDetailUrl);
    if (detailUri == null || !detailUri.hasScheme) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        sourceId: normalizedSourceId,
        briefMessage: '详情地址非法：$normalizedDetailUrl',
      );
    }

    final baseKeyword =
        fallbackTitle?.trim().isNotEmpty == true
            ? fallbackTitle!.trim()
            : 'detail';
    final templateContext = SearchRequestContext(
      keyword: baseKeyword,
      sourceId: normalizedSourceId,
      extraParams: {'detailUrl': normalizedDetailUrl},
    );

    final detailInitVariables = await _loadInitVariables(
      source: source,
      stage: ErrorStage.detail,
      initRule: source.rules.detailInitRule,
      context: templateContext,
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

    final detailRules = _buildDetailRules(source);

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

    final title =
        _extractOptionalValue(
          content: detailHtml,
          expression: titleRule,
          stage: ErrorStage.detail,
        ) ??
        (fallbackTitle?.trim().isNotEmpty == true
            ? fallbackTitle!.trim()
            : '未命名书籍');

    final cover = _resolveMaybeUrl(
      pageUrl: normalizedDetailUrl,
      rawUrl: _extractOptionalValue(
        content: detailHtml,
        expression: coverRule,
        stage: ErrorStage.detail,
      ),
    );

    final extractedTocUrl = _extractOptionalValue(
      content: detailHtml,
      expression: tocUrlRule,
      stage: ErrorStage.detail,
    );

    final tocCandidate =
        extractedTocUrl ??
        (_looksLikeRequestRule(tocUrlRule) ? tocUrlRule : null);

    var tocUrl = _resolveMaybeUrl(
      pageUrl: normalizedDetailUrl,
      rawUrl: tocCandidate,
    );

    if (tocUrl == null || tocUrl.isEmpty) {
      tocUrl = normalizedDetailUrl;
    }

    final detail = BookDetail(
      id: normalizedBookId,
      sourceId: normalizedSourceId,
      title: title,
      detailUrl: normalizedDetailUrl,
      author: _extractOptionalValue(
        content: detailHtml,
        expression: authorRule,
        stage: ErrorStage.detail,
      ),
      intro: _extractOptionalValue(
        content: detailHtml,
        expression: introRule,
        stage: ErrorStage.detail,
      ),
      coverUrl: cover,
      tocUrl: tocUrl,
    );

    final tocCacheKey = '$normalizedSourceId|$normalizedDetailUrl';
    if (!forceRefresh && _tocCache.containsKey(tocCacheKey)) {
      final cached = _tocCache[tocCacheKey]!;
      return BookDetailLoadResult(
        detail: detail,
        chapters: List.unmodifiable(cached),
        sourceName: source.name,
        tocFromCache: true,
      );
    }

    final tocRules = _buildTocRules(source);
    if (tocRules == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.toc,
        sourceId: normalizedSourceId,
        briefMessage: '书源缺少目录规则（chapterList/chapterName/chapterUrl）。',
      );
    }

    var chapters = _parseChapters(
      html: detailHtml,
      pageUrl: normalizedDetailUrl,
      rules: tocRules,
      sourceId: normalizedSourceId,
      bookId: normalizedBookId,
      context: runtimeContext,
    );

    if (chapters.isEmpty && tocUrl != normalizedDetailUrl) {
      final tocHtml = await _fetchHtml(
        source: source,
        stage: ErrorStage.toc,
        url: tocUrl,
        context: runtimeContext,
      );
      chapters = _parseChapters(
        html: tocHtml,
        pageUrl: tocUrl,
        rules: tocRules,
        sourceId: normalizedSourceId,
        bookId: normalizedBookId,
        context: runtimeContext,
      );
    }

    if (chapters.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '目录解析为空，请检查书源规则。',
        sourceId: normalizedSourceId,
        stage: ErrorStage.toc,
        requestUrl: tocUrl,
      );
    }

    _tocCache[tocCacheKey] = chapters;

    return BookDetailLoadResult(
      detail: detail,
      chapters: chapters,
      sourceName: source.name,
      tocFromCache: false,
    );
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

    return response.body;
  }

  _DetailParseRules _buildDetailRules(SourceDefinition source) {
    return _DetailParseRules(
      initRule: _normalizeRuleExpression(
        source.rules.detailRule,
        fallbackExtractor: 'html',
      ),
      titleRule: _normalizeRuleExpression(
        source.rules.detailTitleRule,
        fallbackExtractor: 'text',
      ),
      authorRule: _normalizeRuleExpression(
        source.rules.detailAuthorRule,
        fallbackExtractor: 'text',
      ),
      introRule: _normalizeRuleExpression(
        source.rules.detailIntroRule,
        fallbackExtractor: 'text',
      ),
      coverUrlRule: _normalizeRuleExpression(
        source.rules.detailCoverUrlRule,
        fallbackExtractor: 'attr(src)',
        preferredAttribute: 'src',
      ),
      tocUrlRule: _normalizeLinkRuleExpression(
        source.rules.detailTocUrlRule,
        fallbackExtractor: 'attr(href)',
        preferredAttribute: 'href',
      ),
    );
  }

  _TocParseRules? _buildTocRules(SourceDefinition source) {
    final listRule = _normalizeRuleExpression(
      source.rules.tocListRule ?? source.rules.tocRule,
      fallbackExtractor: 'html',
    );
    final titleRule = _normalizeRuleExpression(
      source.rules.tocTitleRule,
      fallbackExtractor: 'text',
    );
    final chapterUrlRule = _normalizeRuleExpression(
      source.rules.tocChapterUrlRule,
      fallbackExtractor: 'attr(href)',
      preferredAttribute: 'href',
    );

    if (listRule == null || titleRule == null || chapterUrlRule == null) {
      return null;
    }

    return _TocParseRules(
      listRule: listRule,
      titleRule: titleRule,
      chapterUrlRule: chapterUrlRule,
      reversed: source.rules.tocReversed,
    );
  }

  List<Chapter> _parseChapters({
    required String html,
    required String pageUrl,
    required _TocParseRules rules,
    required String sourceId,
    required String bookId,
    required SearchRequestContext context,
  }) {
    final chunks = _tryExecuteAll(
      content: html,
      expression: rules.listRule,
      stage: ErrorStage.toc,
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
      final title = _extractOptionalValue(
        content: chunk,
        expression: rules.titleRule,
        stage: ErrorStage.toc,
      );
      final chapterUrlRaw = _extractOptionalValue(
        content: chunk,
        expression: chapterUrlRule,
        stage: ErrorStage.toc,
      );

      if (title == null || chapterUrlRaw == null) {
        continue;
      }

      final chapterUrl = _resolveMaybeUrl(
        pageUrl: pageUrl,
        rawUrl: chapterUrlRaw,
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

  List<String> _tryExecuteAll({
    required String content,
    required String expression,
    required ErrorStage stage,
  }) {
    for (final candidate in _splitFallbackExpressions(expression)) {
      try {
        final values = _ruleEngine.executeAll(
          content: content,
          expression: candidate,
          stage: stage,
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

  String? _extractOptionalValue({
    required String content,
    required String? expression,
    required ErrorStage stage,
  }) {
    if (expression == null || expression.trim().isEmpty) {
      return null;
    }

    for (final candidate in _splitFallbackExpressions(expression)) {
      try {
        final value = _ruleEngine.executeFirst(
          content: content,
          expression: candidate,
          stage: stage,
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

  String? _resolveMaybeUrl({required String pageUrl, required String? rawUrl}) {
    final text = rawUrl?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }

    final requestSplit = _splitRequestOptions(text);
    final urlPart = requestSplit?.urlTemplate ?? text;

    final parsed = Uri.tryParse(urlPart);
    String resolvedUrl;
    if (parsed != null && parsed.hasScheme) {
      resolvedUrl = urlPart;
    } else {
      final pageUri = Uri.tryParse(pageUrl);
      if (pageUri == null || !pageUri.hasScheme) {
        return null;
      }
      resolvedUrl = pageUri.resolve(urlPart).toString();
    }

    if (requestSplit == null) {
      return resolvedUrl;
    }

    return '$resolvedUrl,${requestSplit.optionsText}';
  }

  String? _resolveDetailRule(String? initRule, String? fieldRule) {
    if (fieldRule == null || fieldRule.trim().isEmpty) {
      return null;
    }

    final normalizedField = fieldRule.trim();
    if (initRule == null || initRule.trim().isEmpty) {
      return normalizedField;
    }

    if (!normalizedField.startsWith('json:') || !initRule.startsWith('json:')) {
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

    final replaced = expression.replaceAllMapped(
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

    final decoded = _tryDecodeJson(response.body);
    if (decoded == null) {
      return const {};
    }

    return _flattenInitVariables(decoded);
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

    return _SearchRequestSpec(
      urlTemplate: splitResult.urlTemplate,
      method: method,
      bodyTemplate: _normalizeBodyTemplate(options['body']),
      contentType: _asNullableString(
        options['contentType'] ?? options['content-type'],
      ),
      headers: _parseHeaders(options['headers'] ?? options['header']),
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
        text.contains(r'{{$.') || text.contains(r'{{ $.');

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

    final firstStage = text.split('&&').first.trim();
    if (firstStage.isEmpty || firstStage.startsWith('js:')) {
      return null;
    }

    final delimiterIndex = firstStage.lastIndexOf('@');
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

class _DetailParseRules {
  const _DetailParseRules({
    this.initRule,
    this.titleRule,
    this.authorRule,
    this.introRule,
    this.coverUrlRule,
    this.tocUrlRule,
  });

  final String? initRule;
  final String? titleRule;
  final String? authorRule;
  final String? introRule;
  final String? coverUrlRule;
  final String? tocUrlRule;
}

class _TocParseRules {
  const _TocParseRules({
    required this.listRule,
    required this.titleRule,
    required this.chapterUrlRule,
    required this.reversed,
  });

  final String listRule;
  final String titleRule;
  final String chapterUrlRule;
  final bool reversed;
}
