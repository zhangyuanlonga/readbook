import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../domain/entities/book.dart';
import '../../search/application/server_gateway_identity.dart';
import '../../source/application/source_health_service.dart';
import '../domain/discover_source_summary.dart';

class ServerDiscoverGatewayService {
  ServerDiscoverGatewayService({
    ApiClient? client,
    ApiClient? catalogClient,
    SourceHealthService? sourceHealthService,
    String? baseUrl,
    String? catalogBaseUrl,
  }) : _gatewayBaseUrl = AppApiConfig.normalizeBaseUrl(
         baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
       ),
       _client =
           client ??
           ApiClient(
             baseUrl: AppApiConfig.normalizeBaseUrl(
               baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
             ),
             defaultTimeout: const Duration(seconds: 30),
           ),
       _catalogClient =
           catalogClient ??
           ApiClient(baseUrl: (catalogBaseUrl ?? AppApiConfig.baseUrl).trim()),
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance;

  final String _gatewayBaseUrl;
  final ApiClient _client;
  final ApiClient _catalogClient;
  final SourceHealthService _sourceHealthService;

  static const int defaultSourcePageSize = 100;

  Future<List<DiscoverSourceSummary>> loadDiscoverSources() async {
    final page = await loadDiscoverSourcePage(
      page: 1,
      pageSize: defaultSourcePageSize,
    );
    return page.items;
  }

  Future<DiscoverSourcePage> loadDiscoverSourcePage({
    int page = 1,
    int pageSize = defaultSourcePageSize,
    String? keyword,
  }) async {
    final result = await _loadEnabledSourcesPage(
      page: page < 1 ? 1 : page,
      pageSize: pageSize.clamp(1, 500),
      keyword: keyword,
    );
    return DiscoverSourcePage(
      items: result.items.map(_sourceSummaryFromItem).toList(growable: false),
      page: result.page,
      pageSize: result.pageSize,
      total: result.total,
      hasMore: result.hasMore,
    );
  }

  Future<DiscoverSourcePage> searchDiscoverSources({
    required String keyword,
    int pageSize = defaultSourcePageSize,
  }) {
    return loadDiscoverSourcePage(
      page: 1,
      pageSize: pageSize,
      keyword: keyword,
    );
  }

  Future<DiscoverSourceSummary> loadSourceCategories({
    required DiscoverSourceSummary source,
  }) async {
    final sourceId = fromServerGatewaySourceId(source.id);
    final sourceItem = _GatewaySourceItem(
      id: sourceId,
      sourceUrl: source.sourceUrl ?? sourceId,
      name: source.name,
      enabled: true,
      sourceType: source.sourceType,
      groupName: source.groupName,
    );
    return _loadSourceSummary(sourceItem);
  }

  Future<List<DiscoverCategoryBook>> loadCategoryBooks({
    required DiscoverSourceSummary source,
    required DiscoverSourceCategory category,
    int page = 1,
  }) async {
    final started = DateTime.now();
    try {
      final response = await _requestGatewayRest(
        path: 'v1/explore',
        body: <String, Object?>{
          'sourceId': fromServerGatewaySourceId(source.id),
          'ruleFindUrl': category.ruleFindUrl,
          'page': page < 1 ? 1 : page,
          if (category.filters.isNotEmpty) 'filters': category.filters,
          'options': <String, Object?>{'timeoutMs': 30000},
        },
        timeout: const Duration(seconds: 35),
        decoder: _ExploreBooksResponse.fromEnvelopeData,
      );
      _sourceHealthService.markDiscoverBooksSuccess(sourceId: source.id);
      return response.items
          .asMap()
          .entries
          .map(
            (entry) => entry.value.toDiscoverBook(
              source: source,
              fallbackCategory: category.name,
              fallbackSeed: _stableSeed('${category.id}:${entry.key}'),
            ),
          )
          .where((book) => book.detailUrl.trim().isNotEmpty)
          .toList(growable: false);
    } on AppException catch (error) {
      _sourceHealthService.markDiscoverBooksFailure(
        sourceId: source.id,
        message: error.briefMessage,
        error: error,
      );
      rethrow;
    } catch (error) {
      _sourceHealthService.markDiscoverBooksFailure(
        sourceId: source.id,
        message: error.toString(),
        error: error,
      );
      rethrow;
    } finally {
      final latency = DateTime.now().difference(started).inMilliseconds;
      if (latency > 0) {
        // The persisted source-health model does not store a dedicated discover
        // latency yet, but the call is still measured here for future extension.
      }
    }
  }

  Future<_GatewaySourcePage> _loadEnabledSourcesPage({
    required int page,
    required int pageSize,
    String? keyword,
  }) async {
    final normalizedKeyword = keyword?.trim() ?? '';
    return _requestCatalogRest(
      path: '/v1/discovery/book-sources',
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (normalizedKeyword.isNotEmpty) 'keyword': normalizedKeyword,
      },
      timeout: const Duration(seconds: 15),
      decoder: _GatewaySourcePage.fromEnvelopeData,
    );
  }

  Future<DiscoverSourceSummary> _loadSourceSummary(
    _GatewaySourceItem source,
  ) async {
    final gatewaySourceId = toServerGatewaySourceId(source.id);
    final started = DateTime.now();
    try {
      final response = await _requestGatewayRest(
        path: 'v1/explore-kinds',
        body: <String, Object?>{
          'sourceId': source.id,
          'options': <String, Object?>{'debug': false},
        },
        timeout: const Duration(seconds: 20),
        decoder: _ExploreKindsResponse.fromEnvelopeData,
      );
      final latency = DateTime.now().difference(started).inMilliseconds;
      _sourceHealthService.markDiscoverCategoriesSuccess(
        sourceId: gatewaySourceId,
      );
      final categories = response.items
          .asMap()
          .entries
          .map(
            (entry) => entry.value.toCategory(
              sourceId: gatewaySourceId,
              index: entry.key,
            ),
          )
          .where((category) => category.ruleFindUrl.trim().isNotEmpty)
          .toList(growable: false);
      return DiscoverSourceSummary(
        id: gatewaySourceId,
        sourceUrl: source.sourceUrl,
        name:
            response.sourceName.isNotEmpty ? response.sourceName : source.name,
        categoryCount: categories.length,
        status: _statusFromHealth(source.healthStatus, latency),
        latencyMs: latency,
        categories: categories,
        executionContext: response.executionContext,
        catalogSourceId: source.catalogSourceId,
        origin: source.origin,
        accessReason: source.accessReason,
        sourceType: source.sourceType,
        groupName: source.groupName,
        sourceReport: response.sourceReport,
      );
    } on AppException catch (error) {
      _sourceHealthService.markDiscoverCategoriesFailure(
        sourceId: gatewaySourceId,
        message: error.briefMessage,
        error: error,
      );
      return DiscoverSourceSummary(
        id: gatewaySourceId,
        sourceUrl: source.sourceUrl,
        name: source.name,
        categoryCount: 0,
        status: DiscoverSourceStatus.unavailable,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        categories: const <DiscoverSourceCategory>[],
        catalogSourceId: source.catalogSourceId,
        origin: source.origin,
        accessReason: source.accessReason,
        sourceType: source.sourceType,
        groupName: source.groupName,
        failure: error.gatewayFailure,
      );
    } catch (error) {
      _sourceHealthService.markDiscoverCategoriesFailure(
        sourceId: gatewaySourceId,
        message: error.toString(),
        error: error,
      );
      return DiscoverSourceSummary(
        id: gatewaySourceId,
        sourceUrl: source.sourceUrl,
        name: source.name,
        categoryCount: 0,
        status: DiscoverSourceStatus.unavailable,
        latencyMs: DateTime.now().difference(started).inMilliseconds,
        categories: const <DiscoverSourceCategory>[],
        catalogSourceId: source.catalogSourceId,
        origin: source.origin,
        accessReason: source.accessReason,
        sourceType: source.sourceType,
        groupName: source.groupName,
      );
    }
  }

  DiscoverSourceSummary _sourceSummaryFromItem(_GatewaySourceItem source) {
    return DiscoverSourceSummary(
      id: toServerGatewaySourceId(source.id),
      sourceUrl: source.sourceUrl,
      name: source.name,
      categoryCount: 0,
      status: _statusFromHealth(source.healthStatus, 0),
      latencyMs: null,
      categories: const <DiscoverSourceCategory>[],
      catalogSourceId: source.catalogSourceId,
      origin: source.origin,
      accessReason: source.accessReason,
      sourceType: source.sourceType,
      groupName: source.groupName,
    );
  }

  Future<T> _requestCatalogRest<T>({
    required String path,
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    required Duration timeout,
    required ApiDataDecoder<T> decoder,
  }) {
    return _catalogClient.request<T>(
      method: ApiMethod.get,
      path: path,
      queryParameters: queryParameters,
      attachAccessToken: true,
      enableRetry: false,
      timeout: timeout,
      stage: ErrorStage.source,
      decoder: decoder,
    );
  }

  Future<T> _requestGatewayRest<T>({
    ApiMethod method = ApiMethod.post,
    required String path,
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    Object? body,
    required Duration timeout,
    required ApiDataDecoder<T> decoder,
  }) {
    return _client.request<T>(
      method: method,
      path: AppApiConfig.readerGatewayApiPath(_gatewayBaseUrl, path),
      queryParameters: queryParameters,
      body: body,
      attachAccessToken: true,
      enableRetry: false,
      timeout: timeout,
      stage: ErrorStage.source,
      decoder: decoder,
    );
  }
}

class DiscoverSourcePage {
  const DiscoverSourcePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<DiscoverSourceSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;
}

DiscoverSourceStatus _statusFromHealth(String? healthStatus, int latencyMs) {
  final normalized = healthStatus?.trim().toLowerCase() ?? '';
  if (normalized == 'unavailable' || normalized == 'disabled') {
    return DiscoverSourceStatus.unavailable;
  }
  if (normalized == 'risky' || normalized == 'warning' || latencyMs > 1500) {
    return DiscoverSourceStatus.slow;
  }
  return DiscoverSourceStatus.available;
}

int _stableSeed(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = 0x1fffffff & (hash * 31 + unit);
  }
  return hash;
}

class _GatewaySourcePage {
  const _GatewaySourcePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<_GatewaySourceItem> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  factory _GatewaySourcePage.fromEnvelopeData(Object? data) {
    final map = _asMap(data, 'Invalid source page');
    final page = _intOrDefault(map['page'], 1);
    final pageSize = _intOrDefault(map['pageSize'] ?? map['page_size'], 0);
    final total = _intOrDefault(map['total'], 0);
    final accessReasons = _stringMap(map['access_reasons']);
    return _GatewaySourcePage(
      items: (map['items'] as List? ?? const <Object?>[])
          .map(
            (item) =>
                _GatewaySourceItem.fromJson(item, accessReasons: accessReasons),
          )
          .toList(growable: false),
      page: page,
      pageSize: pageSize,
      total: total,
      hasMore: map['hasMore'] == true || page * pageSize < total,
    );
  }
}

class _GatewaySourceItem {
  const _GatewaySourceItem({
    required this.id,
    required this.sourceUrl,
    required this.name,
    required this.enabled,
    this.healthStatus,
    this.catalogSourceId,
    this.accessReason,
    this.sourceType,
    this.groupName,
  });

  final String id;
  final String sourceUrl;
  final String name;
  final bool enabled;
  final String? healthStatus;
  final String? catalogSourceId;
  final String? accessReason;
  final String? sourceType;
  final String? groupName;

  String get origin => 'cloud_catalog';

  factory _GatewaySourceItem.fromJson(
    Object? value, {
    Map<String, String> accessReasons = const <String, String>{},
  }) {
    final map = _asMap(value, 'Invalid source item');
    final catalogSourceId = _requiredString(map, 'id');
    final gatewaySourceId =
        _optionalString(map['gateway_source_id']) ?? catalogSourceId;
    return _GatewaySourceItem(
      id: gatewaySourceId,
      sourceUrl:
          _optionalString(map['sourceUrl']) ??
          _optionalString(map['bookSourceUrl']) ??
          gatewaySourceId,
      name:
          _optionalString(map['sourceName']) ??
          _optionalString(map['name']) ??
          _requiredString(map, 'title'),
      enabled: map['enabled'] != false,
      healthStatus: _optionalString(map['healthStatus']),
      catalogSourceId: catalogSourceId,
      accessReason: accessReasons[catalogSourceId],
      sourceType: _optionalString(
        map['sourceType'] ?? map['source_type'] ?? map['visibility'],
      ),
      groupName: _optionalString(map['group_name'] ?? map['groupName']),
    );
  }
}

class _ExploreKindsResponse {
  const _ExploreKindsResponse({
    required this.items,
    required this.sourceName,
    this.executionContext,
    this.sourceReport = const <String, Object?>{},
  });

  final List<_ExploreKindItem> items;
  final String sourceName;
  final String? executionContext;
  final Map<String, Object?> sourceReport;

  factory _ExploreKindsResponse.fromEnvelopeData(Object? data) {
    final map = _asMap(data, 'Invalid explore kinds response');
    return _ExploreKindsResponse(
      items: (map['items'] as List? ?? const <Object?>[])
          .map(_ExploreKindItem.fromJson)
          .toList(growable: false),
      sourceName: _stringOrEmpty(map['sourceName']),
      executionContext: _optionalString(map['executionContext']),
      sourceReport: _mapOrEmpty(map['sourceReport']),
    );
  }
}

class _ExploreKindItem {
  const _ExploreKindItem({
    required this.title,
    this.url,
    this.kindType,
    this.action,
    this.defaultValue,
  });

  final String title;
  final String? url;
  final String? kindType;
  final String? action;
  final String? defaultValue;

  factory _ExploreKindItem.fromJson(Object? value) {
    final map = _asMap(value, 'Invalid explore kind item');
    return _ExploreKindItem(
      title: _requiredString(map, 'title'),
      url: _optionalString(map['url']),
      kindType: _optionalString(map['type']),
      action: _optionalString(map['action']),
      defaultValue: _optionalString(map['default']),
    );
  }

  DiscoverSourceCategory toCategory({
    required String sourceId,
    required int index,
  }) {
    final normalizedTitle = title.trim();
    final ruleFindUrl = url?.trim() ?? '';
    final idSeed =
        ruleFindUrl.isNotEmpty ? ruleFindUrl : '$normalizedTitle:$index';
    return DiscoverSourceCategory(
      id: '${_stableSeed(sourceId)}_${_stableSeed(idSeed)}',
      name: normalizedTitle.isEmpty ? '发现分类' : normalizedTitle,
      ruleFindUrl: ruleFindUrl,
      kindType: kindType,
      action: action,
      defaultValue: defaultValue,
      books: const <DiscoverCategoryBook>[],
    );
  }
}

class _ExploreBooksResponse {
  const _ExploreBooksResponse({required this.items});

  final List<_ExploreBookItem> items;

  factory _ExploreBooksResponse.fromEnvelopeData(Object? data) {
    final map = _asMap(data, 'Invalid explore response');
    return _ExploreBooksResponse(
      items: (map['items'] as List? ?? const <Object?>[])
          .map(_ExploreBookItem.fromJson)
          .toList(growable: false),
    );
  }
}

class _ExploreBookItem {
  const _ExploreBookItem({
    required this.name,
    required this.bookUrl,
    this.author,
    this.coverUrl,
    this.intro,
    this.kind,
    this.lastChapter,
    this.updateTime,
    this.wordCount,
    this.tocUrl,
    this.infoHtml,
    this.tocHtml,
    this.executionContext,
  });

  final String name;
  final String bookUrl;
  final String? author;
  final String? coverUrl;
  final String? intro;
  final String? kind;
  final String? lastChapter;
  final String? updateTime;
  final String? wordCount;
  final String? tocUrl;
  final String? infoHtml;
  final String? tocHtml;
  final String? executionContext;

  factory _ExploreBookItem.fromJson(Object? value) {
    final map = _asMap(value, 'Invalid explore book item');
    return _ExploreBookItem(
      name: _requiredString(map, 'name'),
      bookUrl: _requiredString(map, 'bookUrl'),
      author: _optionalString(map['author']),
      coverUrl: _optionalString(map['coverUrl']),
      intro: _optionalString(map['intro']),
      kind: _optionalString(map['kind']),
      lastChapter: _optionalString(map['lastChapter']),
      updateTime: _optionalString(map['updateTime']),
      wordCount: _optionalString(map['wordCount']),
      tocUrl: _optionalString(map['tocUrl']),
      infoHtml: _optionalString(map['infoHtml']),
      tocHtml: _optionalString(map['tocHtml']),
      executionContext: _optionalString(map['executionContext']),
    );
  }

  DiscoverCategoryBook toDiscoverBook({
    required DiscoverSourceSummary source,
    required String fallbackCategory,
    required int fallbackSeed,
  }) {
    final title = name.trim();
    final detailUrl = bookUrl.trim();
    final book = Book(
      id: 'discover_${_stableSeed('${source.id}:$detailUrl:$title')}',
      sourceId: source.id,
      title: title,
      detailUrl: detailUrl,
      tocUrl: tocUrl,
      author: author,
      intro: intro,
      coverUrl: coverUrl,
      latestChapter: lastChapter,
      wordCount: wordCount,
      category: kind ?? fallbackCategory,
      updateTime: updateTime,
      infoHtml: infoHtml,
      tocHtml: tocHtml,
      executionContext: executionContext,
    );
    return DiscoverCategoryBook(
      id: book.id,
      name: title,
      detailUrl: detailUrl,
      coverSeed: fallbackSeed,
      book: book,
      coverUrl: coverUrl,
      author: author,
    );
  }
}

Map<String, Object?> _asMap(Object? value, String message) {
  if (value is! Map) {
    throw FormatException(message);
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, Object?> _mapOrEmpty(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, value) => MapEntry(key.toString(), value));
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  return value.map(
    (key, item) => MapEntry(_stringOrEmpty(key), _stringOrEmpty(item)),
  )..removeWhere((key, item) => key.isEmpty || item.isEmpty);
}

String _requiredString(Map<String, Object?> map, String key) {
  final value = _stringOrEmpty(map[key]);
  if (value.isEmpty) {
    throw FormatException('Missing required field: $key');
  }
  return value;
}

String _stringOrEmpty(Object? value) => value?.toString().trim() ?? '';

String? _optionalString(Object? value) {
  final text = _stringOrEmpty(value);
  return text.isEmpty ? null : text;
}

int _intOrDefault(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
