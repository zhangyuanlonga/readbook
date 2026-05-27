import '../../../core/errors/app_exception.dart';

class ReaderFailurePresentation {
  const ReaderFailurePresentation({
    required this.message,
    required this.primaryActionLabel,
    required this.allowRetry,
    required this.allowSourceSwitch,
    required this.allowWebLogin,
  });

  final String message;
  final String primaryActionLabel;
  final bool allowRetry;
  final bool allowSourceSwitch;
  final bool allowWebLogin;
}

class ReaderFailurePresentationService {
  const ReaderFailurePresentationService();

  ReaderFailurePresentation resolve(AppException error) {
    final failure = error.gatewayFailure;
    final actionHint = failure?.actionHint.trim() ?? '';
    final baseMessage =
        error.briefMessage.trim().isEmpty
            ? '章节加载失败。'
            : error.briefMessage.trim();
    final message =
        actionHint.isEmpty ? baseMessage : '$baseMessage\n$actionHint';
    final allowWebLogin =
        failure?.isLoginRequired == true || failure?.isWebViewRequired == true;
    final retryable = failure?.retryable ?? true;

    return ReaderFailurePresentation(
      message: message,
      primaryActionLabel:
          allowWebLogin
              ? '网页登录'
              : retryable
              ? '重试'
              : '换源',
      allowRetry: retryable,
      allowSourceSwitch: true,
      allowWebLogin: allowWebLogin,
    );
  }
}
