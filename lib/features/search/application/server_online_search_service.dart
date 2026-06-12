import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/errors/gateway_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/interceptors.dart';
import '../../../domain/entities/book.dart';
import 'server_gateway_identity.dart';
import 'search_models.dart';
import 'search_report_assembler.dart';

class ServerOnlineSearchService {
  ServerOnlineSearchService({
    ApiClient? client,
    Dio? dio,
    AppLogger? logger,
    String? baseUrl,
  }) : _baseUrl = AppApiConfig.normalizeBaseUrl(
         baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
       ),
       _dio = dio ?? Dio(),
       _logger = logger ?? AppLogger.instance,
       _client =
           client ??
           ApiClient(
             baseUrl: AppApiConfig.normalizeBaseUrl(
               baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
             ),
             defaultTimeout: const Duration(seconds: 30),
           ) {
    ApiClient.installAuthInterceptor(_dio);
    if (_dio.interceptors.whereType<NetworkLogInterceptor>().isEmpty) {
      _dio.interceptors.add(NetworkLogInterceptor(_logger));
    }
  }

  final ApiClient _client;
  final Dio _dio;
  final AppLogger _logger;
  final String _baseUrl;

  static const int _rawSearchPageSize = 100;
  static const int _maxSearchConcurrency = 12;
  static const Duration _searchStreamTimeout = Duration(minutes: 21);
  static const Duration _searchOnceTimeout = Duration(minutes: 5);

  static String _contentTypeParam(SearchContentMode mode) {
    return switch (mode) {
      SearchContentMode.manga => 'manga',
      SearchContentMode.audio => 'audio',
      SearchContentMode.novel => 'novel',
    };
  }

  Future<SearchExecutionReport> search({
    required String keyword,
    required SearchContentMode contentMode,
    Iterable<String>? sourceIds,
    bool preciseMatch = false,
    bool aggregateByTitleAuthor = true,
    int? maxConcurrentSources,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
  }) async {
    if (cancellationToken?.isCancelled ?? false) {
      return _emptyReport(keyword);
    }

    return _searchStream(
      keyword: keyword,
      contentMode: contentMode,
      sourceIds: sourceIds,
      preciseMatch: preciseMatch,
      aggregateByTitleAuthor: aggregateByTitleAuthor,
      maxConcurrentSources: maxConcurrentSources,
      cancellationToken: cancellationToken,
      onProgress: onProgress,
    );
  }

  Future<SearchExecutionReport> _searchOnce({
    required String keyword,
    required SearchContentMode contentMode,
    Iterable<String>? sourceIds,
    required bool preciseMatch,
    required bool aggregateByTitleAuthor,
    int? maxConcurrentSources,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
  }) async {
    final selectedSourceIds = _normalizedList(sourceIds);
    final concurrency = _normalizedConcurrency(maxConcurrentSources);
    final payload = <String, Object?>{
      'keyword': keyword,
      'contentType': _contentTypeParam(contentMode),
      'matchMode': preciseMatch ? 'exact' : 'fuzzy',
      'scenario': 'globalSearch',
      'sourceScope': {
        'mode': selectedSourceIds.isEmpty ? 'all' : 'include',
        if (selectedSourceIds.isNotEmpty) 'sourceIds': selectedSourceIds,
      },
      'page': 1,
      'pageSize': _rawSearchPageSize,
      'aggregate': {'byTitleAuthor': false, 'includeSourceHits': true},
      'options': {
        if (concurrency != null)
          'concurrency': {
            'total': concurrency,
            'perHost': _perHostConcurrencyFor(concurrency),
          },
      },
    };

    final response = await _client.request<_ServerSearchResponse>(
      method: ApiMethod.post,
      path: _gatewayPath('v1/books/search'),
      body: payload,
      attachAccessToken: true,
      enableRetry: false,
      timeout: _searchOnceTimeout,
      stage: ErrorStage.search,
      decoder: _ServerSearchResponse.fromEnvelopeData,
    );

    if (cancellationToken?.isCancelled ?? false) {
      return _emptyReport(keyword);
    }

    final report = await response.toSearchExecutionReport(
      keyword,
      aggregateByTitleAuthor: aggregateByTitleAuthor,
    );
    onProgress?.call(report);
    return report;
  }

  Future<SearchExecutionReport> _searchStream({
    required String keyword,
    required SearchContentMode contentMode,
    Iterable<String>? sourceIds,
    required bool preciseMatch,
    required bool aggregateByTitleAuthor,
    int? maxConcurrentSources,
    SearchCancellationToken? cancellationToken,
    SearchProgressCallback? onProgress,
  }) async {
    final normalizedKeyword = keyword.trim();
    final selectedSourceIds = _normalizedList(sourceIds);
    final concurrency = _normalizedConcurrency(maxConcurrentSources);
    final queryParameters = <String, String>{
      'keyword': normalizedKeyword,
      'contentType': _contentTypeParam(contentMode),
      'matchMode': preciseMatch ? 'exact' : 'fuzzy',
      'scenario': 'globalSearch',
      'sourceScopeMode': selectedSourceIds.isEmpty ? 'all' : 'include',
      if (selectedSourceIds.isNotEmpty)
        'sourceIds': jsonEncode(selectedSourceIds),
      'page': '1',
      'pageSize': '$_rawSearchPageSize',
      'aggregateByTitleAuthor': 'false',
      if (concurrency != null) 'concurrency': '$concurrency',
      if (concurrency != null)
        'perHostConcurrency': '${_perHostConcurrencyFor(concurrency)}',
    };
    final url = _resolveUrl(
      'v1/books/search/stream',
      queryParameters: queryParameters,
    );
    final cancelToken = CancelToken();
    Timer? cancellationPoller;
    cancellationPoller = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (cancellationToken?.isCancelled ?? false) {
        cancelToken.cancel('search cancelled');
      }
    });

    try {
      final headers = <String, String>{
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      };

      final response = await _dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          extra: const <String, Object?>{
            apiAttachAccessTokenExtraKey: true,
            apiEnableAuthRefreshExtraKey: true,
          },
          sendTimeout: const Duration(seconds: 8),
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: _searchStreamTimeout,
          validateStatus:
              (statusCode) => statusCode != null && statusCode < 600,
        ),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode >= 400) {
        final message = await _serverErrorMessage(response.data, statusCode);
        throw NetworkException(
          briefMessage: message,
          stage: ErrorStage.search,
          requestUrl: url,
        );
      }

      final body = response.data;
      if (body == null) {
        throw const DecodeException(
          briefMessage: '服务器搜索响应为空。',
          stage: ErrorStage.search,
        );
      }

      final parser = _SseParser();
      final accumulator = _ServerSearchAccumulator(
        keyword: normalizedKeyword,
        aggregateByTitleAuthor: aggregateByTitleAuthor,
        expectedSourceCount:
            selectedSourceIds.isEmpty ? 0 : selectedSourceIds.length,
      );
      SearchExecutionReport? finalReport;

      await for (final chunk in utf8.decoder.bind(
        body.stream.cast<List<int>>(),
      )) {
        await cancellationToken?.waitIfPaused();
        if (cancellationToken?.isCancelled ?? false) {
          cancelToken.cancel('search cancelled');
          break;
        }
        for (final event in parser.addChunk(chunk)) {
          final report = await accumulator.apply(event);
          if (report != null) {
            finalReport = report;
            onProgress?.call(report);
          }
        }
      }

      for (final event in parser.close()) {
        final report = await accumulator.apply(event);
        if (report != null) {
          finalReport = report;
          onProgress?.call(report);
        }
      }

      if (cancellationToken?.isCancelled ?? false) {
        return finalReport ?? await accumulator.currentReport();
      }
      return finalReport ?? await accumulator.currentReport();
    } on DioException catch (error, stackTrace) {
      if (CancelToken.isCancel(error) ||
          (cancellationToken?.isCancelled ?? false)) {
        return _emptyReport(keyword);
      }
      _logger.warn(
        'Server stream search failed, fallback to once request',
        context: <String, Object?>{
          'url': url,
          'message': error.message,
          'type': error.type.name,
        },
      );
      try {
        return await _searchOnce(
          keyword: keyword,
          contentMode: contentMode,
          sourceIds: sourceIds,
          preciseMatch: preciseMatch,
          aggregateByTitleAuthor: aggregateByTitleAuthor,
          maxConcurrentSources: maxConcurrentSources,
          cancellationToken: cancellationToken,
          onProgress: onProgress,
        );
      } catch (_) {
        throw NetworkException(
          briefMessage: '服务器搜索连接失败，请检查服务是否已启动。',
          stage: ErrorStage.search,
          requestUrl: url,
          cause: error,
          stackTrace: stackTrace,
        );
      }
    } on FormatException catch (error, stackTrace) {
      throw DecodeException(
        briefMessage: '服务器搜索流解析失败。',
        stage: ErrorStage.search,
        requestUrl: url,
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      cancellationPoller.cancel();
    }
  }

  Future<List<ServerSearchSourceSummary>> loadSources({
    required SearchContentMode contentMode,
  }) async {
    final response = await loadSourcePage(
      contentMode: contentMode,
      page: 1,
      pageSize: 500,
    );
    return response.items;
  }

  Future<ServerSearchSourcePage> loadSourcePage({
    required SearchContentMode contentMode,
    int page = 1,
    int pageSize = 80,
    String? keyword,
  }) async {
    final response = await _client.request<ServerSearchSourcePage>(
      method: ApiMethod.get,
      path: _gatewayPath('v1/sources'),
      queryParameters: <String, dynamic>{
        'contentType': _contentTypeParam(contentMode),
        'enabled': true,
        'accessScope': 'me',
        if ((keyword ?? '').trim().isNotEmpty) 'keyword': keyword!.trim(),
        'page': page.clamp(1, 1 << 30),
        'pageSize': pageSize.clamp(1, 500),
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 12),
      stage: ErrorStage.source,
      decoder: ServerSearchSourcePage.fromEnvelopeData,
    );
    return response;
  }

  SearchExecutionReport _emptyReport(String keyword) {
    return SearchExecutionReport(
      keyword: keyword,
      sourceCount: 0,
      successSourceCount: 0,
      books: const <Book>[],
      failures: const <SourceSearchFailure>[],
      sourceNames: const <String, String>{},
    );
  }

  String _resolveUrl(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    final normalized = _gatewayPath(path);
    final baseUri = Uri.parse(_baseUrl);
    final resolved =
        normalized.startsWith('http://') || normalized.startsWith('https://')
            ? Uri.parse(normalized)
            : baseUri.resolve(normalized);
    if (queryParameters.isEmpty) {
      return resolved.toString();
    }
    return resolved.replace(queryParameters: queryParameters).toString();
  }

  String _gatewayPath(String path) {
    return AppApiConfig.readerGatewayApiPath(_baseUrl, path);
  }
}

List<String> _normalizedList(Iterable<String>? values) {
  return values
          ?.map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false) ??
      const <String>[];
}

int? _normalizedConcurrency(int? value) {
  if (value == null) {
    return null;
  }
  return value
      .clamp(1, ServerOnlineSearchService._maxSearchConcurrency)
      .toInt();
}

int _perHostConcurrencyFor(int totalConcurrency) {
  return totalConcurrency <= 4 ? 1 : 2;
}

Future<String> _serverErrorMessage(ResponseBody? body, int statusCode) async {
  if (body != null) {
    try {
      final raw = await utf8.decoder.bind(body.stream.cast<List<int>>()).join();
      final data = jsonDecode(raw);
      if (data is Map) {
        final code = data['code']?.toString() ?? '';
        final message = data['message']?.toString() ?? '';
        if (code == 'SOURCE_QUOTA_EXCEEDED') {
          return '今日搜索次数已用完。';
        }
        if (message.trim().isNotEmpty && message != 'source quota exceeded') {
          return message.trim();
        }
      }
    } catch (_) {}
  }
  return '服务器搜索失败，状态码：$statusCode';
}

class ServerSearchSourceSummary {
  const ServerSearchSourceSummary({
    required this.id,
    required this.name,
    required this.contentType,
    required this.enabled,
    this.group,
    this.healthStatus,
    this.sourceType,
    this.visibility,
  });

  final String id;
  final String name;
  final String contentType;
  final bool enabled;
  final String? group;
  final String? healthStatus;
  final String? sourceType;
  final String? visibility;

  factory ServerSearchSourceSummary.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid server source item');
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return ServerSearchSourceSummary(
      id: _requiredString(map, 'id'),
      name: _requiredString(map, 'sourceName'),
      contentType: _stringOrEmpty(map['contentType']),
      enabled: map['enabled'] != false,
      group: _optionalString(map['group']),
      healthStatus: _optionalString(
        map['healthStatus'] ?? map['health_status'],
      ),
      sourceType: _optionalString(map['sourceType'] ?? map['source_type']),
      visibility: _optionalString(map['visibility']),
    );
  }
}

class ServerSearchSourcePage {
  const ServerSearchSourcePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.hasMore,
  });

  final List<ServerSearchSourceSummary> items;
  final int page;
  final int pageSize;
  final int total;
  final bool hasMore;

  factory ServerSearchSourcePage.fromEnvelopeData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Invalid server source page');
    }
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    return ServerSearchSourcePage(
      items: (map['items'] as List? ?? const <Object?>[])
          .map(ServerSearchSourceSummary.fromJson)
          .toList(growable: false),
      page: _intOrDefault(map['page'], 1),
      pageSize: _intOrDefault(map['pageSize'], 0),
      total: _intOrDefault(map['total'], 0),
      hasMore: map['hasMore'] == true,
    );
  }
}

class _ServerSearchAccumulator {
  _ServerSearchAccumulator({
    required this.keyword,
    required this.aggregateByTitleAuthor,
    required this.expectedSourceCount,
  });

  final String keyword;
  final bool aggregateByTitleAuthor;
  final int expectedSourceCount;
  final Map<String, _ServerSearchItem> _itemsById =
      <String, _ServerSearchItem>{};
  final Map<String, String> _sourceNames = <String, String>{};
  final Map<String, int> _sourceOrderById = <String, int>{};
  final List<_ServerSearchFailure> _failures = <_ServerSearchFailure>[];
  final Set<String> _successSourceIds = <String>{};
  final Set<String> _failedSourceIds = <String>{};
  int _sourceCount = 0;
  int _processedSourceCount = 0;

  Future<SearchExecutionReport?> apply(_SseEvent event) async {
    switch (event.name) {
      case 'start':
        return _handleStart(event.data);
      case 'sourceResult':
        return _handleSourceResult(event.data);
      case 'sourceError':
        return _handleSourceError(event.data);
      case 'progress':
        return _handleProgress(event.data);
      case 'end':
        final finalResponse = _ServerSearchResponse.fromEnvelopeData(
          event.data,
        );
        _sourceCount = finalResponse.reports.sourceCount;
        for (final failure in finalResponse.reports.failures) {
          if (failure.sourceId.isNotEmpty) {
            _failedSourceIds.add(failure.sourceId);
            _sourceNames[toServerGatewaySourceId(failure.sourceId)] =
                failure.sourceName;
          }
        }
        _processedSourceCount =
            finalResponse.reports.processedSourceCount > 0
                ? finalResponse.reports.processedSourceCount
                : _effectiveSourceCount;
        return currentReport();
      default:
        return null;
    }
  }

  Future<SearchExecutionReport> currentReport() {
    final books = _itemsById.values
        .map((item) => item.toBook())
        .toList(growable: false);
    final booksById = <String, Book>{for (final book in books) book.id: book};
    final sourceNames = Map<String, String>.unmodifiable(_sourceNames);
    return buildSearchExecutionReportWithExistingAggregator(
      keyword: keyword,
      sourceCount: _effectiveSourceCount,
      successSourceCount: _successSourceIds.length,
      booksById: booksById,
      failures: List<SourceSearchFailure>.unmodifiable(
        _failures.map((failure) => failure.toSourceSearchFailure()),
      ),
      sourceNames: sourceNames,
      sourceOrderById: Map<String, int>.unmodifiable(_sourceOrderById),
      aggregateByTitleAuthor: aggregateByTitleAuthor,
      processedSourceCountOverride: _processedSourceCount,
    );
  }

  Future<SearchExecutionReport?> _handleStart(Object? data) async {
    if (data is Map) {
      _sourceCount = _intOrDefault(data['sourceCount'], _sourceCount);
    }
    return _sourceCount > 0 ? currentReport() : null;
  }

  Future<SearchExecutionReport> _handleSourceResult(Object? data) {
    if (data is! Map) {
      return currentReport();
    }
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    final sourceId = _stringOrEmpty(map['sourceId']);
    final gatewaySourceId = toServerGatewaySourceId(sourceId);
    if (sourceId.isNotEmpty) {
      _sourceOrderById.putIfAbsent(
        gatewaySourceId,
        () => _sourceOrderById.length,
      );
      _sourceNames[gatewaySourceId] = _stringOrEmpty(map['sourceName']);
      _successSourceIds.add(sourceId);
    }
    final items = (map['items'] as List? ?? const <Object?>[])
        .map(_ServerSearchItem.fromJson)
        .toList(growable: false);
    for (final item in items) {
      final itemGatewaySourceId = toServerGatewaySourceId(item.sourceId);
      _sourceOrderById.putIfAbsent(
        itemGatewaySourceId,
        () => _sourceOrderById.length,
      );
      if (item.sourceName.isNotEmpty) {
        _sourceNames[itemGatewaySourceId] = item.sourceName;
      }
      _itemsById[item.bookId] = item;
    }
    _processedSourceCount = _successSourceIds.length + _failedSourceIds.length;
    return currentReport();
  }

  Future<SearchExecutionReport> _handleSourceError(Object? data) {
    final failure = _ServerSearchFailure.fromJson(data);
    _failures.add(failure);
    if (failure.sourceId.isNotEmpty) {
      _failedSourceIds.add(failure.sourceId);
      _sourceNames[toServerGatewaySourceId(failure.sourceId)] =
          failure.sourceName;
    }
    _processedSourceCount = _successSourceIds.length + _failedSourceIds.length;
    return currentReport();
  }

  Future<SearchExecutionReport> _handleProgress(Object? data) {
    if (data is Map) {
      final map = data.map((key, value) => MapEntry(key.toString(), value));
      _sourceCount = _intOrDefault(map['sourceCount'], _sourceCount);
      _processedSourceCount = _intOrDefault(
        map['processedSourceCount'],
        _processedSourceCount,
      );
    }
    return currentReport();
  }

  int get _effectiveSourceCount {
    if (_sourceCount > 0) {
      return _sourceCount;
    }
    return expectedSourceCount > _processedSourceCount
        ? expectedSourceCount
        : _processedSourceCount;
  }
}

class _SseEvent {
  const _SseEvent({required this.name, required this.data});

  final String name;
  final Object? data;
}

class _SseParser {
  final StringBuffer _pendingLine = StringBuffer();
  final StringBuffer _data = StringBuffer();
  String _eventName = 'message';

  List<_SseEvent> addChunk(String chunk) {
    final events = <_SseEvent>[];
    for (var index = 0; index < chunk.length; index++) {
      final char = chunk[index];
      if (char == '\n') {
        _consumeLine(_pendingLine.toString(), events);
        _pendingLine.clear();
      } else {
        _pendingLine.write(char);
      }
    }
    return events;
  }

  List<_SseEvent> close() {
    final events = <_SseEvent>[];
    if (_pendingLine.isNotEmpty) {
      _consumeLine(_pendingLine.toString(), events);
      _pendingLine.clear();
    }
    _dispatch(events);
    return events;
  }

  void _consumeLine(String rawLine, List<_SseEvent> events) {
    final line =
        rawLine.endsWith('\r')
            ? rawLine.substring(0, rawLine.length - 1)
            : rawLine;
    if (line.isEmpty) {
      _dispatch(events);
      return;
    }
    if (line.startsWith(':')) {
      return;
    }
    if (line.startsWith('event:')) {
      _eventName = line.substring(6).trim();
      return;
    }
    if (line.startsWith('data:')) {
      if (_data.isNotEmpty) {
        _data.write('\n');
      }
      _data.write(line.substring(5).trimLeft());
    }
  }

  void _dispatch(List<_SseEvent> events) {
    if (_data.isEmpty) {
      _eventName = 'message';
      return;
    }
    events.add(_SseEvent(name: _eventName, data: jsonDecode(_data.toString())));
    _eventName = 'message';
    _data.clear();
  }
}

class _ServerSearchResponse {
  const _ServerSearchResponse({
    required this.items,
    required this.reports,
    required this.sourceHits,
  });

  final List<_ServerSearchItem> items;
  final _ServerSearchReports reports;
  final Map<String, List<_ServerSearchItem>> sourceHits;

  factory _ServerSearchResponse.fromEnvelopeData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Invalid server search response');
    }
    final map = data.map((key, value) => MapEntry(key.toString(), value));
    final items = (map['items'] as List? ?? const <Object?>[])
        .map(_ServerSearchItem.fromJson)
        .toList(growable: false);
    final sourceHitsRaw = map['sourceHits'];
    final sourceHits = <String, List<_ServerSearchItem>>{};
    if (sourceHitsRaw is Map) {
      for (final entry in sourceHitsRaw.entries) {
        final value = entry.value;
        if (value is List) {
          sourceHits[entry.key.toString()] = value
              .map(_ServerSearchItem.fromJson)
              .toList(growable: false);
        }
      }
    }
    return _ServerSearchResponse(
      items: items,
      reports: _ServerSearchReports.fromJson(map['reports']),
      sourceHits: sourceHits,
    );
  }

  Future<SearchExecutionReport> toSearchExecutionReport(
    String keyword, {
    required bool aggregateByTitleAuthor,
  }) {
    final books = items.map((item) => item.toBook()).toList(growable: false);
    final booksById = <String, Book>{for (final book in books) book.id: book};
    final sourceNames = <String, String>{};
    final sourceOrderById = <String, int>{};
    for (final item in items) {
      final gatewaySourceId = toServerGatewaySourceId(item.sourceId);
      sourceOrderById.putIfAbsent(
        gatewaySourceId,
        () => sourceOrderById.length,
      );
      sourceNames[gatewaySourceId] = item.sourceName;
    }
    for (final hits in sourceHits.values) {
      for (final item in hits) {
        final gatewaySourceId = toServerGatewaySourceId(item.sourceId);
        sourceOrderById.putIfAbsent(
          gatewaySourceId,
          () => sourceOrderById.length,
        );
        sourceNames[gatewaySourceId] = item.sourceName;
      }
    }
    for (final failure in reports.failures) {
      sourceNames[toServerGatewaySourceId(failure.sourceId)] =
          failure.sourceName;
    }
    return buildSearchExecutionReportWithExistingAggregator(
      keyword: keyword,
      sourceCount: reports.sourceCount,
      successSourceCount: reports.successSourceCount,
      booksById: booksById,
      failures: List<SourceSearchFailure>.unmodifiable(
        reports.failures
            .map((failure) => failure.toSourceSearchFailure())
            .toList(growable: false),
      ),
      sourceNames: Map<String, String>.unmodifiable(sourceNames),
      sourceOrderById: Map<String, int>.unmodifiable(sourceOrderById),
      aggregateByTitleAuthor: aggregateByTitleAuthor,
    );
  }
}

class _ServerSearchItem {
  const _ServerSearchItem({
    required this.bookId,
    required this.sourceId,
    required this.sourceName,
    required this.title,
    required this.detailUrl,
    required this.sourceHitCount,
    this.tocUrl,
    this.executionContext,
    this.author,
    this.intro,
    this.coverUrl,
    this.latestChapter,
    this.wordCount,
    this.category,
    this.tags = const <String>[],
    this.updateTime,
    this.infoHtml,
    this.tocHtml,
  });

  final String bookId;
  final String sourceId;
  final String sourceName;
  final String title;
  final String detailUrl;
  final int sourceHitCount;
  final String? tocUrl;
  final String? executionContext;
  final String? author;
  final String? intro;
  final String? coverUrl;
  final String? latestChapter;
  final String? wordCount;
  final String? category;
  final List<String> tags;
  final String? updateTime;
  final String? infoHtml;
  final String? tocHtml;

  factory _ServerSearchItem.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid server search item');
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return _ServerSearchItem(
      bookId: _requiredString(map, 'bookId'),
      sourceId: _requiredString(map, 'sourceId'),
      sourceName: _stringOrEmpty(map['sourceName']),
      title: _requiredString(map, 'title'),
      detailUrl: _requiredString(map, 'detailUrl'),
      sourceHitCount: _intOrDefault(map['sourceHitCount'], 1),
      tocUrl: _optionalString(map['tocUrl']),
      executionContext: _optionalString(map['executionContext']),
      author: _optionalString(map['author']),
      intro: _optionalString(map['intro']),
      coverUrl: _optionalString(map['coverUrl']),
      latestChapter: _optionalString(map['latestChapter']),
      wordCount: _optionalString(map['wordCount']),
      category: _optionalString(map['category']),
      tags: _stringList(map['tags']),
      updateTime: _optionalString(map['updateTime']),
      infoHtml: _optionalString(map['infoHtml']),
      tocHtml: _optionalString(map['tocHtml']),
    );
  }

  Book toBook() {
    return Book(
      id: bookId,
      sourceId: toServerGatewaySourceId(sourceId),
      title: title,
      detailUrl: detailUrl,
      tocUrl: tocUrl,
      author: author,
      intro: intro,
      coverUrl: coverUrl,
      latestChapter: latestChapter,
      wordCount: wordCount,
      category: category,
      tags: tags,
      updateTime: updateTime,
      infoHtml: infoHtml,
      tocHtml: tocHtml,
      executionContext: executionContext,
    );
  }
}

class _ServerSearchReports {
  const _ServerSearchReports({
    required this.sourceCount,
    required this.processedSourceCount,
    required this.successSourceCount,
    required this.failures,
  });

  final int sourceCount;
  final int processedSourceCount;
  final int successSourceCount;
  final List<_ServerSearchFailure> failures;

  factory _ServerSearchReports.fromJson(Object? value) {
    if (value is! Map) {
      return const _ServerSearchReports(
        sourceCount: 0,
        processedSourceCount: 0,
        successSourceCount: 0,
        failures: <_ServerSearchFailure>[],
      );
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return _ServerSearchReports(
      sourceCount: _intOrDefault(map['sourceCount'], 0),
      processedSourceCount: _intOrDefault(map['processedSourceCount'], 0),
      successSourceCount: _intOrDefault(map['successSourceCount'], 0),
      failures: (map['failures'] as List? ?? const <Object?>[])
          .map(_ServerSearchFailure.fromJson)
          .toList(growable: false),
    );
  }
}

class _ServerSearchFailure {
  const _ServerSearchFailure({
    required this.sourceId,
    required this.sourceName,
    required this.message,
    required this.failureStage,
    required this.failureCategory,
    this.failure,
  });

  final String sourceId;
  final String sourceName;
  final String message;
  final String failureStage;
  final String failureCategory;
  final GatewayFailure? failure;

  factory _ServerSearchFailure.fromJson(Object? value) {
    if (value is! Map) {
      return const _ServerSearchFailure(
        sourceId: '',
        sourceName: '',
        message: '服务器搜索失败',
        failureStage: 'search',
        failureCategory: 'unknown',
      );
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return _ServerSearchFailure(
      sourceId: _stringOrEmpty(map['sourceId']),
      sourceName: _stringOrEmpty(map['sourceName']),
      message: _stringOrEmpty(map['message']),
      failureStage: _stringOrEmpty(map['failureStage']),
      failureCategory: _stringOrEmpty(map['failureCategory']),
      failure: GatewayFailure.tryParse(map['failure']),
    );
  }

  SourceSearchFailure toSourceSearchFailure() {
    final gatewayFailure = failure;
    final stage =
        gatewayFailure?.toErrorStage(fallback: ErrorStage.search) ??
        ErrorStage.search;
    final category =
        gatewayFailure?.category.trim().isNotEmpty == true
            ? gatewayFailure!.category
            : failureCategory;
    final stageText =
        gatewayFailure?.stage.trim().isNotEmpty == true
            ? gatewayFailure!.stage
            : failureStage;
    return SourceSearchFailure(
      sourceId: toServerGatewaySourceId(sourceId),
      sourceName: sourceName,
      message:
          gatewayFailure?.message.trim().isNotEmpty == true
              ? gatewayFailure!.message
              : (message.isEmpty ? '服务器搜索失败' : message),
      code:
          gatewayFailure?.toErrorCode() ??
          (category == 'timeout' ? ErrorCode.network : ErrorCode.unknown),
      stage: stage,
      debugMessage:
          stageText.isEmpty && category.isEmpty ? null : '$stageText/$category',
      gatewayFailure: gatewayFailure,
    );
  }
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
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
