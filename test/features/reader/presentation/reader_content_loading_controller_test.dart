import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_logical_position.dart';
import 'package:shuxiang_reading_next/domain/entities/reading_progress.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_content_loading_controller.dart';

void main() {
  group('ReaderContentLoadingController', () {
    const controller = ReaderContentLoadingController();
    const chapters = <Chapter>[
      Chapter(
        id: 'chapter-1',
        bookId: 'book-1',
        title: '第一章',
        chapterUrl: 'chapter://1',
        index: 0,
      ),
      Chapter(
        id: 'volume-1',
        bookId: 'book-1',
        title: '卷一',
        chapterUrl: '',
        index: 1,
        isVolume: true,
      ),
      Chapter(
        id: 'chapter-2',
        bookId: 'book-1',
        title: '第二章',
        chapterUrl: 'chapter://2',
        index: 2,
      ),
      Chapter(
        id: 'chapter-3',
        bookId: 'book-1',
        title: '第三章',
        chapterUrl: 'chapter://3',
        index: 3,
      ),
    ];

    test(
      'matches bootstrap progress by chapter and consumes when requested',
      () {
        final progress = ReadingProgress(
          bookId: 'book-1',
          sourceId: 'source-1',
          detailUrl: 'detail://1',
          chapterId: 'chapter-2',
          chapterUrl: 'chapter://2',
          chapterTitle: '第二章',
          chapterIndex: 2,
          updatedAt: DateTime(2026, 4, 26, 12),
          chapterPositionRatio: 0.4,
        );

        final resolution = controller.resolveBootstrapProgressForCurrentChapter(
          bootstrapProgress: progress,
          currentChapterId: 'chapter-2',
          currentChapterUrl: 'chapter://2',
          consume: true,
        );

        expect(resolution.matchedProgress, same(progress));
        expect(resolution.remainingProgress, isNull);
      },
    );

    test('keeps mismatched bootstrap progress for later chapter restore', () {
      final progress = ReadingProgress(
        bookId: 'book-1',
        sourceId: 'source-1',
        detailUrl: 'detail://1',
        chapterId: 'chapter-2',
        chapterUrl: 'chapter://2',
        chapterTitle: '第二章',
        chapterIndex: 2,
        updatedAt: DateTime(2026, 4, 26, 12),
        chapterPositionRatio: 0.4,
      );

      final resolution = controller.resolveBootstrapProgressForCurrentChapter(
        bootstrapProgress: progress,
        currentChapterId: 'chapter-1',
        currentChapterUrl: 'chapter://1',
        consume: true,
      );

      expect(resolution.matchedProgress, isNull);
      expect(resolution.remainingProgress, same(progress));
    });

    test('matches bootstrap progress by chapter url when route id changed', () {
      final progress = ReadingProgress(
        bookId: 'book-1',
        sourceId: 'source-1',
        detailUrl: 'detail://1',
        chapterId: 'old-chapter-id',
        chapterUrl: 'chapter://2',
        chapterTitle: '第二章',
        chapterIndex: 2,
        updatedAt: DateTime(2026, 4, 26, 12),
        chapterPositionRatio: 0.4,
      );

      final resolution = controller.resolveBootstrapProgressForCurrentChapter(
        bootstrapProgress: progress,
        currentChapterId: 'new-chapter-id',
        currentChapterUrl: 'chapter://2',
        consume: false,
      );

      expect(resolution.matchedProgress, same(progress));
      expect(resolution.remainingProgress, same(progress));
    });

    test('restores ratio from logical position before fallback ratio', () {
      final document = ReaderDocument.fromContent(content: '第一段\n\n第二段\n\n第三段');
      final logicalPosition = ReaderLogicalPosition.fromDocument(
        document: document,
        chapterIndex: 0,
        chapterPositionRatio: 0.75,
      );

      final ratio = controller.resolveDocumentRestoreRatio(
        fallbackDocument: document,
        logicalPosition: logicalPosition,
        fallback: 0.2,
      );

      expect(ratio, closeTo(0.75, 0.05));
    });

    test('builds resolved content for pure image chapter', () {
      final contentState = controller.buildResolvedContent(
        content: '',
        imageUrls: const <String>['https://img/1.jpg', 'https://img/2.jpg'],
      );

      expect(contentState.content, isEmpty);
      expect(contentState.chapterImageUrls, hasLength(2));
      expect(contentState.paragraphs, hasLength(2));
      expect(contentState.renderTextItemsByParagraph, isEmpty);
    });

    test('reuses resolved content cache for identical text payload', () {
      final first = controller.buildResolvedContent(content: '第一段\n\n第二段');
      final second = controller.buildResolvedContent(content: '第一段\n\n第二段');

      expect(identical(first, second), isTrue);
    });

    test('keeps precomputed pagination session when provided', () {
      const page = ReaderPagedSlice(
        paragraphIndex: 0,
        start: 0,
        end: 3,
        height: 24,
      );
      final contentState = controller.buildResolvedContent(
        content: '第一页',
        precomputedPagedPages: <List<ReaderPagedSlice>>[
          <ReaderPagedSlice>[page],
        ],
        precomputedCurrentPageIndex: 0,
        precomputedPaginationSignature: 'sig-1',
      );

      expect(contentState.pagedPages, hasLength(1));
      expect(contentState.paginationState.signature, 'sig-1');
      expect(contentState.currentPageIndex, 0);
    });

    test('seeds continuous text flow from current chapter content', () {
      final contentState = controller.buildResolvedContent(
        content: '第一段\n\n第二段',
      );

      final seeded = controller.seedContinuousTextFlow(
        shouldUseContinuousTextFlow: true,
        isMangaChapter: false,
        currentContent: contentState.content,
        currentChapterIndex: 0,
        chapters: chapters,
        currentChapterId: 'chapter-1',
        currentChapterUrl: 'chapter://1',
        currentChapterTitle: '第一章',
        contentState: contentState,
        isCurrentChapterCached: true,
      );

      expect(seeded, hasLength(1));
      expect(seeded.single.chapterId, 'chapter-1');
      expect(seeded.single.paragraphs, hasLength(2));
      expect(seeded.single.isCached, isTrue);
    });

    test('seeds continuous text flow for EPUB text with inline image', () {
      final document = ReaderDocument.fromContent(
        content:
            '第一段\n\n${ReaderDocument.inlineImageParagraph('file:///cover.jpg')}\n\n第二段',
      );
      final contentState = controller.buildResolvedContent(
        content: document.compatibilityContent,
        document: document,
      );

      final seeded = controller.seedContinuousTextFlow(
        shouldUseContinuousTextFlow: true,
        isMangaChapter: false,
        currentContent: contentState.content,
        currentChapterIndex: 0,
        chapters: chapters,
        currentChapterId: 'chapter-1',
        currentChapterUrl: 'chapter://1',
        currentChapterTitle: '第一章',
        contentState: contentState,
        isCurrentChapterCached: true,
      );

      expect(seeded, hasLength(1));
      expect(seeded.single.document.hasImageBlocks, isTrue);
      expect(seeded.single.paragraphs, hasLength(3));
    });

    test(
      'skips unreadable chapters when resolving adjacent continuous chapter',
      () {
        final loaded = <ReaderContinuousTextChapter>[
          ReaderContinuousTextChapter(
            chapterId: 'chapter-1',
            chapterUrl: 'chapter://1',
            chapterTitle: '第一章',
            displayTitle: '第一章',
            chapterIndex: 0,
            content: '第一章内容',
            document: ReaderDocument.fromContent(content: '第一章内容'),
            paragraphs: <String>['第一章内容'],
            isCached: false,
          ),
        ];

        final forward = controller.resolveAdjacentContinuousTextChapterIndex(
          chapters: chapters,
          loadedChapters: loaded,
          forward: true,
        );

        expect(forward, 2);
      },
    );

    test('builds neighbor prefetch plan near both scroll edges', () {
      final loaded = <ReaderContinuousTextChapter>[
        ReaderContinuousTextChapter(
          chapterId: 'chapter-2',
          chapterUrl: 'chapter://2',
          chapterTitle: '第二章',
          displayTitle: '第二章',
          chapterIndex: 2,
          content: '第二章内容',
          document: ReaderDocument.fromContent(content: '第二章内容'),
          paragraphs: <String>['第二章内容'],
          isCached: false,
        ),
      ];

      final nearTop = controller.resolveNeighborPrefetchPlan(
        shouldUseContinuousTextFlow: true,
        hasScrollClients: true,
        loadedChapters: loaded,
        isScrollEdgeAdvancingChapter: false,
        isAutoReadAdvancingChapter: false,
        viewport: const ReaderContinuousTextViewportMetrics(
          pixels: 40,
          viewportDimension: 500,
          maxScrollExtent: 2000,
        ),
        chapters: chapters,
      );
      final nearBottom = controller.resolveNeighborPrefetchPlan(
        shouldUseContinuousTextFlow: true,
        hasScrollClients: true,
        loadedChapters: loaded,
        isScrollEdgeAdvancingChapter: false,
        isAutoReadAdvancingChapter: false,
        viewport: const ReaderContinuousTextViewportMetrics(
          pixels: 1680,
          viewportDimension: 500,
          maxScrollExtent: 2000,
        ),
        chapters: chapters,
      );

      expect(nearTop.backwardChapterIndex, 0);
      expect(nearBottom.forwardChapterIndex, 3);
    });

    test('resolves active continuous chapter from measured layouts', () {
      final loaded = <ReaderContinuousTextChapter>[
        ReaderContinuousTextChapter(
          chapterId: 'chapter-1',
          chapterUrl: 'chapter://1',
          chapterTitle: '第一章',
          displayTitle: '第一章',
          chapterIndex: 0,
          content: '第一章内容',
          document: ReaderDocument.fromContent(content: '第一章内容'),
          paragraphs: <String>['第一章内容'],
          isCached: false,
        ),
        ReaderContinuousTextChapter(
          chapterId: 'chapter-2',
          chapterUrl: 'chapter://2',
          chapterTitle: '第二章',
          displayTitle: '第二章',
          chapterIndex: 2,
          content: '第二章内容',
          document: ReaderDocument.fromContent(content: '第二章内容'),
          paragraphs: <String>['第二章内容'],
          isCached: true,
        ),
      ];

      final active = controller.resolveActiveContinuousTextChapter(
        chapters: loaded,
        layoutsByChapterIndex: const <int, ReaderContinuousTextChapterLayout>{
          0: ReaderContinuousTextChapterLayout(startOffset: 0, endOffset: 700),
          2: ReaderContinuousTextChapterLayout(
            startOffset: 700,
            endOffset: 1400,
          ),
        },
        viewport: const ReaderContinuousTextViewportMetrics(
          pixels: 760,
          viewportDimension: 400,
          maxScrollExtent: 1400,
        ),
      );

      expect(active?.chapterId, 'chapter-2');
    });

    test('builds activation with normalized content state and ratio', () {
      final chapter = ReaderContinuousTextChapter(
        chapterId: 'chapter-2',
        chapterUrl: 'chapter://2',
        chapterTitle: '第二章',
        displayTitle: '第二章',
        chapterIndex: 2,
        content: '第二章内容\n\n下一段',
        document: ReaderDocument.fromContent(content: '第二章内容\n\n下一段'),
        paragraphs: const <String>['第二章内容', '下一段'],
        isCached: true,
      );

      final activation = controller.buildContinuousTextActivationFromViewport(
        chapter: chapter,
        currentChapterIndex: 0,
        currentChapterId: 'chapter-1',
        currentChapterUrl: 'chapter://1',
        layout: const ReaderContinuousTextChapterLayout(
          startOffset: 600,
          endOffset: 1500,
        ),
        viewport: const ReaderContinuousTextViewportMetrics(
          pixels: 900,
          viewportDimension: 500,
          maxScrollExtent: 2000,
        ),
      );

      expect(activation, isNotNull);
      expect(activation!.chapterId, 'chapter-2');
      expect(activation.contentState.paragraphs, hasLength(2));
      expect(activation.initialRatio, closeTo(0.75, 0.001));
    });

    test('builds continuous text chapter from loaded result', () {
      final result = ChapterContentResult(
        content: '第一段\n\n第二段',
        fromCache: true,
        displayChapterTitle: '显示标题',
      );

      final chapter = controller.buildContinuousTextChapterFromResult(
        chapter: chapters[2],
        chapterIndex: 2,
        result: result,
        isCached: true,
      );

      expect(chapter.displayTitle, '显示标题');
      expect(chapter.paragraphs, hasLength(2));
      expect(chapter.isCached, isTrue);
    });
  });
}
