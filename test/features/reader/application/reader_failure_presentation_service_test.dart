import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_failure_presentation_service.dart';

void main() {
  group('ReaderFailurePresentationService', () {
    test('turns login failure into web login action', () {
      final presentation = const ReaderFailurePresentationService().resolve(
        const AppException(
          code: ErrorCode.validation,
          briefMessage: '需要登录',
          gatewayFailure: GatewayFailure(
            stage: 'content',
            category: 'loginRequired',
            code: 'LOGIN_REQUIRED',
            message: 'login required',
            retryable: false,
            hint: '请登录后重试',
          ),
        ),
      );

      expect(presentation.allowWebLogin, isTrue);
      expect(presentation.primaryActionLabel, '网页登录');
      expect(presentation.message, contains('客户端 WebView'));
    });

    test('keeps retry available for retryable upstream failures', () {
      final presentation = const ReaderFailurePresentationService().resolve(
        const AppException(
          code: ErrorCode.network,
          briefMessage: '上游超时',
          gatewayFailure: GatewayFailure(
            stage: 'content',
            category: 'timeout',
            code: 'UPSTREAM_TIMEOUT',
            message: 'timeout',
            retryable: true,
            hint: '稍后重试',
          ),
        ),
      );

      expect(presentation.allowRetry, isTrue);
      expect(presentation.allowWebLogin, isFalse);
      expect(presentation.primaryActionLabel, '重试');
    });
  });
}
