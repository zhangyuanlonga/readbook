import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/features/reader/application/local/local_book_workflow_policy.dart';

void main() {
  group('LocalBookWorkflowPolicy', () {
    final now = DateTime.parse('2026-04-21T12:00:00.000Z');

    test('defaults import execution to background indexing', () {
      final mode = LocalBookWorkflowPolicy.resolveImportExecutionMode(
        format: LocalBookFormat.txt,
        waitForIndexingRequested: false,
      );

      expect(mode, LocalBookImportExecutionMode.backgroundIndex);
    });

    test('builds import success text for directory-ready flow', () {
      expect(
        LocalBookWorkflowPolicy.importSuccessMessage(
          successCount: 2,
          failureCount: 0,
          directoryReady: true,
        ),
        contains('目录已建立'),
      );
    });

    test('builds failed status text with reimport guidance', () {
      final book = LocalBook(
        id: 'local_1',
        title: '测试',
        format: LocalBookFormat.txt,
        storagePath: '/tmp/test.txt',
        fileSize: 1,
        createdAt: now,
        updatedAt: now,
        indexStatus: LocalBookIndexStatus.failed,
      );

      expect(LocalBookWorkflowPolicy.statusDescription(book), contains('重新导入'));
    });

    test('maps local reader errors to unified copy', () {
      expect(
        LocalBookWorkflowPolicy.readerLoadError('本地章节正文缺失，请重建目录或重新导入后重试。'),
        contains('重建目录'),
      );
    });

    test('uses unified non-ready open message for failed books', () {
      final book = LocalBook(
        id: 'local_2',
        title: '失败测试',
        format: LocalBookFormat.txt,
        storagePath: '/tmp/test.txt',
        fileSize: 1,
        createdAt: now,
        updatedAt: now,
        indexStatus: LocalBookIndexStatus.failed,
      );

      expect(
        LocalBookWorkflowPolicy.nonReadyOpenMessage(book),
        contains('重新导入'),
      );
      expect(LocalBookWorkflowPolicy.statusActionText(book), contains('重新导入'));
    });

    test('normalizes toc warning and detail error copy', () {
      expect(
        LocalBookWorkflowPolicy.tocWarningText('本地章节正文缺失，请重建目录或重新导入后重试。'),
        contains('重建目录'),
      );
      expect(
        LocalBookWorkflowPolicy.userReadableLoadError('本地文件不存在：/tmp/foo.txt'),
        contains('重新导入'),
      );
    });
  });
}
