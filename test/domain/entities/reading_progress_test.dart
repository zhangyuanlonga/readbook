import 'package:flutter_appread/domain/entities/reading_progress.dart';
import 'package:flutter_appread/domain/entities/reader_logical_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingProgress', () {
    test('supports toJson and fromJson with chapter position ratio', () {
      final progress = ReadingProgress(
        bookId: 'book_1',
        sourceId: 'src_1',
        detailUrl: 'https://example.com/book/1',
        chapterId: 'c_1',
        chapterUrl: 'https://example.com/book/1/c1',
        chapterTitle: '第一章',
        chapterIndex: 0,
        updatedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
        chapterPositionRatio: 0.42,
        logicalPosition: const ReaderLogicalPosition(
          chapterIndex: 0,
          blockIndex: 3,
          offsetInBlock: 10,
          chapterPositionRatio: 0.42,
          pageIndex: 2,
        ),
      );

      final json = progress.toJson();
      final restored = ReadingProgress.fromJson(json);

      expect(restored.bookId, progress.bookId);
      expect(restored.chapterTitle, progress.chapterTitle);
      expect(restored.chapterPositionRatio, 0.42);
      expect(restored.logicalPosition, isNotNull);
      expect(restored.logicalPosition!.blockIndex, 3);
      expect(restored.logicalPosition!.pageIndex, 2);
    });

    test('defaults ratio to zero when loading legacy payload', () {
      final restored = ReadingProgress.fromJson({
        'bookId': 'book_legacy',
        'sourceId': 'src_legacy',
        'detailUrl': 'https://example.com/book/legacy',
        'chapterId': 'c_1',
        'chapterUrl': 'https://example.com/book/legacy/c1',
        'chapterTitle': '第一章',
        'chapterIndex': 1,
        'updatedAt': '2026-02-12T12:00:00.000Z',
      });

      expect(restored.chapterPositionRatio, 0);
      expect(restored.logicalPosition, isNull);
    });

    test('clamps ratio into valid range', () {
      final restored = ReadingProgress.fromJson({
        'bookId': 'book_legacy',
        'sourceId': 'src_legacy',
        'detailUrl': 'https://example.com/book/legacy',
        'chapterId': 'c_1',
        'chapterUrl': 'https://example.com/book/legacy/c1',
        'chapterTitle': '第一章',
        'chapterIndex': 1,
        'updatedAt': '2026-02-12T12:00:00.000Z',
        'chapterPositionRatio': 1.9,
      });

      expect(restored.chapterPositionRatio, 1);
    });
  });
}
