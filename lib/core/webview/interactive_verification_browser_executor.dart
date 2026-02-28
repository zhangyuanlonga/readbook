import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../logging/app_logger.dart';
import '../navigation/global_navigator.dart';
import '../network/request_context.dart';
import 'webview_executor.dart';

class InteractiveVerificationBrowserExecutor {
  InteractiveVerificationBrowserExecutor({
    GlobalKey<NavigatorState>? navigatorKey,
    AppLogger? logger,
    this.defaultTimeout = const Duration(minutes: 5),
  }) : _navigatorKey = navigatorKey ?? globalRootNavigatorKey,
       _logger = logger ?? AppLogger.instance;

  static final InteractiveVerificationBrowserExecutor instance =
      InteractiveVerificationBrowserExecutor();

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLogger _logger;
  final Duration defaultTimeout;

  Future<void> _queue = Future<void>.value();

  Future<WebViewResponsePayload> open({
    required WebViewRequestPayload request,
    required bool awaitUserResult,
    String? title,
    bool refetchAfterSuccess = true,
  }) {
    final completer = Completer<WebViewResponsePayload>();
    _queue = _queue
        .catchError((_) {})
        .then(
          (_) async => _runTask(
            request: request,
            awaitUserResult: awaitUserResult,
            title: title,
            refetchAfterSuccess: refetchAfterSuccess,
            completer: completer,
          ),
        );
    return completer.future;
  }

  Future<void> _runTask({
    required WebViewRequestPayload request,
    required bool awaitUserResult,
    required String? title,
    required bool refetchAfterSuccess,
    required Completer<WebViewResponsePayload> completer,
  }) async {
    final normalizedRequest = _normalizeRequest(request);
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState == null) {
      _logger.warn(
        'Interactive verification navigator is unavailable',
        context: <String, Object?>{
          'sourceId': request.sourceId,
          'stage': request.stage.name,
          'url': request.url,
          'diagnostic': 'interactive_verification_navigator_unavailable',
        },
      );
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Navigator is unavailable for interactive verification.'),
        );
      }
      return;
    }

    _logger.info(
      'Interactive verification started',
      context: <String, Object?>{
        'sourceId': request.sourceId,
        'stage': request.stage.name,
        'url': normalizedRequest.url,
        'awaitUserResult': awaitUserResult,
      },
    );

    final route = MaterialPageRoute<_InteractiveVerificationResult>(
      fullscreenDialog: true,
      builder:
          (context) => _InteractiveVerificationPage(
            request: normalizedRequest,
            title: title?.trim().isNotEmpty == true ? title!.trim() : '网页验证',
            awaitUserResult: awaitUserResult,
            refetchAfterSuccess: refetchAfterSuccess,
          ),
    );

    if (!awaitUserResult) {
      unawaited(navigatorState.push(route));
      if (!completer.isCompleted) {
        completer.complete(
          WebViewResponsePayload(
            statusCode: 200,
            body: '',
            finalUrl: normalizedRequest.url,
          ),
        );
      }
      return;
    }

    final timeout = normalizedRequest.timeout ?? defaultTimeout;
    try {
      final result = await navigatorState
          .push(route)
          .timeout(
            timeout,
            onTimeout: () {
              try {
                navigatorState.removeRoute(route);
              } catch (_) {
                // Ignore route removal failures on timeout.
              }
              throw TimeoutException('Interactive verification timeout.');
            },
          );
      if (result == null) {
        throw StateError('Interactive verification was cancelled.');
      }
      if (!completer.isCompleted) {
        completer.complete(
          WebViewResponsePayload(
            statusCode: result.statusCode,
            body: result.body,
            finalUrl: result.finalUrl,
            matchedResourceUrl: result.matchedResourceUrl,
            matchedOverrideUrl: result.matchedOverrideUrl,
            scriptResult: result.scriptResult,
          ),
        );
      }
      _logger.info(
        'Interactive verification completed',
        context: <String, Object?>{
          'sourceId': request.sourceId,
          'stage': request.stage.name,
          'url': result.finalUrl,
        },
      );
    } catch (error, stackTrace) {
      _logger.warn(
        'Interactive verification failed',
        context: <String, Object?>{
          'sourceId': request.sourceId,
          'stage': request.stage.name,
          'url': normalizedRequest.url,
          'briefMessage': error.toString(),
          'diagnostic': 'interactive_verification_failed',
        },
      );
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  }

  WebViewRequestPayload _normalizeRequest(WebViewRequestPayload request) {
    var normalizedUrl = request.url.trim();
    final normalizedHtml = request.html;
    if (normalizedUrl.isEmpty &&
        normalizedHtml != null &&
        normalizedHtml.trim().isNotEmpty) {
      normalizedUrl = 'about:blank';
    }
    if (normalizedUrl.isEmpty) {
      throw StateError('Interactive verification url is empty.');
    }

    final uri = Uri.tryParse(normalizedUrl);
    final hasValidHost = uri?.host.trim().isNotEmpty == true;
    final isAboutBlank = uri?.scheme == 'about';
    if (uri == null || !uri.hasScheme || (!hasValidHost && !isAboutBlank)) {
      throw StateError(
        'Interactive verification url is invalid: $normalizedUrl',
      );
    }

    return WebViewRequestPayload(
      url: uri.toString(),
      method: request.method,
      headers: request.headers,
      body: request.body,
      contentType: request.contentType,
      html: request.html,
      webJs: request.webJs,
      sourceRegex: request.sourceRegex,
      overrideUrlRegex: request.overrideUrlRegex,
      stage: request.stage,
      sourceId: request.sourceId,
      timeout: request.timeout,
    );
  }
}

class _InteractiveVerificationPage extends StatefulWidget {
  const _InteractiveVerificationPage({
    required this.request,
    required this.title,
    required this.awaitUserResult,
    required this.refetchAfterSuccess,
  });

  final WebViewRequestPayload request;
  final String title;
  final bool awaitUserResult;
  final bool refetchAfterSuccess;

  @override
  State<_InteractiveVerificationPage> createState() =>
      _InteractiveVerificationPageState();
}

class _InteractiveVerificationPageState
    extends State<_InteractiveVerificationPage> {
  InAppWebViewController? _controller;
  String _currentUrl = '';
  int _statusCode = 200;
  bool _submitting = false;
  String _lastError = '';
  String _scriptResult = '';
  String? _matchedResourceUrl;
  String? _matchedOverrideUrl;
  RegExp? _sourceRegex;
  RegExp? _overrideUrlRegex;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.request.url;
    _sourceRegex = _compileRegex(widget.request.sourceRegex);
    _overrideUrlRegex = _compileRegex(widget.request.overrideUrlRegex);
  }

  @override
  Widget build(BuildContext context) {
    final initialData = _buildInitialData(widget.request);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.awaitUserResult)
            TextButton(
              onPressed: _submitting ? null : _finishVerification,
              child:
                  _submitting
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('完成验证'),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHintBar(context),
          Expanded(
            child: InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              initialData: initialData,
              initialUrlRequest:
                  initialData == null
                      ? _buildInitialUrlRequest(widget.request)
                      : null,
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              onReceivedHttpError: (
                controller,
                resourceRequest,
                errorResponse,
              ) {
                final next = errorResponse.statusCode;
                if (next != null && next > 0) {
                  _statusCode = next;
                }
              },
              onReceivedError: (controller, request, error) {
                _lastError = error.description;
                _statusCode = 0;
                if (mounted) {
                  setState(() {});
                }
              },
              onLoadResource: (controller, loadedResource) {
                final regex = _sourceRegex;
                if (regex == null || _matchedResourceUrl != null) {
                  return;
                }
                final resourceUrl = loadedResource.url?.toString().trim() ?? '';
                if (resourceUrl.isEmpty) {
                  return;
                }
                if (regex.hasMatch(resourceUrl)) {
                  _matchedResourceUrl = resourceUrl;
                }
              },
              onUpdateVisitedHistory: (controller, updatedUrl, _) {
                final value = updatedUrl?.toString().trim() ?? '';
                if (value.isNotEmpty) {
                  _currentUrl = value;
                }
                final regex = _overrideUrlRegex;
                if (regex != null &&
                    _matchedOverrideUrl == null &&
                    value.isNotEmpty &&
                    regex.hasMatch(value)) {
                  _matchedOverrideUrl = value;
                }
              },
              onLoadStop: (controller, loadedUrl) async {
                final loaded = loadedUrl?.toString().trim() ?? '';
                if (loaded.isNotEmpty) {
                  _currentUrl = loaded;
                }
                await _evaluateConfiguredScript();
                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
          if (_lastError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text(
                _lastError,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red.shade700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHintBar(BuildContext context) {
    final message =
        widget.awaitUserResult
            ? '请在页面中完成验证码/滑块后点击“完成验证”。'
            : '验证页面已打开，可手动完成后返回。';
    final refetchHint =
        widget.awaitUserResult && widget.refetchAfterSuccess
            ? '完成后将回传当前页面结果继续规则执行。'
            : null;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            if (refetchHint != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  refetchHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  URLRequest _buildInitialUrlRequest(WebViewRequestPayload request) {
    final uri = Uri.parse(request.url);
    return URLRequest(
      url: WebUri.uri(uri),
      method: _methodText(request.method),
      headers: request.headers.isEmpty ? null : request.headers,
      body: _encodeRequestBody(request.body),
    );
  }

  InAppWebViewInitialData? _buildInitialData(WebViewRequestPayload request) {
    final html = request.html?.trim();
    if (html == null || html.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(request.url);
    if (uri == null || !uri.hasScheme) {
      return InAppWebViewInitialData(
        data: html,
        mimeType: 'text/html',
        encoding: 'utf-8',
      );
    }
    return InAppWebViewInitialData(
      data: html,
      mimeType: 'text/html',
      encoding: 'utf-8',
      baseUrl: WebUri.uri(uri),
      historyUrl: WebUri.uri(uri),
    );
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

  RegExp? _compileRegex(String? pattern) {
    final raw = pattern?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return RegExp(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _evaluateConfiguredScript() async {
    final controller = _controller;
    final script = widget.request.webJs?.trim();
    if (controller == null || script == null || script.isEmpty) {
      return;
    }
    try {
      final value = await controller.evaluateJavascript(source: script);
      _scriptResult = _stringifyJsValue(value);
    } catch (_) {
      // Ignore script evaluation failures and keep page available for user.
    }
  }

  Future<void> _finishVerification() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
    });

    try {
      await _evaluateConfiguredScript();
      final html = await controller.evaluateJavascript(
        source: 'document.documentElement.outerHTML',
      );
      final currentUrl = await controller.getUrl();
      final nextUrl = currentUrl?.toString().trim() ?? _currentUrl;
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        _InteractiveVerificationResult(
          statusCode: _statusCode,
          body: _stringifyJsValue(html),
          finalUrl: nextUrl.isNotEmpty ? nextUrl : widget.request.url,
          matchedResourceUrl: _matchedResourceUrl,
          matchedOverrideUrl: _matchedOverrideUrl,
          scriptResult: _scriptResult,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '验证结果回传失败：$error';
      _lastError = message;
      setState(() {
        _submitting = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
}

class _InteractiveVerificationResult {
  const _InteractiveVerificationResult({
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
