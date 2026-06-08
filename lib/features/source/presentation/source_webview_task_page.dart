import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/widgets/feature_disabled_page.dart';
import '../application/source_webview_task_service.dart';
import '../application/webview_cookie_bridge.dart';

class SourceWebViewTaskPage extends ConsumerStatefulWidget {
  const SourceWebViewTaskPage({
    super.key,
    required this.sourceId,
    required this.stage,
    this.mode,
    this.url,
    this.keyword,
    this.page,
    this.sourceRegex,
    this.overrideUrlRegex,
    this.javaScript,
    this.sourceName,
    this.bookId,
    this.detailUrl,
    this.tocUrl,
    this.chapterUrl,
    this.chapterIndex,
    this.chapterTitle,
    this.executionContext,
  });

  final String sourceId;
  final String stage;
  final String? mode;
  final String? url;
  final String? keyword;
  final int? page;
  final String? sourceRegex;
  final String? overrideUrlRegex;
  final String? javaScript;
  final String? sourceName;
  final String? bookId;
  final String? detailUrl;
  final String? tocUrl;
  final String? chapterUrl;
  final int? chapterIndex;
  final String? chapterTitle;
  final String? executionContext;

  @override
  ConsumerState<SourceWebViewTaskPage> createState() =>
      _SourceWebViewTaskPageState();
}

class _SourceWebViewTaskPageState extends ConsumerState<SourceWebViewTaskPage> {
  WebViewController? _controller;
  SourceWebViewTask? _task;
  Timer? _submitTimer;
  Timer? _timeoutTimer;
  int _progress = 0;
  bool _isSubmitting = false;
  bool _isFinished = false;
  String? _currentUrl;
  String? _matchedUrl;
  String? _statusText;
  String? _error;
  final Set<String> _resourceUrls = <String>{};

  bool get _isSupportedPlatform =>
      ref.read(appPlatformCapabilitiesProvider).supportsEmbeddedWebView;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url?.trim();
    if (_isSupportedPlatform) {
      unawaited(_bootstrapTask());
    }
  }

  @override
  void dispose() {
    _submitTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrapTask() async {
    if (widget.sourceId.trim().isEmpty) {
      _setError('缺少书源标识，无法创建 WebView 任务。');
      return;
    }
    _setStatus('正在创建 WebView 任务');

    try {
      final service = ref.read(sourceWebViewTaskServiceProvider);
      final task = await service.createTask(
        sourceId: widget.sourceId,
        stage: widget.stage,
        mode: widget.mode,
        url: widget.url,
        keyword: widget.keyword,
        page: widget.page,
        sourceRegex: widget.sourceRegex,
        overrideUrlRegex: widget.overrideUrlRegex,
        javaScript: widget.javaScript,
        bookRef: _bookRef,
        chapterRef: _chapterRef,
      );
      if (!mounted) return;

      final uri = Uri.tryParse(task.request.url.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        _setError('WebView 任务地址无效，无法打开页面。');
        return;
      }

      final controller =
          WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setNavigationDelegate(_buildNavigationDelegate());
      await controller.addJavaScriptChannel(
        webViewResourceSnifferChannelName,
        onMessageReceived: (message) {
          _captureResourceUrl(message.message);
        },
      );
      if (!mounted) return;
      setState(() {
        _task = task;
        _controller = controller;
        _currentUrl = task.request.url;
        _statusText = '正在加载页面';
        _error = null;
      });

      _startTimeoutTimer(task);
      await _loadTaskRequest(controller, task, uri);
    } catch (error) {
      if (!mounted) return;
      _setError('创建 WebView 任务失败：$error');
    }
  }

  NavigationDelegate _buildNavigationDelegate() {
    return NavigationDelegate(
      onNavigationRequest: (request) {
        _captureNavigatedUrl(request.url);
        return NavigationDecision.navigate;
      },
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      },
      onPageStarted: (url) {
        if (!mounted) return;
        _resourceUrls.clear();
        _captureNavigatedUrl(url);
        unawaited(_installResourceSniffer());
        setState(() {
          _progress = 0;
          _statusText = '正在加载页面';
          _error = null;
        });
      },
      onPageFinished: (url) {
        if (!mounted) return;
        _captureNavigatedUrl(url);
        unawaited(_installResourceSniffer());
        setState(() {
          _progress = 100;
          _statusText = '正在等待页面稳定';
        });
        _queueSubmit();
      },
      onWebResourceError: (error) {
        if (!mounted || error.isForMainFrame != true) return;
        setState(() {
          _error =
              error.description.trim().isEmpty
                  ? '页面加载失败'
                  : error.description.trim();
        });
      },
      onUrlChange: (change) {
        final url = change.url?.trim();
        if (url == null || url.isEmpty) return;
        _captureNavigatedUrl(url);
      },
    );
  }

  Future<void> _loadTaskRequest(
    WebViewController controller,
    SourceWebViewTask task,
    Uri uri,
  ) {
    final method =
        task.request.method == 'POST'
            ? LoadRequestMethod.post
            : LoadRequestMethod.get;
    final body = task.request.body;
    return controller.loadRequest(
      uri,
      method: method,
      headers: task.request.headers,
      body:
          body == null || body.isEmpty
              ? null
              : Uint8List.fromList(utf8.encode(body)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _pageTitle;
    final embeddedWebView = ref.watch(
      appPlatformCapabilitiesProvider.select(
        (capabilities) => capabilities.embeddedWebView,
      ),
    );
    if (!embeddedWebView.isSupported) {
      return FeatureDisabledPage(
        title: title,
        message:
            embeddedWebView.reason ??
            '当前平台暂不支持内嵌 WebView。请在 Android、iOS 或 macOS 客户端执行书源 WebView 任务。',
        icon: Icons.language_rounded,
      );
    }

    final controller = _controller;
    if (controller == null || _error != null) {
      return FeatureDisabledPage(
        title: title,
        message: _error ?? _statusText ?? '正在准备 WebView 任务。',
        icon:
            _error == null
                ? Icons.language_rounded
                : Icons.error_outline_rounded,
        actionLabel: _error == null ? null : '返回',
        onAction:
            _error == null
                ? null
                : () {
                  if (context.canPop()) {
                    context.pop();
                  }
                },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed:
                _isSubmitting
                    ? null
                    : () {
                      _submitTimer?.cancel();
                      controller.reload();
                    },
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submitNow,
            child:
                _isSubmitting
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('提交结果'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          _TaskNotice(
            statusText: _statusText,
            currentUrl: _currentUrl,
            matchedUrl: _matchedUrl,
          ),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    );
  }

  String get _pageTitle {
    final name = widget.sourceName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name WebView';
    }
    final taskName = _task?.sourceName.trim();
    if (taskName != null && taskName.isNotEmpty) {
      return '$taskName WebView';
    }
    return '书源 WebView';
  }

  SourceWebViewBookRef? get _bookRef {
    final detailUrl = widget.detailUrl?.trim();
    if (detailUrl == null || detailUrl.isEmpty) {
      return null;
    }
    return SourceWebViewBookRef(
      sourceId: widget.sourceId,
      detailUrl: detailUrl,
      bookId: widget.bookId,
      tocUrl: widget.tocUrl,
      executionContext: widget.executionContext,
    );
  }

  SourceWebViewChapterRef? get _chapterRef {
    final chapterUrl = widget.chapterUrl?.trim();
    if (chapterUrl == null || chapterUrl.isEmpty) {
      return null;
    }
    return SourceWebViewChapterRef(
      chapterUrl: chapterUrl,
      index: widget.chapterIndex,
      title: widget.chapterTitle,
      executionContext: widget.executionContext,
    );
  }

  void _captureNavigatedUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    final task = _task;
    final matched =
        task == null
            ? null
            : _firstRegexMatch(task.overrideUrlRegex, normalized) ??
                _firstRegexMatch(task.sourceRegex, normalized);
    if (!mounted) return;
    setState(() {
      _currentUrl = normalized;
      if (matched != null && matched.isNotEmpty) {
        _matchedUrl = matched;
      }
    });
    if (task?.mode == 'navigationSniff' && matched != null) {
      _queueSubmit(fast: true);
    }
  }

  void _captureResourceUrl(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return;
    _resourceUrls.add(normalized);
    final task = _task;
    final matched =
        task == null
            ? null
            : _firstRegexMatch(task.sourceRegex, normalized) ??
                _firstRegexMatch(task.overrideUrlRegex, normalized);
    if (!mounted) return;
    if (matched != null && matched.isNotEmpty) {
      setState(() => _matchedUrl = matched);
      if (task?.mode == 'resourceSniff') {
        _queueSubmit(fast: true);
      }
    }
  }

  void _startTimeoutTimer(SourceWebViewTask task) {
    _timeoutTimer?.cancel();
    final timeoutMs = task.timeoutMs <= 0 ? 60000 : task.timeoutMs;
    _timeoutTimer = Timer(Duration(milliseconds: timeoutMs), () {
      if (!mounted || _isFinished || _isSubmitting) return;
      unawaited(_submitNow());
    });
  }

  void _queueSubmit({bool fast = false}) {
    if (_isFinished || _isSubmitting) return;
    final task = _task;
    if (task == null) return;
    _submitTimer?.cancel();
    final waitMs =
        fast
            ? 300
            : task.delayMs > 0
            ? task.delayMs
            : task.request.webViewDelayTime ?? 600;
    _submitTimer = Timer(Duration(milliseconds: waitMs), () {
      if (!mounted || _isFinished || _isSubmitting) return;
      unawaited(_submitNow());
    });
  }

  Future<void> _submitNow() async {
    final task = _task;
    final controller = _controller;
    if (task == null || controller == null || _isSubmitting || _isFinished) {
      return;
    }
    _submitTimer?.cancel();
    setState(() {
      _isSubmitting = true;
      _statusText = '正在回传 WebView 结果';
    });

    try {
      final html = await _readHtml(controller, task);
      final resourceUrls = await _collectResourceUrls(controller);
      final finalUrl = await controller.currentUrl() ?? _currentUrl;
      final rawCookie = await _runJavaScript(controller, 'document.cookie');
      final rawLocalStorage = await _runJavaScript(
        controller,
        dumpWebViewLocalStorageScript,
      );
      final matchedUrl =
          _matchedUrl ??
          _firstResourceRegexMatch(task, resourceUrls) ??
          _firstRegexMatch(task.sourceRegex, html) ??
          _firstRegexMatch(task.overrideUrlRegex, finalUrl ?? '');
      final result = SourceWebViewResult(
        taskId: task.taskId,
        sourceId: task.sourceId,
        stage: task.stage,
        mode: task.mode,
        html: html.isEmpty ? null : html,
        matchedUrl: matchedUrl,
        finalUrl: finalUrl,
        cookies: normalizeWebViewCookieResult(rawCookie),
        localStorage: normalizeWebViewStringMapResult(rawLocalStorage),
      );
      final resolved = await ref
          .read(sourceWebViewTaskServiceProvider)
          .resolve(
            task: task,
            result: result,
            bookRef: _bookRef,
            chapterRef: _chapterRef,
          );
      if (!mounted) return;
      _timeoutTimer?.cancel();
      setState(() {
        _isFinished = true;
        _statusText = 'WebView 结果已提交';
      });
      _showMessage('WebView 结果已提交，可以重试当前书源。');
      if (context.canPop()) {
        context.pop(resolved.payload);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '提交 WebView 结果失败：$error';
        _isSubmitting = false;
      });
    }
  }

  Future<Object?> _runJavaScript(
    WebViewController controller,
    String script,
  ) async {
    try {
      return await controller.runJavaScriptReturningResult(script);
    } catch (_) {
      return null;
    }
  }

  Future<void> _installResourceSniffer() async {
    final controller = _controller;
    if (controller == null) return;
    final raw = await _runJavaScript(
      controller,
      installWebViewResourceSnifferScript,
    );
    for (final url in _stringListFromWebViewResult(raw)) {
      _captureResourceUrl(url);
    }
  }

  Future<List<String>> _collectResourceUrls(
    WebViewController controller,
  ) async {
    await _installResourceSniffer();
    final raw = await _runJavaScript(controller, dumpWebViewResourceUrlsScript);
    for (final url in _stringListFromWebViewResult(raw)) {
      _captureResourceUrl(url);
    }
    return _resourceUrls.toList(growable: false);
  }

  Future<String> _readHtml(
    WebViewController controller,
    SourceWebViewTask task,
  ) async {
    final script =
        _nonBlank(task.javaScript) ??
        _nonBlank(task.request.webJs) ??
        dumpWebViewDocumentHtmlScript;
    final raw = await _runJavaScript(controller, script);
    final html = normalizeWebViewStringResult(raw);
    if (html.isNotEmpty) {
      return html;
    }
    final fallback = await _runJavaScript(
      controller,
      dumpWebViewDocumentHtmlScript,
    );
    return normalizeWebViewStringResult(fallback);
  }

  String? _firstRegexMatch(String? pattern, String text) {
    final normalizedPattern = pattern?.trim();
    if (normalizedPattern == null ||
        normalizedPattern.isEmpty ||
        text.trim().isEmpty) {
      return null;
    }
    try {
      final match = RegExp(normalizedPattern, dotAll: true).firstMatch(text);
      if (match == null) {
        return null;
      }
      return (match.groupCount >= 1 ? match.group(1) : match.group(0))?.trim();
    } catch (_) {
      return null;
    }
  }

  String? _firstResourceRegexMatch(
    SourceWebViewTask task,
    Iterable<String> urls,
  ) {
    for (final url in urls) {
      final matched =
          _firstRegexMatch(task.sourceRegex, url) ??
          _firstRegexMatch(task.overrideUrlRegex, url);
      if (matched != null && matched.isNotEmpty) {
        return matched;
      }
    }
    return null;
  }

  List<String> _stringListFromWebViewResult(Object? value) {
    final text = normalizeWebViewStringResult(value);
    if (text.isEmpty) {
      return const <String>[];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        return const <String>[];
      }
      return decoded
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  String? _nonBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  void _setStatus(String message) {
    if (!mounted) return;
    setState(() {
      _statusText = message;
      _error = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isSubmitting = false;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TaskNotice extends StatelessWidget {
  const _TaskNotice({
    required this.statusText,
    required this.currentUrl,
    required this.matchedUrl,
  });

  final String? statusText;
  final String? currentUrl;
  final String? matchedUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = currentUrl?.trim();
    final matched = matchedUrl?.trim();
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                [
                      statusText?.trim(),
                      if (matched != null && matched.isNotEmpty) '命中：$matched',
                      if (url != null && url.isNotEmpty) '当前页面：$url',
                    ]
                    .whereType<String>()
                    .where((item) => item.isNotEmpty)
                    .join('\n'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
