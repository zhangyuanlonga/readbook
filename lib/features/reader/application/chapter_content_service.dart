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
import '../../../domain/entities/search_request_context.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import 'content_text_cleaner.dart';

class ChapterContentResult {
  const ChapterContentResult({
    required this.content,
    required this.fromCache,
    this.imageUrls = const [],
  });

  final String content;
  final bool fromCache;
  final List<String> imageUrls;

  bool get isImageContent => imageUrls.isNotEmpty;
}

class ChapterContentService {
  ChapterContentService({
    AppDatabase? database,
    SourceRepository? sourceRepository,
    AppHttpClient? httpClient,
    RuleEngine? ruleEngine,
    ContentTextCleaner? cleaner,
    AppLogger? logger,
    UrlTemplateResolver? urlTemplateResolver,
  }) : _database = database ?? AppDatabase.instance,
       _sourceRepository =
           sourceRepository ??
           SourceRepositoryImpl(database ?? AppDatabase.instance),
       _httpClient = httpClient ?? AppHttpClient(),
       _ruleEngine = ruleEngine ?? RuleEngine(),
       _cleaner = cleaner ?? const ContentTextCleaner(),
       _logger = logger ?? AppLogger.instance,
       _urlTemplateResolver =
           urlTemplateResolver ?? const UrlTemplateResolver();

  final AppDatabase _database;
  final SourceRepository _sourceRepository;
  final AppHttpClient _httpClient;
  final RuleEngine _ruleEngine;
  final ContentTextCleaner _cleaner;
  final AppLogger _logger;
  final UrlTemplateResolver _urlTemplateResolver;

  static final Map<String, String> _chapterCache = <String, String>{};
  static const String _imageCachePrefix = '__appread_image_payload__:';

  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
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
    final contentRule = _normalizeRuleExpression(
      source.rules.contentRule,
      fallbackExtractor: 'html',
    );

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

    final initVariables = await _loadInitVariables(
      source: source,
      initRule: source.rules.contentInitRule,
      context: templateContext,
    );

    final runtimeContext =
        initVariables.isEmpty
            ? templateContext
            : templateContext.copyWith(
              extraParams: {...templateContext.extraParams, ...initVariables},
            );

    final requestSpec = _parseChapterRequestSpec(
      chapterUrl: normalizedChapterUrl,
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
      'Chapter content request',
      context: {
        'sourceId': normalizedSourceId,
        'sourceName': source.name,
        'chapterUrl': normalizedChapterUrl,
        'method': requestSpec.method.name,
        'url': requestUrl,
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
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
      ),
    );

    final contentExpression = _resolveRuntimeRuleTemplate(
      expression: contentRule,
      context: runtimeContext,
    );

    final extractedSegments = _executeAllWithFallback(
      content: response.body,
      expression: contentExpression,
      stage: ErrorStage.content,
    );

    final imageUrls = _extractImageUrls(
      extractedSegments: extractedSegments,
      responseBody: response.body,
      source: source,
      chapterUrl: normalizedChapterUrl,
    );

    if (extractedSegments.isEmpty && imageUrls.isEmpty) {
      throw RuleMatchEmptyException(
        briefMessage: '正文解析为空，请检查正文规则。',
        stage: ErrorStage.content,
        sourceId: normalizedSourceId,
      );
    }

    final normalizedBookId = bookId?.trim() ?? '';

    if (imageUrls.isNotEmpty) {
      final payload = _encodeImageCachePayload(imageUrls);
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

      return ChapterContentResult(
        content: '',
        fromCache: false,
        imageUrls: imageUrls,
      );
    }

    final extracted = extractedSegments
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('\n\n');

    final cleaned = _cleaner.clean(extracted);
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

  _ContentRequestSpec _parseChapterRequestSpec({required String chapterUrl}) {
    final normalized = chapterUrl.trim();
    final splitResult = _splitRequestOptions(normalized);
    if (splitResult == null) {
      return _ContentRequestSpec(
        urlTemplate: normalized,
        method: HttpRequestMethod.get,
      );
    }

    final options = _decodeOptionsMap(splitResult.optionsText);

    final methodText = options['method']?.toString().toUpperCase();
    final method =
        methodText == 'POST' ? HttpRequestMethod.post : HttpRequestMethod.get;

    return _ContentRequestSpec(
      urlTemplate: splitResult.urlTemplate,
      method: method,
      headers: _parseHeaders(options['headers'] ?? options['header']),
      bodyTemplate: _normalizeBodyTemplate(options['body']),
      contentType: _asNullableString(
        options['contentType'] ?? options['content-type'],
      ),
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

  Future<Map<String, String>> _loadInitVariables({
    required SourceDefinition source,
    required String? initRule,
    required SearchRequestContext context,
  }) async {
    final rawInitRule = initRule?.trim();
    if (rawInitRule == null || rawInitRule.isEmpty) {
      return const {};
    }

    final requestSpec = _parseChapterRequestSpec(chapterUrl: rawInitRule);
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
        stage: ErrorStage.content,
        sourceId: source.id,
      ),
    );

    final decoded = _tryDecodeJson(response.body);
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

      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final item in decoded) {
              addUrl(item?.toString());
            }
          }
        } on FormatException {
          // keep regex fallback
        }
      }

      for (final match in _extractImageUrlRegex(trimmed)) {
        addUrl(match);
      }
    }

    if (urls.isNotEmpty || !imageRuleHint) {
      return List.unmodifiable(urls);
    }

    for (final match in _extractImageUrlRegex(responseBody)) {
      addUrl(match);
    }

    return List.unmodifiable(urls);
  }

  Iterable<String> _extractImageUrlRegex(String source) sync* {
    final patterns = <RegExp>[
      RegExp(
        "<img[^>]+(?:src|data-src|data-original)\\s*=\\s*['\"]([^'\"]+)['\"]",
        caseSensitive: false,
      ),
      RegExp(
        "https?://[^\\s'\"]+\\.(?:jpg|jpeg|png|webp|gif)",
        caseSensitive: false,
      ),
      RegExp("//[^\\s'\"]+\\.(?:jpg|jpeg|png|webp|gif)", caseSensitive: false),
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

  bool _looksLikeImageUrl(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('data:image/')) {
      return true;
    }

    return normalized.contains('.jpg') ||
        normalized.contains('.jpeg') ||
        normalized.contains('.png') ||
        normalized.contains('.webp') ||
        normalized.contains('.gif');
  }

  String? _normalizeImageUrl(
    String? value, {
    required String baseUrl,
    required String chapterUrl,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('data:image/')) {
      return trimmed;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      return uri.toString();
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    final chapterUri = Uri.tryParse(chapterUrl);
    if (chapterUri != null && chapterUri.hasScheme) {
      return chapterUri.resolve(trimmed).toString();
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri != null && baseUri.hasScheme) {
      return baseUri.resolve(trimmed).toString();
    }

    return null;
  }

  String _encodeImageCachePayload(List<String> imageUrls) {
    return '$_imageCachePrefix${jsonEncode(imageUrls)}';
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
    } on FormatException {
      return _DecodedChapterCache(content: trimmed);
    }

    return _DecodedChapterCache(content: trimmed);
  }

  List<String> _executeAllWithFallback({
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
      } on AppException catch (error) {
        if (candidate.startsWith('json:') && error.code == ErrorCode.decode) {
          final repaired = _repairJsonControlCharacters(content);
          if (repaired != content) {
            try {
              final repairedValues = _ruleEngine.executeAll(
                content: repaired,
                expression: candidate,
                stage: stage,
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
    final replaced = expression.replaceAllMapped(
      RegExp(r'\{\{\s*baseUrl\.match\(/(.+?)\/\)\[(\d+)\]\s*\}\}'),
      (match) {
        final baseUrl = context.extraParams['chapterUrl'] ?? '';
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
  });

  final String content;
  final List<String> imageUrls;
}

class _RequestRuleSplit {
  const _RequestRuleSplit({
    required this.urlTemplate,
    required this.optionsText,
  });

  final String urlTemplate;
  final String optionsText;
}

class _ContentRequestSpec {
  const _ContentRequestSpec({
    required this.urlTemplate,
    required this.method,
    this.headers = const {},
    this.bodyTemplate,
    this.contentType,
  });

  final String urlTemplate;
  final HttpRequestMethod method;
  final Map<String, String> headers;
  final Object? bodyTemplate;
  final String? contentType;
}
