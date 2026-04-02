import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/domain/entities/reader_logical_position.dart';
import 'package:flutter_appread/features/reader/application/reader_source_switch_target_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSourceSwitchTargetResolver', () {
    const resolver = ReaderSourceSwitchTargetResolver();

    const currentChapters = <Chapter>[
      Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://current/1',
        index: 0,
      ),
      Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://current/2',
        index: 1,
      ),
    ];

    test('skips volume nodes and clears paged restore index', () {
      final target = resolver.resolve(
        currentChapters: currentChapters,
        targetChapters: const [
          Chapter(
            id: 'volume_1',
            bookId: 'book_2',
            title: '第一卷',
            chapterUrl: '',
            index: 0,
            isVolume: true,
          ),
          Chapter(
            id: 'chapter_1',
            bookId: 'book_2',
            title: '第一章',
            chapterUrl: 'https://target/1',
            index: 1,
          ),
        ],
        previousChapterTitle: null,
        previousChapterIndex: 0,
        previousLogicalPosition: const ReaderLogicalPosition(
          chapterIndex: 0,
          blockIndex: 2,
          offsetInBlock: 18,
          chapterPositionRatio: 0.45,
          pageIndex: 3,
        ),
        lagTolerance: 2,
      );

      expect(target.positionDecision.targetIndex, 0);
      expect(target.targetChapterIndex, 1);
      expect(target.logicalPosition.chapterIndex, 1);
      expect(target.logicalPosition.blockIndex, 2);
      expect(target.logicalPosition.pageIndex, isNull);
    });

    test(
      'falls back to chapter start when no previous logical position exists',
      () {
        final target = resolver.resolve(
          currentChapters: currentChapters,
          targetChapters: const [
            Chapter(
              id: 'chapter_1',
              bookId: 'book_2',
              title: '第一章',
              chapterUrl: 'https://target/1',
              index: 0,
            ),
          ],
          previousChapterTitle: '第一章',
          previousChapterIndex: 0,
          previousLogicalPosition: null,
          lagTolerance: 2,
        );

        expect(target.targetChapterIndex, 0);
        expect(target.logicalPosition.blockIndex, 0);
        expect(target.logicalPosition.offsetInBlock, 0);
        expect(target.logicalPosition.chapterPositionRatio, 0);
      },
    );

    test('throws when target source has no readable chapters', () {
      expect(
        () => resolver.resolve(
          currentChapters: currentChapters,
          targetChapters: const [
            Chapter(
              id: 'volume_1',
              bookId: 'book_2',
              title: '第一卷',
              chapterUrl: '',
              index: 0,
              isVolume: true,
            ),
          ],
          previousChapterTitle: '第一章',
          previousChapterIndex: 0,
          previousLogicalPosition: null,
          lagTolerance: 2,
        ),
        throwsStateError,
      );
    });
  });
}
