import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/reader/application/reader_jump_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderJumpPlanner', () {
    const planner = ReaderJumpPlanner();
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

    test('resolves nearest readable chapter for initial jump', () {
      final decision = planner.resolve(
        chapters: chapters,
        requestedChapterIndex: 0,
        currentChapterIndex: null,
      );

      expect(decision.type, ReaderJumpDecisionType.jump);
      expect(decision.targetChapterIndex, 1);
    });

    test('uses forward-only search when jumping ahead', () {
      final decision = planner.resolve(
        chapters: chapters,
        requestedChapterIndex: 2,
        currentChapterIndex: 1,
      );

      expect(decision.type, ReaderJumpDecisionType.jump);
      expect(decision.targetChapterIndex, 3);
    });

    test('uses backward-only search when jumping backward', () {
      final decision = planner.resolve(
        chapters: chapters,
        requestedChapterIndex: 2,
        currentChapterIndex: 3,
      );

      expect(decision.type, ReaderJumpDecisionType.jump);
      expect(decision.targetChapterIndex, 1);
    });

    test('returns boundary decision when no readable chapter found', () {
      const chaptersWithoutTail = <Chapter>[
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
      ];
      final backwardBoundary = planner.resolve(
        chapters: chapters,
        requestedChapterIndex: 0,
        currentChapterIndex: 1,
      );
      final forwardBoundary = planner.resolve(
        chapters: chaptersWithoutTail,
        requestedChapterIndex: 2,
        currentChapterIndex: 1,
      );

      expect(backwardBoundary.type, ReaderJumpDecisionType.boundary);
      expect(backwardBoundary.isFirstBoundary, isTrue);
      expect(forwardBoundary.type, ReaderJumpDecisionType.boundary);
      expect(forwardBoundary.isFirstBoundary, isFalse);
    });
  });
}
