import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../app/platform/app_platform_capabilities.dart';
import '../../../app/widgets/feature_disabled_page.dart';
import '../application/source_runtime_session_service.dart';
import '../application/webview_cookie_bridge.dart';

const _dumpLocalStorageScript = '''
(() => {
  const data = {};
  for (let index = 0; index < localStorage.length; index += 1) {
    const key = localStorage.key(index);
    if (key) {
      data[key] = localStorage.getItem(key) || '';
    }
  }
  return JSON.stringify(data);
})()
''';

class SourceWebViewLoginPage extends ConsumerStatefulWidget {
  const SourceWebViewLoginPage({
    super.key,
    required this.sourceId,
    required this.loginUrl,
    this.sourceName,
  });

  final String sourceId;
  final String loginUrl;
  final String? sourceName;

  @override
  ConsumerState<SourceWebViewLoginPage> createState() =>
      _SourceWebViewLoginPageState();
}

class _SourceWebViewLoginPageState
    extends ConsumerState<SourceWebViewLoginPage> {
  WebViewController? _controller;
  int _progress = 0;
  bool _isSubmitting = false;
  String? _currentUrl;
  String? _error;

  bool get _isSupportedPlatform =>
      ref.read(appPlatformCapabilitiesProvider).supportsEmbeddedWebView;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.loginUrl.trim();
    if (_isSupportedPlatform) {
      _initializeController();
    }
  }

  void _initializeController() {
    if (widget.sourceId.trim().isEmpty) {
      _error = '缺少书源标识，无法提交登录会话。';
      return;
    }

    final uri = Uri.tryParse(widget.loginUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _error = '登录地址无效，无法打开 WebView。';
      return;
    }

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (progress) {
                if (!mounted) return;
                setState(() => _progress = progress);
              },
              onPageStarted: (url) {
                if (!mounted) return;
                setState(() {
                  _currentUrl = url;
                  _error = null;
                });
              },
              onPageFinished: (url) {
                if (!mounted) return;
                setState(() {
                  _currentUrl = url;
                  _progress = 100;
                });
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
                if (!mounted || url == null || url.isEmpty) return;
                setState(() => _currentUrl = url);
              },
            ),
          )
          ..loadRequest(uri);
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
            '当前平台暂不支持内嵌 WebView。可以在 Android、iOS 或 macOS 客户端中完成书源网页登录，再把会话提交给网关。',
        icon: Icons.language_rounded,
      );
    }

    final controller = _controller;
    if (controller == null || _error != null) {
      return FeatureDisabledPage(
        title: title,
        message: _error ?? '登录地址无效，无法打开 WebView。',
        icon: Icons.error_outline_rounded,
        actionLabel: '返回',
        onAction: () {
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
            onPressed: _isSubmitting ? null : controller.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _submitSession,
            child:
                _isSubmitting
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('提交会话'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          _SessionNotice(currentUrl: _currentUrl),
          Expanded(child: WebViewWidget(controller: controller)),
        ],
      ),
    );
  }

  String get _pageTitle {
    final name = widget.sourceName?.trim();
    if (name != null && name.isNotEmpty) {
      return '$name 登录';
    }
    return '书源登录';
  }

  Future<void> _submitSession() async {
    final controller = _controller;
    if (controller == null || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final rawCookie = await controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final cookie = normalizeWebViewCookieResult(rawCookie);
      final rawLocalStorage = await controller.runJavaScriptReturningResult(
        _dumpLocalStorageScript,
      );
      final localStorage = normalizeWebViewStringMapResult(rawLocalStorage);
      final hasCookie = hasUsableCookieHeader(cookie);
      if (!hasCookie && localStorage.isEmpty) {
        _showMessage('未读取到可用 Cookie 或 localStorage。请确认已完成登录，或该站点是否限制 JS 读取会话。');
        return;
      }

      final service = ref.read(sourceRuntimeSessionServiceProvider);
      await service.submitLoginResult(
        sourceId: widget.sourceId,
        cookies: hasCookie ? cookie : null,
        localStorage: localStorage,
        finalUrl: _currentUrl,
      );
      if (!mounted) return;
      _showMessage('登录会话已提交给网关，可以返回重试当前书源。');
      if (context.canPop()) {
        context.pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('提交会话失败：$error');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.currentUrl});

  final String? currentUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = currentUrl?.trim();
    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '登录完成后点“提交会话”。Flutter 只读取当前站点 Cookie 并提交给 Rust 网关短期使用，不在客户端解析书源规则。'
                '${url == null || url.isEmpty ? '' : '\n当前页面：$url'}',
                maxLines: 4,
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
