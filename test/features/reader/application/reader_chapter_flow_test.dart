import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/reader/application/reader_chapter_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderChapterFlow', () {
    const flow = ReaderChapterFlow();
    const chapters = <Chapter>[
      Chapter(
        id: 'volume_1',
        bookId: 'book_1',
        title: '第一卷',
        chapterUrl: '',
        index: 0,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 1,
      ),
      Chapter(
        id: 'volume_2',
        bookId: 'book_1',
        title: '第二卷',
        chapterUrl: '',
        index: 2,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/2',
        index: 3,
      ),
    ];

    test('returns jump decision and skips volume nodes', () {
      final decision = flow.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: 1,
        forward: true,
      );

      expect(decision.type, ReaderAdjacentChapterDecisionType.jump);
      expect(decision.targetChapterIndex, 3);
      expect(decision.initialScrollRatio, 0);
    });

    test('supports backward jump with chapter-end ratio', () {
      final decision = flow.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: 3,
        forward: false,
      );

      expect(decision.type, ReaderAdjacentChapterDecisionType.jump);
      expect(decision.targetChapterIndex, 1);
      expect(decision.initialScrollRatio, 1);
    });

    test('returns boundary decision at reading edge', () {
      final atStart = flow.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: 1,
        forward: false,
      );
      final atEnd = flow.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: 3,
        forward: true,
      );

      expect(atStart.type, ReaderAdjacentChapterDecisionType.boundary);
      expect(atStart.isFirstBoundary, isTrue);
      expect(atEnd.type, ReaderAdjacentChapterDecisionType.boundary);
      expect(atEnd.isFirstBoundary, isFalse);
    });

    test('returns noCurrent when chapter index is missing', () {
      final decision = flow.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: null,
        forward: true,
      );

      expect(decision.type, ReaderAdjacentChapterDecisionType.noCurrent);
      expect(decision.targetChapterIndex, isNull);
    });
  });
}
