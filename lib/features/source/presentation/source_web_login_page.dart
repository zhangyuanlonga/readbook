import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/layout/app_adaptive.dart';
import '../../../core/errors/app_exception.dart';
import '../application/source_login_runtime_service.dart';
import '../providers.dart';

typedef SourceWebLoginViewBuilder =
    Widget Function(
      BuildContext context,
      SourceWebLoginRequest request,
      ValueChanged<String> onUrlChanged,
    );

class SourceWebLoginPage extends ConsumerStatefulWidget {
  const SourceWebLoginPage({
    super.key,
    required this.sourceId,
    this.sourceLoginRuntimeService,
    this.webLoginViewBuilder,
  });

  final String sourceId;
  final SourceLoginRuntimeService? sourceLoginRuntimeService;
  final SourceWebLoginViewBuilder? webLoginViewBuilder;

  @override
  ConsumerState<SourceWebLoginPage> createState() => _SourceWebLoginPageState();
}

class _SourceWebLoginPageState extends ConsumerState<SourceWebLoginPage> {
  late final SourceLoginRuntimeService _sourceLoginRuntimeService;

  SourceWebLoginRequest? _request;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorText;
  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _sourceLoginRuntimeService =
        widget.sourceLoginRuntimeService ??
        ref.read(sourceLoginRuntimeServiceProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final request = await _sourceLoginRuntimeService.prepareWebLogin(
        widget.sourceId,
      );
      if (!mounted) {
        return;
      }
      if (request == null) {
        setState(() {
          _isLoading = false;
          _errorText = '当前书源未提供可用的网页登录地址。';
        });
        return;
      }
      setState(() {
        _request = request;
        _currentUrl = request.uri.toString();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is AppException ? error.briefMessage : '网页登录配置加载失败。';
      setState(() {
        _errorText = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _completeLogin() async {
    final request = _request;
    if (request == null || _isSubmitting) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final finalUri = Uri.tryParse((_currentUrl ?? '').trim()) ?? request.uri;
      await _sourceLoginRuntimeService.completeWebLogin(
        widget.sourceId,
        currentUri: finalUri,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('登录态已同步。')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is AppException ? error.briefMessage : '登录态同步失败。';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    return Scaffold(
      appBar: AppBar(
        title: Text(request?.sourceName ?? '网页登录'),
        actions: [
          TextButton(
            onPressed:
                _isLoading || _isSubmitting || request == null
                    ? null
                    : _completeLogin,
            child:
                _isSubmitting
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('完成登录'),
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody(context, request)),
    );
  }

  Widget _buildBody(BuildContext context, SourceWebLoginRequest? request) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      final metrics = AppAdaptiveMetrics.of(context);
      return Center(
        child: Padding(
          padding: EdgeInsets.all(metrics.pagePadding + metrics.contentGap),
          child: Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (request == null) {
      return const SizedBox.shrink();
    }
    if (widget.webLoginViewBuilder case final builder?) {
      return builder(context, request, _handleUrlChanged);
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: InAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          domStorageEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
        ),
        initialUrlRequest: URLRequest(
          url: WebUri.uri(request.uri),
          headers: request.headers,
        ),
        onLoadStart: (controller, url) {
          _handleUrlChanged(url?.toString() ?? request.uri.toString());
        },
        onLoadStop: (controller, url) async {
          _handleUrlChanged(url?.toString() ?? request.uri.toString());
        },
        onUpdateVisitedHistory: (controller, url, _) {
          _handleUrlChanged(url?.toString() ?? request.uri.toString());
        },
      ),
    );
  }

  void _handleUrlChanged(String url) {
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUrl = url.trim().isEmpty ? _currentUrl : url.trim();
    });
  }
}
