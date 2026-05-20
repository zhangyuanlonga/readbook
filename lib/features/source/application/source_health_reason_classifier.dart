import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/session/session_cancellation.dart';
import '../../../domain/entities/source_health.dart';

class SourceHealthReasonClassifier {
  const SourceHealthReasonClassifier();

  SourceHealthFailureKind classify({
    AppException? appException,
    Object? error,
    String? message,
  }) {
    if (error is SessionTaskCancelledException) {
      return SourceHealthFailureKind.cancelled;
    }

    final normalizedMessage = (message ?? error?.toString() ?? '')
        .trim()
        .toLowerCase();

    if (appException != null) {
      switch (appException.code) {
        case ErrorCode.network:
          return SourceHealthFailureKind.network;
        case ErrorCode.ruleParse:
        case ErrorCode.decode:
          return SourceHealthFailureKind.parser;
        case ErrorCode.ruleMatchEmpty:
          return SourceHealthFailureKind.emptyResult;
        default:
          break;
      }
    }

    if (normalizedMessage.contains('timeout')) {
      return SourceHealthFailureKind.timeout;
    }
    if (normalizedMessage.contains('challenge') ||
        normalizedMessage.contains('captcha') ||
        normalizedMessage.contains('browser')) {
      return SourceHealthFailureKind.browserChallenge;
    }
    if (normalizedMessage.contains('disabled')) {
      return SourceHealthFailureKind.disabled;
    }
    return SourceHealthFailureKind.unknown;
  }
}
