import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../errors/error_stage.dart';
import '../logging/app_logger.dart';
import '../network/request_context.dart';

class WebViewRequestPayload {
  const WebViewRequestPayload({
    required this.url,
    this.method = HttpRequestMethod.get,
    this.headers = const <String, String>{},
    this.body,
    this.contentType,
    this.webJs,
    this.sourceRegex,
    this.stage = ErrorStage.search,
    this.sourceId,
    this.timeout,
  });

  final String url;
  final HttpRequestMethod method;
  final Map<String, String> headers;
  final Object? body;
  final String? contentType;
  final String? webJs;
  final String? sourceRegex;
  final ErrorStage stage;
  final String? sourceId;
  final Duration? timeout;
}

class WebViewResponsePayload {
  const WebViewResponsePayload({
    required this.statusCode,
    required this.body,
    required this.finalUrl,
    this.matchedResourceUrl,
  });

  final int statusCode;
  final String body;
  final String finalUrl;
  final String? matchedResourceUrl;
}

abstract class WebViewSession {
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
    required Duration timeout,
  });

  Future<void> dispose();
}

typedef WebViewSessionFactory = WebViewSession Function(int workerIndex);

class WebViewExecutor {
  WebViewExecutor({
    AppLogger? logger,
    this.defaultTimeout = const Duration(seconds: 30),
    int poolSize = 2,
    WebViewSessionFactory? sessionFactory,
  }) : _logger = logger ?? AppLogger.instance,
       poolSize = poolSize < 1 ? 1 : poolSize,
       _sessionFactory = sessionFactory ?? ((_) => _HeadlessWebViewSession());

  final AppLogger _logger;
  final Duration defaultTimeout;
  final int poolSize;
  final WebViewSessionFactory _sessionFactory;

  final List<_WebViewWorker> _workers = <_WebViewWorker>[];
  var _nextWorkerCursor = 0;
  var _disposed = false;

  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
  }) async {
    if (_disposed) {
      throw StateError('WebViewExecutor has been disposed.');
    }

    final prepared = _normalizeRequest(request);
    final worker = _selectWorker();

    try {
      return await worker.run(
        request: prepared.request,
        timeout: prepared.timeout,
      );
    } on MissingPluginException {
      _logger.warn(
        'WebView plugin is unavailable',
        context: <String, Object?>{
          'sourceId': prepared.request.sourceId,
          'stage': prepared.request.stage.name,
          'url': prepared.request.url,
          'diagnostic': 'webview_plugin_unavailable',
        },
      );
      rethrow;
    } on TimeoutException {
      _logger.warn(
        'WebView request timeout',
        context: <String, Object?>{
          'sourceId': prepared.request.sourceId,
          'stage': prepared.request.stage.name,
          'url': prepared.request.url,
          'timeoutMs': prepared.timeout.inMilliseconds,
          'diagnostic': 'webview_timeout',
        },
      );
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
  }

  _PreparedWebViewRequest _normalizeRequest(WebViewRequestPayload request) {
    final normalizedUrl = request.url.trim();
    if (normalizedUrl.isEmpty) {
      throw StateError('WebView request url is empty.');
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('WebView request url is invalid: $normalizedUrl');
    }

    final mergedHeaders = <String, String>{...request.headers};
    final contentType = request.contentType?.trim();
    if (contentType != null &&
        contentType.isNotEmpty &&
        !mergedHeaders.keys.any((key) => key.toLowerCase() == 'content-type')) {
      mergedHeaders['Content-Type'] = contentType;
    }

    return _PreparedWebViewRequest(
      request: WebViewRequestPayload(
        url: uri.toString(),
        method: request.method,
        headers: Map<String, String>.unmodifiable(mergedHeaders),
        body: request.body,
        contentType: request.contentType,
        webJs: request.webJs,
        sourceRegex: request.sourceRegex,
        stage: request.stage,
        sourceId: request.sourceId,
        timeout: request.timeout,
      ),
      timeout: request.timeout ?? defaultTimeout,
    );
  }

  _WebViewWorker _selectWorker() {
    if (_workers.isEmpty) {
      for (var i = 0; i < poolSize; i += 1) {
        _workers.add(_WebViewWorker(index: i, sessionFactory: _sessionFactory));
      }
    }

    final start = _nextWorkerCursor;
    _nextWorkerCursor = (_nextWorkerCursor + 1) % _workers.length;

    var selected = _workers[start];
    for (var offset = 1; offset < _workers.length; offset += 1) {
      final candidate = _workers[(start + offset) % _workers.length];
      if (candidate.pendingCount < selected.pendingCount) {
        selected = candidate;
      }
    }
    return selected;
  }
}

class _PreparedWebViewRequest {
  const _PreparedWebViewRequest({required this.request, required this.timeout});

  final WebViewRequestPayload request;
  final Duration timeout;
}

class _WebViewWorker {
  _WebViewWorker({required this.index, required this.sessionFactory});

  final int index;
  final WebViewSessionFactory sessionFactory;

  WebViewSession? _session;
  Future<void> _chain = Future<void>.value();
  var _pendingCount = 0;
  var _disposed = false;

  int get pendingCount => _pendingCount;

  Future<WebViewResponsePayload> run({
    required WebViewRequestPayload request,
    required Duration timeout,
  }) {
    if (_disposed) {
      return Future<WebViewResponsePayload>.error(
        StateError('WebView worker has been disposed.'),
      );
    }

    final completer = Completer<WebViewResponsePayload>();
    _pendingCount += 1;

    _chain = _chain
        .catchError((_) {})
        .then(
          (_) => _runTask(
            request: request,
            timeout: timeout,
            completer: completer,
          ),
        );

    return completer.future;
  }

  Future<void> _runTask({
    required WebViewRequestPayload request,
    required Duration timeout,
    required Completer<WebViewResponsePayload> completer,
  }) async {
    try {
      final session = _session ??= sessionFactory(index);
      final response = await session.load(request: request, timeout: timeout);
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    } catch (error, stackTrace) {
      await _resetSession();
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    } finally {
      _pendingCount -= 1;
    }
  }

  Future<void> _resetSession() async {
    final session = _session;
    _session = null;
    if (session == null) {
      return;
    }
    try {
      await session.dispose();
    } catch (_) {
      // Ignore reset disposal errors.
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    try {
      await _chain;
    } catch (_) {
      // Ignore pending task failures during shutdown.
    }
    await _resetSession();
  }
}

class _HeadlessWebViewSession implements WebViewSession {
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  _ActiveWebViewLoad? _activeLoad;
  Future<void>? _startFuture;
  var _disposed = false;

  @override
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
    required Duration timeout,
  }) async {
    if (_disposed) {
      throw StateError('WebView session has been disposed.');
    }

    await _ensureStarted();
    final controller = _controller;
    if (controller == null) {
      throw StateError('WebView controller is unavailable.');
    }

    final uri = Uri.tryParse(request.url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw StateError('WebView request url is invalid: ${request.url}');
    }

    final activeLoad = _ActiveWebViewLoad(
      request: request,
      sourceRegex: _compileSourceRegex(request.sourceRegex),
    );
    _activeLoad = activeLoad;

    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri.uri(uri),
        method: _methodText(request.method),
        headers: request.headers.isEmpty ? null : request.headers,
        body: _encodeRequestBody(request.body),
      ),
    );

    try {
      return await activeLoad.completer.future.timeout(timeout);
    } finally {
      if (identical(_activeLoad, activeLoad)) {
        _activeLoad = null;
      }
      try {
        await controller.stopLoading();
      } catch (_) {
        // Ignore stopLoading failure.
      }
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    final activeLoad = _activeLoad;
    _activeLoad = null;
    if (activeLoad != null && !activeLoad.completer.isCompleted) {
      activeLoad.completer.completeError(
        StateError('WebView session disposed during active request.'),
      );
    }

    final headless = _headless;
    _headless = null;
    _controller = null;

    if (headless != null) {
      try {
        await headless.dispose();
      } catch (_) {
        // Ignore dispose failure.
      }
    }
  }

  Future<void> _ensureStarted() async {
    if (_controller != null) {
      return;
    }
    if (_startFuture != null) {
      return _startFuture!;
    }

    final completer = Completer<void>();
    _startFuture = completer.future;

    final headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      onWebViewCreated: (controller) {
        _controller = controller;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onReceivedHttpError: (controller, resourceRequest, errorResponse) {
        final activeLoad = _activeLoad;
        if (activeLoad == null) {
          return;
        }

        final next = errorResponse.statusCode;
        if (next != null && next > 0) {
          activeLoad.statusCode = next;
        }
      },
      onReceivedError: (controller, resourceRequest, error) {
        final activeLoad = _activeLoad;
        if (activeLoad == null || activeLoad.completer.isCompleted) {
          return;
        }
        activeLoad.completer.completeError(
          StateError('WebView load failed: ${error.description}'),
        );
      },
      onLoadResource: (controller, loadedResource) {
        final activeLoad = _activeLoad;
        if (activeLoad == null || activeLoad.matchedResourceUrl != null) {
          return;
        }

        final sourceRegex = activeLoad.sourceRegex;
        if (sourceRegex == null) {
          return;
        }

        final resourceUrl = loadedResource.url?.toString().trim();
        if (resourceUrl == null || resourceUrl.isEmpty) {
          return;
        }
        if (sourceRegex.hasMatch(resourceUrl)) {
          activeLoad.matchedResourceUrl = resourceUrl;
        }
      },
      onLoadStop: (controller, loadedUrl) async {
        final activeLoad = _activeLoad;
        if (activeLoad == null || activeLoad.completer.isCompleted) {
          return;
        }

        try {
          final webJs = activeLoad.request.webJs?.trim();
          if (webJs != null && webJs.isNotEmpty) {
            await controller.evaluateJavascript(source: webJs);
          }

          final html = await controller.evaluateJavascript(
            source: 'document.documentElement.outerHTML',
          );
          final currentUrl = await controller.getUrl();
          activeLoad.complete(
            WebViewResponsePayload(
              statusCode: activeLoad.statusCode,
              body: _stringifyJsValue(html),
              finalUrl:
                  currentUrl?.toString().trim().isNotEmpty == true
                      ? currentUrl.toString()
                      : (loadedUrl?.toString() ?? activeLoad.request.url),
              matchedResourceUrl: activeLoad.matchedResourceUrl,
            ),
          );
        } catch (error) {
          activeLoad.completeError(StateError('WebView evaluate failed: $error'));
        }
      },
    );

    _headless = headless;

    try {
      await headless.run();
      _controller ??= headless.webViewController;
      if (_controller != null && !completer.isCompleted) {
        completer.complete();
      }
      await completer.future;
    } catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      rethrow;
    } finally {
      _startFuture = null;
    }
  }

  Uint8List? _encodeRequestBody(Object? body) {
    if (body == null) {
      return null;
    }
    if (body is List<int>) {
      return Uint8List.fromList(body);
    }
    if (body is String) {
      return Uint8List.fromList(utf8.encode(body));
    }
    if (body is Map || body is List) {
      return Uint8List.fromList(utf8.encode(jsonEncode(body)));
    }
    return Uint8List.fromList(utf8.encode(body.toString()));
  }

  String _methodText(HttpRequestMethod method) {
    return switch (method) {
      HttpRequestMethod.get => 'GET',
      HttpRequestMethod.post => 'POST',
    };
  }

  String _stringifyJsValue(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }

  RegExp? _compileSourceRegex(String? sourceRegex) {
    final pattern = sourceRegex?.trim();
    if (pattern == null || pattern.isEmpty) {
      return null;
    }

    try {
      return RegExp(pattern);
    } catch (_) {
      return null;
    }
  }
}

class _ActiveWebViewLoad {
  _ActiveWebViewLoad({required this.request, required this.sourceRegex});

  final WebViewRequestPayload request;
  final RegExp? sourceRegex;
  final Completer<WebViewResponsePayload> completer =
      Completer<WebViewResponsePayload>();

  var statusCode = 200;
  String? matchedResourceUrl;

  void complete(WebViewResponsePayload payload) {
    if (!completer.isCompleted) {
      completer.complete(payload);
    }
  }

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      if (stackTrace != null) {
        completer.completeError(error, stackTrace);
      } else {
        completer.completeError(error);
      }
    }
  }
}
