import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_error_presenter.dart';

void main() {
  group('ReaderErrorPresenter', () {
    const presenter = ReaderErrorPresenter();

    test('uses local book policy for local content failures', () {
      const error = AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在',
      );

      expect(
        presenter.userReadableError(error, isLocalContent: true),
        '未找到本地书籍，请确认文件是否存在或重新导入。',
      );
    });

    test('resolves gateway presentation and recovery stage', () {
      const error = AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '登录失效',
        gatewayFailure: GatewayFailure(
          stage: 'detail',
          category: 'loginRequired',
          code: 'LOGIN_REQUIRED',
          message: '登录态失效',
          retryable: false,
          hint: '',
        ),
      );

      final presentation = presenter.gatewayPresentationFor(error);

      expect(presentation, isNotNull);
      expect(presentation!.allowWebLogin, isTrue);
      expect(presentation.primaryActionLabel, '网页登录');
      expect(presenter.gatewayFailureStageFor(error), 'detail');
      expect(
        presenter.userReadableError(error, isLocalContent: false),
        contains('登录失效'),
      );
    });
  });
}
