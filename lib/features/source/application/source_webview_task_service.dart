import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_stage.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_config.dart';
import '../../search/application/server_gateway_identity.dart';

final sourceWebViewTaskServiceProvider = Provider<SourceWebViewTaskService>((
  ref,
) {
  return SourceWebViewTaskService();
});

class SourceWebViewTaskService {
  SourceWebViewTaskService({ApiClient? client, String? baseUrl})
    : _baseUrl = AppApiConfig.normalizeBaseUrl(
        baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
      ),
      _client =
          client ??
          ApiClient(
            baseUrl: AppApiConfig.normalizeBaseUrl(
              baseUrl ?? AppApiConfig.effectiveReaderGatewayBaseUrl,
            ),
            defaultTimeout: const Duration(seconds: 70),
          );

  final String _baseUrl;
  final ApiClient _client;

  Future<SourceWebViewTask> createTask({
    required String sourceId,
    required String stage,
    String? mode,
    String? url,
    String? keyword,
    int? page,
    String? sourceRegex,
    String? overrideUrlRegex,
    String? javaScript,
    SourceWebViewBookRef? bookRef,
    SourceWebViewChapterRef? chapterRef,
  }) {
    final gatewaySourceId = fromServerGatewaySourceId(sourceId);
    return _client.request<SourceWebViewTask>(
      method: ApiMethod.post,
      path: _gatewayPath(
        'v1/sources/${Uri.encodeComponent(gatewaySourceId)}/webview-task',
      ),
      body: <String, Object?>{
        'stage': stage.trim(),
        if (_text(mode) != null) 'mode': _text(mode),
        if (_text(url) != null) 'url': _text(url),
        if (_text(keyword) != null) 'keyword': _text(keyword),
        if (page != null) 'page': page,
        if (_text(sourceRegex) != null) 'sourceRegex': _text(sourceRegex),
        if (_text(overrideUrlRegex) != null)
          'overrideUrlRegex': _text(overrideUrlRegex),
        if (_text(javaScript) != null) 'javaScript': _text(javaScript),
        if (bookRef != null) 'bookRef': bookRef.toJson(),
        if (chapterRef != null) 'chapterRef': chapterRef.toJson(),
        'options': const <String, Object?>{'timeoutMs': 60000},
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 75),
      stage: _errorStage(stage),
      decoder: SourceWebViewTask.fromJson,
    );
  }

  Future<SourceWebViewResolveResult> resolve({
    required SourceWebViewTask task,
    required SourceWebViewResult result,
    SourceWebViewBookRef? bookRef,
    SourceWebViewChapterRef? chapterRef,
  }) {
    return _client.request<SourceWebViewResolveResult>(
      method: ApiMethod.post,
      path: _gatewayPath('v1/webview/resolve'),
      body: <String, Object?>{
        'sourceId': task.sourceId,
        'stage': task.stage,
        if (bookRef != null) 'bookRef': bookRef.toJson(),
        if (chapterRef != null) 'chapterRef': chapterRef.toJson(),
        'options': const <String, Object?>{'timeoutMs': 60000},
        'result': result.toJson(),
      },
      attachAccessToken: true,
      enableRetry: false,
      timeout: const Duration(seconds: 75),
      stage: _errorStage(task.stage),
      decoder: SourceWebViewResolveResult.fromJson,
    );
  }

  String _gatewayPath(String path) {
    return AppApiConfig.readerGatewayApiPath(_baseUrl, path);
  }
}

class SourceWebViewTask {
  const SourceWebViewTask({
    required this.taskId,
    required this.sourceId,
    required this.sourceName,
    required this.stage,
    required this.mode,
    required this.request,
    required this.baseUrl,
    this.javaScript,
    this.sourceRegex,
    this.overrideUrlRegex,
    this.delayMs = 0,
    this.timeoutMs = 60000,
  });

  final String taskId;
  final String sourceId;
  final String sourceName;
  final String stage;
  final String mode;
  final SourceWebViewRequestSnapshot request;
  final String baseUrl;
  final String? javaScript;
  final String? sourceRegex;
  final String? overrideUrlRegex;
  final int delayMs;
  final int timeoutMs;

  factory SourceWebViewTask.fromJson(Object? value) {
    final map = _asMap(value);
    return SourceWebViewTask(
      taskId: _string(map['taskId']),
      sourceId: _string(map['sourceId']),
      sourceName: _string(map['sourceName'], fallback: '书源 WebView'),
      stage: _string(map['stage'], fallback: 'content'),
      mode: _string(map['mode'], fallback: 'html'),
      request: SourceWebViewRequestSnapshot.fromJson(map['request']),
      baseUrl: _string(map['baseUrl']),
      javaScript: _text(map['javaScript']?.toString()),
      sourceRegex: _text(map['sourceRegex']?.toString()),
      overrideUrlRegex: _text(map['overrideUrlRegex']?.toString()),
      delayMs: _int(map['delayMs'], 0),
      timeoutMs: _int(map['timeoutMs'], 60000),
    );
  }
}

class SourceWebViewRequestSnapshot {
  const SourceWebViewRequestSnapshot({
    required this.url,
    required this.method,
    this.headers = const <String, String>{},
    this.body,
    this.webJs,
    this.webViewDelayTime,
  });

  final String url;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final String? webJs;
  final int? webViewDelayTime;

  factory SourceWebViewRequestSnapshot.fromJson(Object? value) {
    final map = _asMap(value);
    return SourceWebViewRequestSnapshot(
      url: _string(map['url']),
      method: _string(map['method'], fallback: 'GET').toUpperCase(),
      headers: _stringMap(map['headers']),
      body: _text(map['body']?.toString()),
      webJs: _text(map['webJs']?.toString()),
      webViewDelayTime: _optionalInt(map['webViewDelayTime']),
    );
  }
}

class SourceWebViewResult {
  const SourceWebViewResult({
    required this.taskId,
    required this.sourceId,
    required this.stage,
    required this.mode,
    this.html,
    this.matchedUrl,
    this.finalUrl,
    this.cookies,
    this.headers = const <String, String>{},
    this.localStorage = const <String, String>{},
    this.error,
  });

  final String taskId;
  final String sourceId;
  final String stage;
  final String mode;
  final String? html;
  final String? matchedUrl;
  final String? finalUrl;
  final String? cookies;
  final Map<String, String> headers;
  final Map<String, String> localStorage;
  final String? error;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'taskId': taskId,
      'sourceId': sourceId,
      'stage': stage,
      'mode': mode,
      if (_text(html) != null) 'html': _text(html),
      if (_text(matchedUrl) != null) 'matchedUrl': _text(matchedUrl),
      if (_text(finalUrl) != null) 'finalUrl': _text(finalUrl),
      if (_text(cookies) != null) 'cookies': _text(cookies),
      if (headers.isNotEmpty) 'headers': headers,
      if (localStorage.isNotEmpty) 'localStorage': localStorage,
      if (_text(error) != null) 'error': _text(error),
    };
  }
}

class SourceWebViewResolveResult {
  const SourceWebViewResolveResult({
    required this.stage,
    required this.sourceId,
    required this.payload,
  });

  final String stage;
  final String sourceId;
  final Map<String, Object?> payload;

  factory SourceWebViewResolveResult.fromJson(Object? value) {
    final map = _asMap(value);
    return SourceWebViewResolveResult(
      stage: _string(map['stage'], fallback: 'webview'),
      sourceId: _string(map['sourceId']),
      payload: _asMap(map['payload']),
    );
  }
}

class SourceWebViewBookRef {
  const SourceWebViewBookRef({
    required this.sourceId,
    required this.detailUrl,
    this.bookId,
    this.tocUrl,
    this.executionContext,
  });

  final String sourceId;
  final String detailUrl;
  final String? bookId;
  final String? tocUrl;
  final String? executionContext;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sourceId': fromServerGatewaySourceId(sourceId),
      if (_text(bookId) != null) 'bookId': _text(bookId),
      'detailUrl': detailUrl.trim(),
      if (_text(tocUrl) != null) 'tocUrl': _text(tocUrl),
      if (_text(executionContext) != null)
        'executionContext': _text(executionContext),
    };
  }
}

class SourceWebViewChapterRef {
  const SourceWebViewChapterRef({
    required this.chapterUrl,
    this.index,
    this.title,
    this.executionContext,
  });

  final String chapterUrl;
  final int? index;
  final String? title;
  final String? executionContext;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'chapterUrl': chapterUrl.trim(),
      if (index != null) 'index': index,
      if (_text(title) != null) 'title': _text(title),
      if (_text(executionContext) != null)
        'executionContext': _text(executionContext),
    };
  }
}

ErrorStage _errorStage(String stage) {
  switch (stage.trim()) {
    case 'detail':
      return ErrorStage.detail;
    case 'toc':
      return ErrorStage.toc;
    case 'content':
      return ErrorStage.content;
    case 'search':
      return ErrorStage.search;
    default:
      return ErrorStage.source;
  }
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
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
  return Map.unmodifiable(result);
}

String _string(Object? value, {String fallback = ''}) {
  return _text(value?.toString()) ?? fallback;
}

String? _text(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

int _int(Object? value, int fallback) {
  return _optionalInt(value) ?? fallback;
}

int? _optionalInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}
