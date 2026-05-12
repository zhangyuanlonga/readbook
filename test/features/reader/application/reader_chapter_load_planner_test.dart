import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_chapter_load_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderChapterLoadPlanner', () {
    const planner = ReaderChapterLoadPlanner();
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

    test(
      'resolveLoadRequest returns null when source or chapter url missing',
      () {
        final invalid = planner.resolveLoadRequest(
          sourceIdOverride: 'source_a',
          chapterIdOverride: 'chapter_1',
          chapterUrlOverride: '',
          chapterTitleOverride: '第一章',
          currentSourceId: null,
          currentChapterId: 'chapter_1',
          currentChapterUrl: null,
          currentChapterTitle: null,
        );

        expect(invalid, isNull);
      },
    );

    test('resolveLoadRequest normalizes override and current fields', () {
      final request = planner.resolveLoadRequest(
        sourceIdOverride: ' source_a ',
        chapterIdOverride: null,
        chapterUrlOverride: null,
        chapterTitleOverride: null,
        currentSourceId: 'source_b',
        currentChapterId: ' chapter_1 ',
        currentChapterUrl: ' https://example.com/1 ',
        currentChapterTitle: '第一章',
      );

      expect(request, isNotNull);
      expect(request!.sourceId, 'source_a');
      expect(request.chapterId, 'chapter_1');
      expect(request.chapterUrl, 'https://example.com/1');
      expect(request.chapterTitle, '第一章');
    });

    test('resolveFetchChapterIndex prefers override then fallback lookup', () {
      final override = planner.resolveFetchChapterIndex(
        chapterIndexOverride: 1,
        currentChapterIndex: 0,
        chapters: chapters,
        chapterUrl: 'https://example.com/2',
      );
      final fallback = planner.resolveFetchChapterIndex(
        chapterIndexOverride: null,
        currentChapterIndex: null,
        chapters: chapters,
        chapterUrl: 'https://example.com/2',
      );

      expect(override, 1);
      expect(fallback, 1);
    });

    test('canPrepaginate and resolvePageIndexByRatio obey guards', () {
      final can = planner.canPrepaginate(
        isPagedTextReaderEnabled: true,
        hasImages: false,
        content: '正文',
        maxWidth: 120,
        maxHeight: 240,
      );
      final cannot = planner.canPrepaginate(
        isPagedTextReaderEnabled: true,
        hasImages: true,
        content: '正文',
        maxWidth: 120,
        maxHeight: 240,
      );
      final pageIndex = planner.resolvePageIndexByRatio(
        targetRatio: 0.5,
        pageCount: 5,
      );

      expect(can, isTrue);
      expect(cannot, isFalse);
      expect(pageIndex, 2);
    });

    test('resolvePageIndexByRatio restores conservatively', () {
      final pageIndex = planner.resolvePageIndexByRatio(
        targetRatio: 0.12,
        pageCount: 8,
      );

      expect(pageIndex, 0);
    });

    test('resolveChapterTitleAfterLoad applies display title precedence', () {
      final commitTitle = planner.resolveChapterTitleAfterLoad(
        commitChapterIdentity: true,
        loadedDisplayChapterTitle: ' 新标题 ',
        targetChapterTitle: '原标题',
        currentChapterTitle: '当前标题',
      );
      final keepCurrent = planner.resolveChapterTitleAfterLoad(
        commitChapterIdentity: false,
        loadedDisplayChapterTitle: null,
        targetChapterTitle: '原标题',
        currentChapterTitle: '当前标题',
      );

      expect(commitTitle, '新标题');
      expect(keepCurrent, '当前标题');
    });
  });
}
