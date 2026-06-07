import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_bootstrap_controller.dart';

void main() {
  group('ReaderPageBootstrapController', () {
    const controller = ReaderPageBootstrapController();

    test('trims route seed and only drops blank bookmark id', () {
      final seed = controller.resolveSeed(
        bookId: ' book-a ',
        chapterId: ' chapter-1 ',
        chapterUrl: ' ',
        chapterTitle: ' 第一章 ',
        sourceId: ' source-a ',
        detailUrl: ' detail-a ',
        chapterIndex: 3,
        bookmarkId: ' ',
      );

      expect(seed.bookId, 'book-a');
      expect(seed.chapterId, 'chapter-1');
      expect(seed.chapterUrl, '');
      expect(seed.chapterTitle, '第一章');
      expect(seed.sourceId, 'source-a');
      expect(seed.detailUrl, 'detail-a');
      expect(seed.chapterIndex, 3);
      expect(seed.pendingBookmarkId, isNull);
    });

    test('keeps non-blank bookmark id', () {
      final seed = controller.resolveSeed(
        bookId: 'book-a',
        chapterId: 'chapter-1',
        bookmarkId: ' bookmark-a ',
      );

      expect(seed.pendingBookmarkId, 'bookmark-a');
    });
  });
}
