import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../application/search_service.dart';

class OnlineSourceErrorPresentation {
  const OnlineSourceErrorPresentation({
    required this.message,
    required this.badge,
    required this.actionHint,
  });

  final String message;
  final String badge;
  final String actionHint;
}

/// 在线书源错误展示适配器。
///
/// 搜索、详情、目录和后续阅读器章节加载都应从这里拿用户可读文案，避免同一类
/// 书源异常在不同端、不同页面出现不同提示。
class OnlineSourceErrorPresentationAdapter {
  const OnlineSourceErrorPresentationAdapter();

  static const String missingSourceMessage =
      '当前保存的书源已失效或无权访问，请换源或从搜索重新进入。';

  OnlineSourceErrorPresentation fromFailure(SourceSearchFailure failure) {
    final gatewayFailure = failure.gatewayFailure;
    final message = _messageFor(
      code: failure.code,
      stage: failure.stage,
      fallback: failure.message,
      gatewayMessage: gatewayFailure?.message,
    );
    return OnlineSourceErrorPresentation(
      message: message,
      badge: failure.gatewayCode ?? failure.code.name,
      actionHint:
          gatewayFailure?.actionHint ??
          _actionHintFor(code: failure.code, retryable: failure.retryable),
    );
  }

  String forException(AppException error) {
    return _messageFor(
      code: error.code,
      stage: error.stage,
      fallback: error.briefMessage,
      gatewayMessage: error.gatewayFailure?.message,
    );
  }

  String forReaderContentException(AppException error) {
    final gatewayFailure = error.gatewayFailure;
    if (gatewayFailure != null) {
      final message = gatewayFailure.message.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }

    final message = error.briefMessage.trim();
    return switch (error.code) {
      ErrorCode.network when message.contains('状态码：403') =>
        '章节被源站拦截（403），请在书源配置 Referer/Origin/User-Agent 后重试。',
      ErrorCode.network when message.contains('状态码：404') =>
        '章节地址已失效（404），请刷新目录后重试。',
      ErrorCode.network when message.contains('超时') => '请求超时，请稍后重试或切换书源。',
      ErrorCode.validation
          when message.contains('正文') && message.contains('缺少') =>
        '书源缺少正文解析配置，无法读取该章节。',
      ErrorCode.validation => '书源配置不完整，无法继续阅读。',
      ErrorCode.ruleMatchEmpty when message.contains('解析为空') =>
        '正文解析未命中，当前章节暂无可读内容。',
      ErrorCode.ruleMatchEmpty => '当前章节没有可读取内容，请切换章节或书源。',
      _ => _contentMessageFor(error.code, message),
    };
  }

  String? tocWarningFor(AppException? error) {
    if (error == null) {
      return null;
    }
    return _tocWarningFor(
      code: error.code,
      fallback: error.briefMessage,
      gatewayMessage: error.gatewayFailure?.message,
    );
  }

  String genericFailureForStage(ErrorStage stage) {
    return switch (stage) {
      ErrorStage.source => '书源加载失败，请检查书源或稍后重试。',
      ErrorStage.search => '搜索失败，请稍后重试。',
      ErrorStage.toc => '目录加载失败，目录暂不可用。',
      ErrorStage.content || ErrorStage.reader => '章节加载失败，请稍后重试或切换书源。',
      ErrorStage.detail => '加载失败，请稍后重试。',
      ErrorStage.unknown => '加载失败，请稍后重试。',
    };
  }

  String _messageFor({
    required ErrorCode code,
    required ErrorStage stage,
    required String fallback,
    String? gatewayMessage,
  }) {
    final normalizedGatewayMessage = gatewayMessage?.trim() ?? '';
    final normalizedFallback = fallback.trim();
    if (normalizedGatewayMessage.isNotEmpty && code == ErrorCode.validation) {
      return normalizedGatewayMessage;
    }
    return switch (stage) {
      ErrorStage.source => _detailMessageFor(code, normalizedFallback),
      ErrorStage.search => _searchMessageFor(code, normalizedFallback),
      ErrorStage.toc => _tocWarningFor(
        code: code,
        fallback: normalizedFallback,
        gatewayMessage: normalizedGatewayMessage,
      ),
      ErrorStage.content ||
      ErrorStage.reader => _contentMessageFor(code, normalizedFallback),
      ErrorStage.detail ||
      ErrorStage.unknown => _detailMessageFor(code, normalizedFallback),
    };
  }

  String _searchMessageFor(ErrorCode code, String fallback) {
    return switch (code) {
      ErrorCode.network => '网络请求失败，请检查网络或稍后重试。',
      ErrorCode.validation => _nonEmpty(fallback, '书源配置不完整，暂时无法搜索。'),
      ErrorCode.ruleParse => '服务器书源解析规则异常，无法完成搜索。',
      ErrorCode.ruleMatchEmpty => '该书源没有返回有效搜索结果。',
      ErrorCode.decode => '搜索响应解析失败，可能是编码或格式不兼容。',
      ErrorCode.unknownSource => missingSourceMessage,
      ErrorCode.unknown => _nonEmpty(fallback, '搜索失败，请稍后重试。'),
    };
  }

  String _detailMessageFor(ErrorCode code, String fallback) {
    return switch (code) {
      ErrorCode.network => '网络请求失败，请检查网络或更换书源后重试。',
      ErrorCode.validation => _nonEmpty(fallback, '书源配置不完整，暂时无法加载详情。'),
      ErrorCode.ruleParse => '服务器书源解析规则异常，无法加载详情。',
      ErrorCode.ruleMatchEmpty => '未获取到有效内容，请更换书源或稍后重试。',
      ErrorCode.decode => '响应解析失败，可能是编码或格式不兼容。',
      ErrorCode.unknownSource => missingSourceMessage,
      ErrorCode.unknown => _nonEmpty(fallback, '加载失败，请稍后重试。'),
    };
  }

  String _contentMessageFor(ErrorCode code, String fallback) {
    return switch (code) {
      ErrorCode.network => '章节网络请求失败，请检查网络或切换书源后重试。',
      ErrorCode.validation => _nonEmpty(fallback, '书源配置不完整，暂时无法加载章节。'),
      ErrorCode.ruleParse => '服务器书源解析规则异常，无法加载章节。',
      ErrorCode.ruleMatchEmpty => '未获取到章节正文，请更换书源或稍后重试。',
      ErrorCode.decode => '章节响应解析失败，可能是编码或格式不兼容。',
      ErrorCode.unknownSource => missingSourceMessage,
      ErrorCode.unknown => _nonEmpty(fallback, '章节加载失败，请稍后重试。'),
    };
  }

  String _tocWarningFor({
    required ErrorCode code,
    required String fallback,
    String? gatewayMessage,
  }) {
    final normalizedGatewayMessage = gatewayMessage?.trim() ?? '';
    if (normalizedGatewayMessage.isNotEmpty && code == ErrorCode.validation) {
      return normalizedGatewayMessage;
    }
    return switch (code) {
      ErrorCode.network => '目录加载失败（网络异常），已展示详情。可稍后刷新目录重试。',
      ErrorCode.validation => _nonEmpty(fallback, '书源配置不完整，目录暂不可用。'),
      ErrorCode.ruleParse => '服务器书源解析规则异常，目录暂不可用。',
      ErrorCode.ruleMatchEmpty => '未获取到目录内容，目录暂为空。',
      ErrorCode.decode => '目录解析失败，目录暂不可用。',
      ErrorCode.unknownSource => '当前保存的书源已失效或无权访问，目录暂不可用。',
      ErrorCode.unknown => _nonEmpty(fallback, '目录加载失败，目录暂不可用。'),
    };
  }

  String _actionHintFor({required ErrorCode code, required bool retryable}) {
    if (retryable || code == ErrorCode.network) {
      return '可以稍后重试，或切换其他书源。';
    }
    if (code == ErrorCode.unknownSource) {
      return '可能是书源被删除、取消授权，或当前账号不再属于该书源分组；建议换源或重新搜索。';
    }
    return '建议检查书源配置或切换书源。';
  }

  String _nonEmpty(String value, String fallback) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}
