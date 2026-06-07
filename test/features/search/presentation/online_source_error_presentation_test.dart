import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/features/search/presentation/online_source_error_presentation.dart';

void main() {
  const adapter = OnlineSourceErrorPresentationAdapter();

  test('maps online detail and toc failures to shared user messages', () {
    expect(
      adapter.forException(
        const AppException(
          code: ErrorCode.network,
          stage: ErrorStage.detail,
          briefMessage: 'timeout',
        ),
      ),
      '网络请求失败，请检查网络或更换书源后重试。',
    );
    expect(
      adapter.tocWarningFor(
        const AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.toc,
          briefMessage: 'empty',
        ),
      ),
      '未获取到目录内容，目录暂为空。',
    );
  });

  test('keeps validation fallback for source specific messages', () {
    expect(
      adapter.forException(
        const AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.search,
          briefMessage: '该书源需要登录。',
        ),
      ),
      '该书源需要登录。',
    );
  });
}
