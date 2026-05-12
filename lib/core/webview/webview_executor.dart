import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    this.html,
    this.webViewDelay,
    this.enabledCookieJar = false,
    this.webJs,
    this.sourceRegex,
    this.overrideUrlRegex,
    this.stage = ErrorStage.search,
    this.sourceId,
    this.timeout,
  });

  final String url;
  final HttpRequestMethod method;
  final Map<String, String> headers;
  final Object? body;
  final String? contentType;
  final String? html;
  final Duration? webViewDelay;
  final bool enabledCookieJar;
  final String? webJs;
  final String? sourceRegex;
  final String? overrideUrlRegex;
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
    this.matchedOverrideUrl,
    this.scriptResult,
  });

  final int statusCode;
  final String body;
  final String finalUrl;
  final String? matchedResourceUrl;
  final String? matchedOverrideUrl;
  final String? scriptResult;
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
    int? poolSize,
    WebViewSessionFactory? sessionFactory,
  }) : _logger = logger ?? AppLogger.instance,
       poolSize = _resolvePoolSize(poolSize),
       _sessionFactory = sessionFactory ?? ((_) => _HeadlessWebViewSession());

  final AppLogger _logger;
  final Duration defaultTimeout;
  final int poolSize;
  final WebViewSessionFactory _sessionFactory;

  static int _resolvePoolSize(int? configuredPoolSize) {
    final defaultPoolSize =
        !kIsWeb &&
                (defaultTargetPlatform == TargetPlatform.macOS ||
                    defaultTargetPlatform == TargetPlatform.windows ||
                    defaultTargetPlatform == TargetPlatform.linux)
            ? 1
            : 2;
    final resolved = configuredPoolSize ?? defaultPoolSize;
    return resolved < 1 ? 1 : resolved;
  }

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
    var normalizedUrl = request.url.trim();
    final normalizedHtml = request.html;
    if (normalizedUrl.isEmpty &&
        normalizedHtml != null &&
        normalizedHtml.trim().isNotEmpty) {
      normalizedUrl = 'about:blank';
    }
    if (normalizedUrl.isEmpty) {
      throw StateError('WebView request url is empty.');
    }

    final uri = Uri.tryParse(normalizedUrl);
    final hasValidHost = uri?.host.trim().isNotEmpty == true;
    final isAboutBlank = uri?.scheme == 'about';
    if (uri == null || !uri.hasScheme || (!hasValidHost && !isAboutBlank)) {
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
        html: request.html,
        webViewDelay: request.webViewDelay,
        enabledCookieJar: request.enabledCookieJar,
        webJs: request.webJs,
        sourceRegex: request.sourceRegex,
        overrideUrlRegex: request.overrideUrlRegex,
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
    final hasValidHost = uri?.host.trim().isNotEmpty == true;
    final isAboutBlank = uri?.scheme == 'about';
    if (uri == null || !uri.hasScheme || (!hasValidHost && !isAboutBlank)) {
      throw StateError('WebView request url is invalid: ${request.url}');
    }

    final activeLoad = _ActiveWebViewLoad(
      request: request,
      sourceRegex: _compileSourceRegex(request.sourceRegex),
      overrideUrlRegex: _compileSourceRegex(request.overrideUrlRegex),
    );
    _activeLoad = activeLoad;
    final inlineHtml = request.html;
    if (inlineHtml != null && inlineHtml.trim().isNotEmpty) {
      await controller.loadData(
        data: inlineHtml,
        baseUrl: WebUri.uri(uri),
        historyUrl: WebUri.uri(uri),
      );
    } else {
      await controller.loadUrl(
        urlRequest: URLRequest(
          url: WebUri.uri(uri),
          method: _methodText(request.method),
          headers: request.headers.isEmpty ? null : request.headers,
          body: _encodeRequestBody(request.body),
        ),
      );
    }

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
      onWebViewCreated: (controller) {
        _controller = controller;
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      onReceivedHttpError: (controller, resourceRequest, errorResponse) {
        final activeLoad = _activeLoad;
        if (activeLoad == null || resourceRequest.isForMainFrame == false) {
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
        if (_isIgnorableWebViewError(request: resourceRequest, error: error)) {
          return;
        }
        activeLoad.completer.completeError(
          StateError('WebView load failed: ${error.description}'),
        );
      },
      onReceivedServerTrustAuthRequest: (controller, challenge) async {
        return _buildServerTrustAuthResponse(challenge);
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
      onUpdateVisitedHistory: (controller, updatedUrl, _) {
        final activeLoad = _activeLoad;
        if (activeLoad == null || activeLoad.matchedOverrideUrl != null) {
          return;
        }
        final overrideRegex = activeLoad.overrideUrlRegex;
        if (overrideRegex == null) {
          return;
        }
        final candidate = updatedUrl?.toString().trim() ?? '';
        if (candidate.isEmpty) {
          return;
        }
        if (overrideRegex.hasMatch(candidate)) {
          activeLoad.matchedOverrideUrl = candidate;
        }
      },
      onLoadStop: (controller, loadedUrl) async {
        final activeLoad = _activeLoad;
        if (activeLoad == null || activeLoad.completer.isCompleted) {
          return;
        }

        try {
          await _waitForDocumentReady(controller);
          await _waitForRenderSettle(controller);
          final webViewDelay = activeLoad.request.webViewDelay;
          if (webViewDelay != null &&
              webViewDelay.inMilliseconds > 0 &&
              !activeLoad.completer.isCompleted) {
            await Future<void>.delayed(webViewDelay);
          }

          String? scriptResult;
          final webJs = activeLoad.request.webJs?.trim();
          if (webJs != null && webJs.isNotEmpty) {
            final scriptValue = await controller.evaluateJavascript(
              source: webJs,
            );
            scriptResult = _stringifyJsValue(scriptValue);
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
              matchedOverrideUrl: activeLoad.matchedOverrideUrl,
              scriptResult: scriptResult,
            ),
          );
        } catch (error) {
          activeLoad.completeError(
            StateError('WebView evaluate failed: $error'),
          );
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

  Future<void> _waitForDocumentReady(InAppWebViewController controller) async {
    const maxAttempts = 20;
    for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
      final state = await controller.evaluateJavascript(
        source: 'document.readyState',
      );
      final readyState = _stringifyJsValue(state).toLowerCase();
      if (readyState == 'complete' || readyState == 'interactive') {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _waitForRenderSettle(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(
        source: '''
          (async function() {
            if (typeof requestAnimationFrame !== 'function') {
              await new Promise(function(resolve) { setTimeout(resolve, 120); });
              return true;
            }
            await new Promise(function(resolve) {
              requestAnimationFrame(function() {
                requestAnimationFrame(resolve);
              });
            });
            return true;
          })();
        ''',
      );
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
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
      HttpRequestMethod.head => 'HEAD',
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

  bool _isIgnorableWebViewError({
    required WebResourceRequest request,
    required WebResourceError error,
  }) {
    final requestUrl = request.url.toString().trim().toLowerCase();
    if (requestUrl == 'about:blank') {
      return true;
    }
    if (error.type == WebResourceErrorType.CANCELLED) {
      return true;
    }
    final isMainFrame = request.isForMainFrame;
    if (isMainFrame != null && !isMainFrame) {
      return true;
    }
    final normalizedDescription = error.description.trim().toLowerCase();
    return normalizedDescription.contains('cancel');
  }

  ServerTrustAuthResponse _buildServerTrustAuthResponse(
    URLAuthenticationChallenge challenge,
  ) {
    final sslErrorCode = challenge.protectionSpace.sslError?.code;
    final action =
        sslErrorCode == null || sslErrorCode == SslErrorType.UNSPECIFIED
            ? ServerTrustAuthResponseAction.PROCEED
            : ServerTrustAuthResponseAction.CANCEL;
    return ServerTrustAuthResponse(action: action);
  }
}

class _ActiveWebViewLoad {
  _ActiveWebViewLoad({
    required this.request,
    required this.sourceRegex,
    required this.overrideUrlRegex,
  });

  final WebViewRequestPayload request;
  final RegExp? sourceRegex;
  final RegExp? overrideUrlRegex;
  final Completer<WebViewResponsePayload> completer =
      Completer<WebViewResponsePayload>();

  var statusCode = 200;
  String? matchedResourceUrl;
  String? matchedOverrideUrl;

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
