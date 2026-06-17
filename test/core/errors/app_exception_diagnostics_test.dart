import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception_diagnostics.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';

void main() {
  test('copies app exception gateway failure and context', () {
    final diagnostics = AppExceptionDiagnostics.fromException(
      title: '章节正文诊断',
      scene: 'reader_content',
      userMessage: '章节网络请求失败，请检查网络或切换书源后重试。',
      timestamp: DateTime.utc(2026, 6, 17, 10, 30),
      error: const AppException(
        code: ErrorCode.network,
        stage: ErrorStage.content,
        briefMessage: '请求超时，请稍后重试。',
        sourceId: 'src_001',
        requestUrl: 'https://example.test/chapter/1',
        gatewayFailure: GatewayFailure(
          stage: 'content',
          category: 'timeout',
          code: 'UPSTREAM_TIMEOUT',
          message: '源站请求超时',
          httpStatus: 504,
          retryable: true,
          hint: '稍后重试或切换书源。',
        ),
      ),
      context: const <String, Object?>{
        'bookId': 'book_001',
        'title': '测试书',
        'chapterTitle': '第一章',
      },
    );

    final text = diagnostics.toClipboardText();

    expect(text, contains('scene: reader_content'));
    expect(text, contains('sourceId: src_001'));
    expect(text, contains('requestUrl: https://example.test/chapter/1'));
    expect(text, contains('code: UPSTREAM_TIMEOUT'));
    expect(text, contains('bookId: book_001'));
    expect(text, contains('"chapterTitle": "第一章"'));
  });
}
