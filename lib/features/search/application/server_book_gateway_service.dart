import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../../core/network/interceptors.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import 'server_gateway_identity.dart';

class ServerBookGatewayService {
  ServerBookGatewayService({ApiClient? client, Dio? dio, String? baseUrl})
    : _baseUrl = (baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl).trim(),
      _dio = dio ?? Dio(),
      _client =
          client ??
          ApiClient(
            baseUrl:
                (baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl).trim(),
            defaultTimeout: const Duration(seconds: 70),
          ) {
    if (_dio.interceptors.whereType<NetworkLogInterceptor>().isEmpty) {
      _dio.interceptors.add(NetworkLogInterceptor(AppLogger.instance));
    }
  }

  final ApiClient _client;
  final Dio _dio;
  final String _baseUrl;

  Future<ServerGatewayDetailResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? tocUrl,
    String? executionContext,
    String? infoHtml,
    String? tocHtml,
    String? fallbackTitle,
    String? fallbackAuthor,
    String? coverUrl,
    bool refresh = false,
  }) {
    final gatewaySourceId = toServerGatewaySourceId(sourceId);
    return _client.request<ServerGatewayDetailResult>(
      method: ApiMethod.post,
      path: 'v1/books/detail',
      body: {
        'bookRef': {
          'bookId': bookId,
          'sourceId': fromServerGatewaySourceId(gatewaySourceId),
          'detailUrl': detailUrl,
          if ((tocUrl ?? '').trim().isNotEmpty) 'tocUrl': tocUrl!.trim(),
          if ((executionContext ?? '').trim().isNotEmpty)
            'executionContext': executionContext!.trim(),
          if ((infoHtml ?? '').trim().isNotEmpty) 'infoHtml': infoHtml!.trim(),
          if ((tocHtml ?? '').trim().isNotEmpty) 'tocHtml': tocHtml!.trim(),
        },
        'hints': {
          'title': fallbackTitle,
          'author': fallbackAuthor,
          'coverUrl': coverUrl,
        },
        'options': {'refresh': refresh, 'timeoutMs': 15000},
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 25),
      stage: ErrorStage.detail,
      decoder:
          (data) => ServerGatewayDetailResult.fromEnvelopeData(
            data,
            fallbackBookId: bookId,
            fallbackSourceId: gatewaySourceId,
            fallbackDetailUrl: detailUrl,
            fallbackTitle: fallbackTitle,
            fallbackAuthor: fallbackAuthor,
            fallbackCoverUrl: coverUrl,
          ),
    );
  }

  Future<ServerGatewayTocResult> loadToc({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? tocUrl,
    String? executionContext,
    bool refresh = false,
  }) {
    final gatewaySourceId = toServerGatewaySourceId(sourceId);
    final effectiveTocUrl =
        (tocUrl ?? '').trim().isNotEmpty ? tocUrl!.trim() : detailUrl.trim();
    return _client.request<ServerGatewayTocResult>(
      method: ApiMethod.post,
      path: 'v1/books/toc',
      body: {
        'bookRef': {
          'bookId': bookId,
          'sourceId': fromServerGatewaySourceId(gatewaySourceId),
          'detailUrl': detailUrl,
          if (effectiveTocUrl.isNotEmpty) 'tocUrl': effectiveTocUrl,
          if ((executionContext ?? '').trim().isNotEmpty)
            'executionContext': executionContext!.trim(),
        },
        'options': {'refresh': refresh, 'timeoutMs': 60000},
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 70),
      stage: ErrorStage.toc,
      decoder:
          (data) => ServerGatewayTocResult.fromEnvelopeData(
            data,
            fallbackBookId: bookId,
          ),
    );
  }

  Future<ServerGatewayTocResult> loadTocFirstBatch({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? tocUrl,
    String? executionContext,
    bool refresh = false,
  }) async {
    try {
      await for (final result in streamToc(
        sourceId: sourceId,
        bookId: bookId,
        detailUrl: detailUrl,
        tocUrl: tocUrl,
        executionContext: executionContext,
        refresh: refresh,
      )) {
        if (result.chapters.isNotEmpty) {
          return result;
        }
      }
    } catch (_) {
      // Keep old request/response behavior as a safe fallback.
    }
    return loadToc(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      tocUrl: tocUrl,
      executionContext: executionContext,
      refresh: refresh,
    );
  }

  Future<ServerGatewayTocResult> loadTocComplete({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? tocUrl,
    String? executionContext,
    bool refresh = false,
  }) async {
    ServerGatewayTocResult? latest;
    try {
      await for (final result in streamToc(
        sourceId: sourceId,
        bookId: bookId,
        detailUrl: detailUrl,
        tocUrl: tocUrl,
        executionContext: executionContext,
        refresh: refresh,
      )) {
        if (result.chapters.isNotEmpty) {
          latest = result;
        }
        if (result.isComplete) {
          if (result.chapters.isNotEmpty) {
            return result.copyWith(hasMore: false, isComplete: true);
          }
          final completed = latest;
          if (completed != null) {
            return completed.copyWith(
              hasMore: false,
              isComplete: true,
              loadedCount:
                  result.loadedCount > 0
                      ? result.loadedCount
                      : completed.loadedCount,
              cacheHit: completed.cacheHit || result.cacheHit,
            );
          }
        }
      }
    } catch (_) {
      final partial = latest;
      if (partial != null) {
        return partial;
      }
    }
    return loadToc(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      tocUrl: tocUrl,
      executionContext: executionContext,
      refresh: refresh,
    );
  }

  Stream<ServerGatewayTocResult> streamToc({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? tocUrl,
    String? executionContext,
    bool refresh = false,
  }) async* {
    final gatewaySourceId = toServerGatewaySourceId(sourceId);
    final effectiveTocUrl =
        (tocUrl ?? '').trim().isNotEmpty ? tocUrl!.trim() : detailUrl.trim();
    final url = _resolveUrl(
      'v1/books/toc/stream',
      queryParameters: <String, String>{
        'bookId': bookId,
        'sourceId': fromServerGatewaySourceId(gatewaySourceId),
        'detailUrl': detailUrl,
        if (effectiveTocUrl.isNotEmpty) 'tocUrl': effectiveTocUrl,
        if ((executionContext ?? '').trim().isNotEmpty)
          'executionContext': executionContext!.trim(),
        'refresh': refresh ? 'true' : 'false',
        'timeoutMs': '60000',
      },
    );
    final headers = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };
    final accessToken =
        await ApiClient.defaultAuthTokenRefresher?.getAccessToken();
    if ((accessToken ?? '').isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await _dio.get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: headers,
        sendTimeout: const Duration(seconds: 8),
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 75),
        validateStatus: (statusCode) => statusCode != null && statusCode < 600,
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 400) {
      throw NetworkException(
        briefMessage: '服务器目录加载失败，状态码：$statusCode',
        stage: ErrorStage.toc,
        requestUrl: url,
      );
    }
    final body = response.data;
    if (body == null) {
      throw const DecodeException(
        briefMessage: '服务器目录响应为空。',
        stage: ErrorStage.toc,
      );
    }

    final parser = _SseParser();
    await for (final chunk in utf8.decoder.bind(
      body.stream.cast<List<int>>(),
    )) {
      for (final event in parser.addChunk(chunk)) {
        final result = _tocResultFromEvent(event, fallbackBookId: bookId);
        if (result != null) {
          yield result;
        }
      }
    }
    for (final event in parser.close()) {
      final result = _tocResultFromEvent(event, fallbackBookId: bookId);
      if (result != null) {
        yield result;
      }
    }
  }

  Future<ServerGatewayContentResult> loadContent({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    required String chapterUrl,
    int? chapterIndex,
    String? chapterTitle,
    String? executionContext,
    bool refresh = false,
  }) {
    final gatewaySourceId = toServerGatewaySourceId(sourceId);
    return _client.request<ServerGatewayContentResult>(
      method: ApiMethod.post,
      path: 'v1/books/content',
      body: {
        'bookRef': {
          'bookId': bookId,
          'sourceId': fromServerGatewaySourceId(gatewaySourceId),
          'detailUrl': detailUrl,
          if ((executionContext ?? '').trim().isNotEmpty)
            'executionContext': executionContext!.trim(),
        },
        'chapterRef': {
          'chapterUrl': chapterUrl,
          if (chapterIndex != null) 'index': chapterIndex,
          if ((chapterTitle ?? '').trim().isNotEmpty)
            'title': chapterTitle!.trim(),
          if ((executionContext ?? '').trim().isNotEmpty)
            'executionContext': executionContext!.trim(),
        },
        'options': {
          'refresh': refresh,
          'format': 'auto',
          'includeImages': true,
          'followNextContent': true,
          'timeoutMs': 45000,
        },
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 55),
      stage: ErrorStage.content,
      decoder: ServerGatewayContentResult.fromEnvelopeData,
    );
  }

  String _resolveUrl(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
  }) {
    final normalized = path.trim();
    final resolved =
        normalized.startsWith('http://') || normalized.startsWith('https://')
            ? normalized
            : _baseUrl.isEmpty
            ? normalized
            : Uri.parse(_baseUrl).resolve(normalized).toString();
    final uri = Uri.parse(resolved);
    return uri.replace(queryParameters: queryParameters).toString();
  }
}

class ServerGatewayDetailResult {
  const ServerGatewayDetailResult({
    required this.detail,
    required this.sourceName,
    required this.cacheHit,
    this.executionContext,
  });

  final BookDetail detail;
  final String sourceName;
  final bool cacheHit;
  final String? executionContext;

  factory ServerGatewayDetailResult.fromEnvelopeData(
    Object? data, {
    required String fallbackBookId,
    required String fallbackSourceId,
    required String fallbackDetailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    String? fallbackCoverUrl,
  }) {
    final map = _asMap(data);
    final book = _asMap(map['book']);
    final report = _asMap(map['sourceReport']);
    final detailUrl =
        _optionalString(book['bookUrl']) ?? fallbackDetailUrl.trim();
    return ServerGatewayDetailResult(
      detail: BookDetail(
        id: fallbackBookId.trim().isEmpty ? detailUrl : fallbackBookId.trim(),
        sourceId: toServerGatewaySourceId(
          _optionalString(report['sourceId']) ?? fallbackSourceId,
        ),
        title:
            _optionalString(book['name']) ??
            _optionalString(fallbackTitle) ??
            '未知书籍',
        detailUrl: detailUrl,
        author:
            _optionalString(book['author']) ?? _optionalString(fallbackAuthor),
        intro: _optionalString(book['intro']),
        coverUrl:
            _optionalString(book['coverUrl']) ??
            _optionalString(fallbackCoverUrl),
        tocUrl: _optionalString(book['tocUrl']),
        latestChapterTitle: _optionalString(book['latestChapterTitle']),
        totalChapterNum: _intOrNull(book['totalChapterNum']),
        wordCount: _optionalString(book['wordCount']),
        category: _optionalString(book['kind']),
        tags: _stringList(book['tags']),
        updateTime: _optionalString(book['updateTime']),
        executionContext: _optionalString(map['executionContext']),
      ),
      sourceName: _optionalString(report['sourceName']) ?? '服务器书源',
      cacheHit: report['cacheHit'] == true,
      executionContext: _optionalString(map['executionContext']),
    );
  }
}

class ServerGatewayTocResult {
  const ServerGatewayTocResult({
    required this.chapters,
    required this.cacheHit,
    this.hasMore = false,
    this.loadedCount = 0,
    this.isComplete = true,
    this.executionContext,
  });

  final List<Chapter> chapters;
  final bool cacheHit;
  final bool hasMore;
  final int loadedCount;
  final bool isComplete;
  final String? executionContext;

  ServerGatewayTocResult copyWith({
    List<Chapter>? chapters,
    bool? cacheHit,
    bool? hasMore,
    int? loadedCount,
    bool? isComplete,
    String? executionContext,
  }) {
    return ServerGatewayTocResult(
      chapters: chapters ?? this.chapters,
      cacheHit: cacheHit ?? this.cacheHit,
      hasMore: hasMore ?? this.hasMore,
      loadedCount: loadedCount ?? this.loadedCount,
      isComplete: isComplete ?? this.isComplete,
      executionContext: executionContext ?? this.executionContext,
    );
  }

  factory ServerGatewayTocResult.fromEnvelopeData(
    Object? data, {
    required String fallbackBookId,
  }) {
    final map = _asMap(data);
    final report = _asMap(map['sourceReport']);
    final chapters = (map['chapters'] as List? ?? const <Object?>[])
        .map((item) => _chapterFromJson(item, fallbackBookId))
        .toList(growable: false);
    return ServerGatewayTocResult(
      chapters: chapters,
      cacheHit: report['cacheHit'] == true,
      hasMore: map['hasMore'] == true,
      loadedCount: _intOrDefault(map['loadedCount'], chapters.length),
      isComplete: map['hasMore'] != true,
      executionContext: _optionalString(map['executionContext']),
    );
  }
}

ServerGatewayTocResult? _tocResultFromEvent(
  _SseEvent event, {
  required String fallbackBookId,
}) {
  if (event.name != 'chapters' && event.name != 'end') {
    return null;
  }
  final map = _asMap(event.data);
  if (event.name == 'end') {
    return ServerGatewayTocResult(
      chapters: const <Chapter>[],
      cacheHit: _asMap(map['sourceReport'])['cacheHit'] == true,
      loadedCount: _intOrDefault(map['loadedCount'], 0),
      isComplete: map['isComplete'] != false,
      executionContext: _optionalString(map['executionContext']),
    );
  }
  final report = _asMap(map['sourceReport']);
  final chapters = (map['chapters'] as List? ?? const <Object?>[])
      .map((item) => _chapterFromJson(item, fallbackBookId))
      .toList(growable: false);
  return ServerGatewayTocResult(
    chapters: chapters,
    cacheHit: report['cacheHit'] == true,
    hasMore: map['hasMore'] == true,
    loadedCount: _intOrDefault(map['loadedCount'], chapters.length),
    isComplete: map['isComplete'] == true,
    executionContext: _optionalString(map['executionContext']),
  );
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

class ServerGatewayContentResult {
  const ServerGatewayContentResult({
    required this.content,
    required this.cacheHit,
    required this.contentType,
    required this.kind,
    required this.format,
    this.imageUrls = const <String>[],
    this.imageHeaders = const <String, String>{},
    this.audioUrl,
    this.audioManifestUrl,
    this.audioHeaders = const <String, String>{},
    this.executionContext,
  });

  final String content;
  final bool cacheHit;
  final String contentType;
  final String kind;
  final String format;
  final List<String> imageUrls;
  final Map<String, String> imageHeaders;
  final String? audioUrl;
  final String? audioManifestUrl;
  final Map<String, String> audioHeaders;
  final String? executionContext;

  factory ServerGatewayContentResult.fromEnvelopeData(Object? data) {
    final map = _asMap(data);
    final report = _asMap(map['sourceReport']);
    return ServerGatewayContentResult(
      content: map['content']?.toString() ?? '',
      cacheHit: report['cacheHit'] == true,
      contentType: _optionalString(map['contentType']) ?? '',
      kind: _optionalString(map['kind']) ?? '',
      format: _optionalString(map['format']) ?? 'plain',
      imageUrls: _firstStringList(map, const [
        'imageUrls',
        'images',
        'image_urls',
      ]),
      imageHeaders: _stringMap(map['imageHeaders'] ?? map['image_headers']),
      audioUrl: _optionalString(map['audioUrl'] ?? map['audio_url']),
      audioManifestUrl: _optionalString(
        map['audioManifestUrl'] ?? map['audio_manifest_url'],
      ),
      audioHeaders: _stringMap(map['audioHeaders'] ?? map['audio_headers']),
      executionContext: _optionalString(map['executionContext']),
    );
  }
}

Chapter _chapterFromJson(Object? value, String fallbackBookId) {
  final map = _asMap(value);
  final chapterUrl = map['url']?.toString().trim() ?? '';
  final index = _intOrDefault(map['index'], 0);
  return Chapter(
    id: '$fallbackBookId::gateway::$index::${chapterUrl.hashCode}',
    bookId: fallbackBookId,
    title: _optionalString(map['title']) ?? '第 ${index + 1} 章',
    chapterUrl: chapterUrl,
    index: index,
    isVolume: map['isVolume'] == true,
    executionContext: _optionalString(map['executionContext']),
  );
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

String? _optionalString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int _intOrDefault(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _intOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
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

List<String> _firstStringList(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final items = _stringList(map[key]);
    if (items.isNotEmpty) {
      return items;
    }
  }
  return const <String>[];
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  final result = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key?.toString().trim() ?? '';
    final itemValue = entry.value?.toString().trim() ?? '';
    if (key.isNotEmpty && itemValue.isNotEmpty) {
      result[key] = itemValue;
    }
  }
  return Map<String, String>.unmodifiable(result);
}
