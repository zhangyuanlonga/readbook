import 'error_codes.dart';
import 'error_stage.dart';

class GatewayFailure {
  const GatewayFailure({
    required this.stage,
    required this.category,
    required this.code,
    required this.message,
    this.httpStatus,
    required this.retryable,
    required this.hint,
  });

  final String stage;
  final String category;
  final String code;
  final String message;
  final int? httpStatus;
  final bool retryable;
  final String hint;

  factory GatewayFailure.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid gateway failure shape');
    }
    final map = value.map((key, value) => MapEntry(key.toString(), value));
    return GatewayFailure(
      stage: _stringOrDefault(map['stage'], 'unknown'),
      category: _stringOrDefault(map['category'], 'unknown'),
      code: _stringOrDefault(map['code'], 'UNKNOWN'),
      message: _stringOrDefault(map['message'], '网关执行失败。'),
      httpStatus: _optionalInt(map['httpStatus']),
      retryable: map['retryable'] == true,
      hint: _stringOrDefault(map['hint'], ''),
    );
  }

  static GatewayFailure? tryParse(Object? value) {
    try {
      if (value == null) {
        return null;
      }
      return GatewayFailure.fromJson(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'stage': stage,
      'category': category,
      'code': code,
      'message': message,
      if (httpStatus != null) 'httpStatus': httpStatus,
      'retryable': retryable,
      if (hint.trim().isNotEmpty) 'hint': hint,
    };
  }

  ErrorCode toErrorCode() {
    switch (code.trim().toUpperCase()) {
      case 'UPSTREAM_TIMEOUT':
        return ErrorCode.network;
      case 'PARSE_FAILED':
        return _categoryEquals('emptyResponse')
            ? ErrorCode.ruleMatchEmpty
            : ErrorCode.ruleParse;
      case 'LOGIN_REQUIRED':
        return ErrorCode.validation;
      case 'PROXY_FAILED':
      case 'RESOURCE_PROXY_FAILED':
      case 'UPSTREAM_ERROR':
        return ErrorCode.network;
      case 'NOT_FOUND':
        return ErrorCode.unknownSource;
      case 'BAD_REQUEST':
        return ErrorCode.validation;
      case 'INTERNAL_ERROR':
        return ErrorCode.unknown;
    }

    switch (category.trim()) {
      case 'timeout':
      case 'upstream':
      case 'dnsError':
      case 'connectRefused':
      case 'connectionReset':
      case 'tlsError':
      case 'proxyError':
      case 'resourceProxy':
        return ErrorCode.network;
      case 'parse':
      case 'jsError':
        return ErrorCode.ruleParse;
      case 'emptyResponse':
        return ErrorCode.ruleMatchEmpty;
      case 'loginRequired':
      case 'badRequest':
      case 'invalidUrl':
      case 'webviewRequired':
        return ErrorCode.validation;
      case 'notFound':
        return ErrorCode.unknownSource;
      default:
        return ErrorCode.unknown;
    }
  }

  ErrorStage toErrorStage({ErrorStage fallback = ErrorStage.unknown}) {
    switch (stage.trim()) {
      case 'search':
        return ErrorStage.search;
      case 'detail':
        return ErrorStage.detail;
      case 'toc':
        return ErrorStage.toc;
      case 'content':
      case 'imageProxy':
      case 'mediaProxy':
        return ErrorStage.content;
      default:
        return fallback;
    }
  }

  String get displayCode => code.trim().isEmpty ? 'UNKNOWN' : code.trim();

  String get displayHint {
    final normalizedHint = hint.trim();
    if (normalizedHint.isNotEmpty) {
      return normalizedHint;
    }
    return retryable ? '可以稍后重试，或切换其他书源。' : '建议检查书源配置或切换书源。';
  }

  bool get isLoginRequired =>
      code.trim().toUpperCase() == 'LOGIN_REQUIRED' ||
      _categoryEquals('loginRequired');

  bool get isWebViewRequired =>
      code.trim().toUpperCase() == 'WEBVIEW_REQUIRED' ||
      _categoryEquals('webviewRequired');

  bool get isAntiSpider => _categoryEquals('antiSpider');

  bool get isMissingSource =>
      code.trim().toUpperCase() == 'SOURCE_NOT_FOUND' ||
      code.trim().toUpperCase() == 'NOT_FOUND' ||
      _categoryEquals('notFound');

  String get actionHint {
    if (isLoginRequired) {
      return '该书源需要登录或登录态已失效，可先用客户端 WebView 完成登录并提交会话，再重试或切换其他书源。';
    }
    if (isWebViewRequired) {
      return '该书源依赖 WebView/浏览器环境，可在客户端执行 WebView 渲染任务后重试；仍失败时建议切换书源。';
    }
    if (isAntiSpider) {
      return '疑似触发反爬或限流，可稍后重试、降低并发，或切换其他书源。';
    }
    if (isMissingSource) {
      return '可能是书源被删除、取消授权，或当前账号不再属于该书源分组；建议换源或重新搜索。';
    }
    return retryable ? '可以稍后重试，或切换其他书源。' : '建议检查书源配置或切换书源。';
  }

  bool _categoryEquals(String value) =>
      category.trim().toLowerCase() == value.toLowerCase();
}

String _stringOrDefault(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
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
