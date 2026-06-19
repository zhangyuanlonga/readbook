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

  test('explains stale online source references', () {
    expect(
      adapter.forException(
        const AppException(
          code: ErrorCode.unknownSource,
          stage: ErrorStage.detail,
          briefMessage: 'bookRef.sourceId not found',
        ),
      ),
      OnlineSourceErrorPresentationAdapter.missingSourceMessage,
    );
    expect(
      adapter.tocWarningFor(
        const AppException(
          code: ErrorCode.unknownSource,
          stage: ErrorStage.toc,
          briefMessage: 'bookRef.sourceId not found',
        ),
      ),
      '当前保存的书源已失效或无权访问，目录暂不可用。',
    );
  });

  test('maps reader content failures through shared online adapter', () {
    expect(
      adapter.forReaderContentException(
        const AppException(
          code: ErrorCode.network,
          stage: ErrorStage.content,
          briefMessage: '状态码：403',
        ),
      ),
      '章节被源站拦截（403），请在书源配置 Referer/Origin/User-Agent 后重试。',
    );
    expect(
      adapter.forReaderContentException(
        const AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '正文选择器缺少',
        ),
      ),
      '书源缺少正文解析配置，无法读取该章节。',
    );
    expect(
      adapter.forReaderContentException(
        const AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '解析为空',
        ),
      ),
      '正文解析未命中，当前章节暂无可读内容。',
    );
    expect(
      adapter.forReaderContentException(
        const AppException(
          code: ErrorCode.decode,
          stage: ErrorStage.content,
          briefMessage: 'bad bytes',
        ),
      ),
      '章节响应解析失败，可能是编码或格式不兼容。',
    );
  });
}
