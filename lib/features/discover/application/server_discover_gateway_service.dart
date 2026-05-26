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
    SourceHealthService? sourceHealthService,
    String? baseUrl,
  }) : _client =
           client ??
           ApiClient(
             baseUrl:
                 (baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl).trim(),
             defaultTimeout: const Duration(seconds: 30),
           ),
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance;

  final ApiClient _client;
  final SourceHealthService _sourceHealthService;

  static const int _sourcePageSize = 500;
  static const int _exploreKindsConcurrency = 6;

  Future<List<DiscoverSourceSummary>> loadDiscoverSources() async {
    final sources = await _loadEnabledSources();
    return _mapConcurrent(
      sources,
      _exploreKindsConcurrency,
      _loadSourceSummary,
    ).then((items) {
      final visible = items
          .where((item) => item.categories.isNotEmpty || item.failure != null)
          .toList(growable: false);
      visible.sort((a, b) {
        final byStatus = a.status.index.compareTo(b.status.index);
        if (byStatus != 0) return byStatus;
        return a.name.compareTo(b.name);
      });
      return visible;
    });
  }

  Future<List<DiscoverCategoryBook>> loadCategoryBooks({
    required DiscoverSourceSummary source,
    required DiscoverSourceCategory category,
    int page = 1,
  }) async {
    final started = DateTime.now();
    try {
      final response = await _client.request<_ExploreBooksResponse>(
        method: ApiMethod.post,
        path: 'v1/explore',
        body: <String, Object?>{
          'sourceId': fromServerGatewaySourceId(source.id),
          'ruleFindUrl': category.ruleFindUrl,
          'page': page < 1 ? 1 : page,
          if (category.filters.isNotEmpty) 'filters': category.filters,
          'options': <String, Object?>{'timeoutMs': 30000},
        },
        attachAccessToken: true,
        enableRetry: false,
        timeout: const Duration(seconds: 35),
        stage: ErrorStage.source,
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

  Future<List<_GatewaySourceItem>> _loadEnabledSources() async {
    final all = <_GatewaySourceItem>[];
    var page = 1;
    var hasMore = true;
    while (hasMore) {
      final result = await _client.request<_GatewaySourcePage>(
        method: ApiMethod.get,
        path: 'v1/sources',
        queryParameters: <String, dynamic>{
          'enabled': true,
          'page': page,
          'pageSize': _sourcePageSize,
        },
        attachAccessToken: true,
        enableRetry: false,
        timeout: const Duration(seconds: 15),
        stage: ErrorStage.source,
        decoder: _GatewaySourcePage.fromEnvelopeData,
      );
      all.addAll(result.items.where((item) => item.enabled));
      hasMore = result.hasMore;
      page += 1;
    }
    return all;
  }

  Future<DiscoverSourceSummary> _loadSourceSummary(
    _GatewaySourceItem source,
  ) async {
    final gatewaySourceId = toServerGatewaySourceId(source.id);
    final started = DateTime.now();
    try {
      final response = await _client.request<_ExploreKindsResponse>(
        method: ApiMethod.post,
        path: 'v1/explore-kinds',
        body: <String, Object?>{
          'sourceId': source.id,
          'options': <String, Object?>{'debug': false},
        },
        attachAccessToken: true,
        enableRetry: false,
        timeout: const Duration(seconds: 20),
        stage: ErrorStage.source,
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
      );
    }
  }
}

Future<List<R>> _mapConcurrent<T, R>(
  List<T> values,
  int concurrency,
  Future<R> Function(T value) mapper,
) async {
  if (values.isEmpty) return <R>[];
  final results = List<R?>.filled(values.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      nextIndex += 1;
      if (index >= values.length) return;
      results[index] = await mapper(values[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, values.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return results.whereType<R>().toList(growable: false);
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
  const _GatewaySourcePage({required this.items, required this.hasMore});

  final List<_GatewaySourceItem> items;
  final bool hasMore;

  factory _GatewaySourcePage.fromEnvelopeData(Object? data) {
    final map = _asMap(data, 'Invalid source page');
    return _GatewaySourcePage(
      items: (map['items'] as List? ?? const <Object?>[])
          .map(_GatewaySourceItem.fromJson)
          .toList(growable: false),
      hasMore: map['hasMore'] == true,
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
  });

  final String id;
  final String sourceUrl;
  final String name;
  final bool enabled;
  final String? healthStatus;

  factory _GatewaySourceItem.fromJson(Object? value) {
    final map = _asMap(value, 'Invalid source item');
    return _GatewaySourceItem(
      id: _requiredString(map, 'id'),
      sourceUrl:
          _optionalString(map['sourceUrl']) ?? _requiredString(map, 'id'),
      name: _requiredString(map, 'sourceName'),
      enabled: map['enabled'] != false,
      healthStatus: _optionalString(map['healthStatus']),
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
