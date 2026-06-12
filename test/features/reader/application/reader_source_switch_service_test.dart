import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_source_switch_service.dart';

void main() {
  group('ReaderSourceSwitchService', () {
    const service = ReaderSourceSwitchService();

    Chapter chapter({
      required String bookId,
      required int index,
      required String title,
      bool isVolume = false,
    }) {
      return Chapter(
        id: '$bookId-$index',
        bookId: bookId,
        title: title,
        chapterUrl: isVolume ? '' : 'https://example.com/$bookId/$index',
        index: index,
        isVolume: isVolume,
      );
    }

    BookDetailLoadResult detailResult({
      required String bookId,
      required String sourceId,
      required List<Chapter> chapters,
    }) {
      return BookDetailLoadResult(
        detail: BookDetail(
          id: bookId,
          sourceId: sourceId,
          title: '目标书',
          detailUrl: 'https://example.com/detail/$bookId',
        ),
        chapters: chapters,
        sourceName: '目标源',
        tocFromCache: false,
      );
    }

    test('builds target chapter and progress migration plan', () {
      final plan = service.buildPlan(
        current: ReaderSourceSwitchCurrentState(
          bookId: 'current-book',
          chapters: [
            chapter(bookId: 'current-book', index: 0, title: '第一章'),
            chapter(bookId: 'current-book', index: 1, title: '第二章'),
          ],
          chapterTitle: '第二章',
          chapterIndex: 1,
          logicalPosition: const ReaderLogicalPosition(
            chapterIndex: 1,
            blockIndex: 3,
            offsetInBlock: 24,
            chapterPositionRatio: 0.62,
            pageIndex: 4,
          ),
        ),
        destination: ReaderSourceSwitchDestination(
          book: const Book(
            id: 'target-book',
            sourceId: 'target-source',
            title: '目标书',
            detailUrl: 'https://example.com/detail/target-book',
          ),
          detailResult: detailResult(
            bookId: 'target-book',
            sourceId: 'target-source',
            chapters: [
              chapter(bookId: 'target-book', index: 0, title: '第一章'),
              chapter(bookId: 'target-book', index: 1, title: '第二章'),
            ],
          ),
        ),
        lagTolerance: 2,
      );

      expect(plan.target.targetChapterIndex, 1);
      expect(plan.targetChapter.title, '第二章');
      expect(plan.progressMigration.previousBookId, 'current-book');
      expect(plan.progressMigration.nextBookId, 'target-book');
      expect(plan.progressMigration.chapterPositionRatio, closeTo(0.62, 0.001));
      expect(plan.progressMigration.logicalPosition.chapterIndex, 1);
      expect(plan.progressMigration.logicalPosition.blockIndex, 3);
      expect(plan.progressMigration.logicalPosition.pageIndex, isNull);
    });

    test('skips volume target chapter in unified switch plan', () {
      final plan = service.buildPlan(
        current: ReaderSourceSwitchCurrentState(
          bookId: 'current-book',
          chapters: [chapter(bookId: 'current-book', index: 0, title: '第一章')],
          chapterTitle: null,
          chapterIndex: 0,
          logicalPosition: null,
        ),
        destination: ReaderSourceSwitchDestination(
          book: const Book(
            id: 'target-book',
            sourceId: 'target-source',
            title: '目标书',
            detailUrl: 'https://example.com/detail/target-book',
          ),
          detailResult: detailResult(
            bookId: 'target-book',
            sourceId: 'target-source',
            chapters: [
              chapter(
                bookId: 'target-book',
                index: 0,
                title: '第一卷',
                isVolume: true,
              ),
              chapter(bookId: 'target-book', index: 1, title: '第一章'),
            ],
          ),
        ),
        lagTolerance: 2,
      );

      expect(plan.target.positionDecision.targetIndex, 0);
      expect(plan.target.targetChapterIndex, 1);
      expect(plan.targetChapter.isVolume, isFalse);
      expect(plan.progressMigration.logicalPosition.chapterPositionRatio, 0);
    });
  });
}
