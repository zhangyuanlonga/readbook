import 'package:flutter_appread/domain/entities/bookmark.dart';
import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/domain/entities/reader_document.dart';
import 'package:flutter_appread/features/reader/application/reader_jump_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderJumpFacade', () {
    const facade = ReaderJumpFacade();
    final now = DateTime(2026, 4, 2);
    final chapters = <Chapter>[
      const Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 0,
      ),
      const Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/2',
        index: 1,
      ),
    ];
    final chaptersWithVolume = <Chapter>[
      const Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/1',
        index: 0,
      ),
      const Chapter(
        id: 'volume_1',
        bookId: 'book_1',
        title: '第一卷',
        chapterUrl: '',
        index: 1,
        isVolume: true,
      ),
      const Chapter(
        id: 'chapter_2',
        bookId: 'book_1',
        title: '第二章',
        chapterUrl: 'https://example.com/2',
        index: 2,
      ),
    ];

    Bookmark buildBookmark({
      String chapterId = 'chapter_2',
      int chapterIndex = 1,
      int startOffset = 4,
      String snippet = '内容',
    }) {
      return Bookmark(
        id: 'bookmark_1',
        bookId: 'book_1',
        chapterId: chapterId,
        chapterIndex: chapterIndex,
        startOffset: startOffset,
        endOffset: startOffset + 2,
        snippet: snippet,
        createdAt: now,
        updatedAt: now,
      );
    }

    test(
      'resolves bookmark chapter index by chapter id and fallback index',
      () {
        final byId = facade.resolveBookmarkChapterIndex(
          bookmark: buildBookmark(chapterId: 'chapter_2', chapterIndex: 0),
          chapters: chapters,
        );
        final byIndex = facade.resolveBookmarkChapterIndex(
          bookmark: buildBookmark(chapterId: 'missing', chapterIndex: 0),
          chapters: chapters,
        );
        final invalid = facade.resolveBookmarkChapterIndex(
          bookmark: buildBookmark(chapterId: 'missing', chapterIndex: 8),
          chapters: chapters,
        );

        expect(byId, 1);
        expect(byIndex, 0);
        expect(invalid, isNull);
      },
    );

    test('redirects bookmark chapter index to nearest readable chapter', () {
      final byVolumeId = facade.resolveBookmarkChapterIndex(
        bookmark: buildBookmark(chapterId: 'volume_1', chapterIndex: 0),
        chapters: chaptersWithVolume,
      );
      final byVolumeIndex = facade.resolveBookmarkChapterIndex(
        bookmark: buildBookmark(chapterId: 'missing', chapterIndex: 1),
        chapters: chaptersWithVolume,
      );

      expect(byVolumeId, 2);
      expect(byVolumeIndex, 2);
    });

    test('resolves readable chapter target index with forward preference', () {
      final forward = facade.resolveReadableChapterTargetIndex(
        chapters: chaptersWithVolume,
        chapterIndex: 1,
      );
      final backward = facade.resolveReadableChapterTargetIndex(
        chapters: chaptersWithVolume,
        chapterIndex: 1,
        preferForward: false,
      );

      expect(forward, 2);
      expect(backward, 0);
    });

    test('resolves bookmark restore ratio by offset then snippet fallback', () {
      final byOffset = facade.resolveBookmarkRestoreRatio(
        bookmark: buildBookmark(startOffset: 5, snippet: 'x'),
        chapterContent: '0123456789',
      );
      final bySnippet = facade.resolveBookmarkRestoreRatio(
        bookmark: buildBookmark(startOffset: 99, snippet: '345'),
        chapterContent: '0123456789',
      );

      expect(byOffset, closeTo(0.5, 0.0001));
      expect(bySnippet, closeTo(0.3, 0.0001));
    });

    test('resolves bookmark logical position from document and ratio', () {
      final position = facade.resolveBookmarkLogicalPosition(
        bookmark: buildBookmark(startOffset: 5),
        document: ReaderDocument(
          blocks: const [
            ReaderTextBlock(text: '第一段'),
            ReaderTextBlock(text: '第二段内容'),
          ],
        ),
        currentChapterIndex: 1,
        isPagedTextReaderEnabled: true,
        currentPageIndex: 3,
        chapterContent: '0123456789',
      );

      expect(position, isNotNull);
      expect(position!.chapterIndex, 1);
      expect(position.pageIndex, 3);
      expect(position.chapterPositionRatio, closeTo(0.5, 0.0001));
    });

    test('resolves bookmark restore plan with logical position first', () {
      final plan = facade.resolveBookmarkRestorePlan(
        bookmark: buildBookmark(startOffset: 5),
        document: ReaderDocument(
          blocks: const [
            ReaderTextBlock(text: '第一段'),
            ReaderTextBlock(text: '第二段内容'),
          ],
        ),
        currentChapterIndex: 1,
        isPagedTextReaderEnabled: true,
        currentPageIndex: 3,
        chapterContent: '0123456789',
      );

      expect(plan.logicalPosition, isNotNull);
      expect(plan.fallbackRatio, isNull);
      expect(plan.logicalPosition!.pageIndex, 3);
    });

    test(
      'resolves bookmark restore plan fallback ratio when document is empty',
      () {
        final plan = facade.resolveBookmarkRestorePlan(
          bookmark: buildBookmark(startOffset: 5, snippet: 'x'),
          document: ReaderDocument(blocks: const []),
          currentChapterIndex: 1,
          isPagedTextReaderEnabled: false,
          currentPageIndex: 0,
          chapterContent: '0123456789',
        );

        expect(plan.logicalPosition, isNull);
        expect(plan.fallbackRatio, closeTo(0.5, 0.0001));
      },
    );

    test('resolves catalog selection decisions', () {
      final resume = facade.resolveCatalogSelection(
        selectedIndex: null,
        chapters: chapters,
        currentChapterIndex: 2,
        selectedScrollRatio: null,
        selectedLogicalPosition: null,
      );
      final restoreCurrent = facade.resolveCatalogSelection(
        selectedIndex: 2,
        chapters: const <Chapter>[
          Chapter(
            id: 'chapter_0',
            bookId: 'book_1',
            title: '第零章',
            chapterUrl: 'https://example.com/0',
            index: 0,
          ),
          Chapter(
            id: 'chapter_1',
            bookId: 'book_1',
            title: '第一章',
            chapterUrl: 'https://example.com/1',
            index: 1,
          ),
          Chapter(
            id: 'chapter_2',
            bookId: 'book_1',
            title: '第二章',
            chapterUrl: 'https://example.com/2',
            index: 2,
          ),
          Chapter(
            id: 'chapter_3',
            bookId: 'book_1',
            title: '第三章',
            chapterUrl: 'https://example.com/3',
            index: 3,
          ),
        ],
        currentChapterIndex: 2,
        selectedScrollRatio: 0.4,
        selectedLogicalPosition: null,
      );
      final jump = facade.resolveCatalogSelection(
        selectedIndex: 5,
        chapters: List<Chapter>.generate(
          10,
          (index) => Chapter(
            id: 'chapter_$index',
            bookId: 'book_1',
            title: '第${index + 1}章',
            chapterUrl: 'https://example.com/$index',
            index: index,
          ),
        ),
        currentChapterIndex: 2,
        selectedScrollRatio: 0.1,
        selectedLogicalPosition: null,
      );
      final jumpFromVolume = facade.resolveCatalogSelection(
        selectedIndex: 1,
        chapters: chaptersWithVolume,
        currentChapterIndex: 0,
        selectedScrollRatio: 0.2,
        selectedLogicalPosition: null,
      );

      expect(resume.type, ReaderCatalogSelectionDecisionType.resumeAutoRead);
      expect(
        restoreCurrent.type,
        ReaderCatalogSelectionDecisionType.restoreCurrent,
      );
      expect(jump.type, ReaderCatalogSelectionDecisionType.jumpChapter);
      expect(jump.targetChapterIndex, 5);
      expect(jump.initialScrollRatio, 0.1);
      expect(
        jumpFromVolume.type,
        ReaderCatalogSelectionDecisionType.jumpChapter,
      );
      expect(jumpFromVolume.targetChapterIndex, 2);
    });
  });
}
