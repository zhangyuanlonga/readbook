import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_controller.dart';

void main() {
  group('ReaderSessionController', () {
    test('invalidates previous chapter content tokens', () {
      final controller = ReaderSessionController();

      final first = controller.nextChapterContentToken();
      final second = controller.nextChapterContentToken();

      expect(controller.isActiveChapterContentToken(first), isFalse);
      expect(controller.isActiveChapterContentToken(second), isTrue);
    });

    test('cancels task generations independently', () {
      final controller = ReaderSessionController();
      final chapter = controller.nextChapterContentToken();
      final preload = controller.nextPreloadTaskToken();
      final pagination = controller.nextPaginationTaskToken();

      controller.cancelPreloadTasks();

      expect(controller.isActiveChapterContentToken(chapter), isTrue);
      expect(controller.isActivePreloadTaskToken(preload), isFalse);
      expect(controller.isActivePaginationTaskToken(pagination), isTrue);
    });

    test('cancels all active task generations', () {
      final controller = ReaderSessionController();
      final chapter = controller.nextToken(
        ReaderSessionTaskKind.chapterContent,
      );
      final preload = controller.nextToken(ReaderSessionTaskKind.preload);
      final pagination = controller.nextToken(ReaderSessionTaskKind.pagination);

      controller.cancelAll();

      expect(controller.isActive(chapter), isFalse);
      expect(controller.isActive(preload), isFalse);
      expect(controller.isActive(pagination), isFalse);
    });
  });
}
