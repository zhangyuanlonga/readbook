import 'package:flutter_appread/features/reader/application/reader_logical_position.dart';
import 'package:flutter_appread/features/reader/application/reader_session_state.dart';
import 'package:flutter_appread/features/reader/application/reader_session_state_resolver.dart';
import 'package:flutter_appread/features/reader/application/text_reader_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReaderSessionStateResolver', () {
    const resolver = ReaderSessionStateResolver();
    const logicalPosition = ReaderLogicalPosition(
      chapterIndex: 3,
      blockIndex: 2,
      offsetInBlock: 16,
      chapterPositionRatio: 0.48,
    );

    test('returns null when required chapter context is missing', () {
      final missingIndex = resolver.resolve(
        chapterIndex: null,
        chapterId: 'chapter_3',
        chapterUrl: 'https://example.com/3',
        chapterTitle: '第三章',
        logicalPosition: logicalPosition,
        rendererKind: TextReaderRendererKind.paged,
        metrics: const ReaderRenderMetrics(pageCount: 8, currentPageIndex: 2),
        isAutoReading: false,
        isChapterTransitioning: false,
      );
      final missingLogical = resolver.resolve(
        chapterIndex: 3,
        chapterId: 'chapter_3',
        chapterUrl: 'https://example.com/3',
        chapterTitle: '第三章',
        logicalPosition: null,
        rendererKind: TextReaderRendererKind.paged,
        metrics: const ReaderRenderMetrics(pageCount: 8, currentPageIndex: 2),
        isAutoReading: false,
        isChapterTransitioning: false,
      );

      expect(missingIndex, isNull);
      expect(missingLogical, isNull);
    });

    test('builds paged visible position and clamps page index', () {
      final state = resolver.resolve(
        chapterIndex: 3,
        chapterId: ' chapter_3 ',
        chapterUrl: ' https://example.com/3 ',
        chapterTitle: ' 第三章 ',
        logicalPosition: logicalPosition,
        rendererKind: TextReaderRendererKind.paged,
        metrics: const ReaderRenderMetrics(pageCount: 5, currentPageIndex: 9),
        isAutoReading: true,
        isChapterTransitioning: false,
      );

      expect(state, isNotNull);
      expect(state!.currentChapterId, 'chapter_3');
      expect(state.currentChapterUrl, 'https://example.com/3');
      expect(state.currentChapterTitle, '第三章');
      expect(state.visiblePosition.pageCount, 5);
      expect(state.visiblePosition.pageIndex, 4);
      expect(state.isAutoReading, isTrue);
      expect(state.rendererKind, TextReaderRendererKind.paged);
    });

    test('builds scroll visible position from metrics', () {
      final state = resolver.resolve(
        chapterIndex: 3,
        chapterId: 'chapter_3',
        chapterUrl: 'https://example.com/3',
        chapterTitle: '第三章',
        logicalPosition: logicalPosition,
        rendererKind: TextReaderRendererKind.scroll,
        metrics: const ReaderRenderMetrics(
          hasScrollClients: true,
          scrollOffset: 128,
          maxScrollExtent: 620,
        ),
        isAutoReading: false,
        isChapterTransitioning: true,
      );

      expect(state, isNotNull);
      expect(state!.visiblePosition.scrollOffset, 128);
      expect(state.visiblePosition.maxScrollExtent, 620);
      expect(state.isChapterTransitioning, isTrue);
      expect(state.rendererKind, TextReaderRendererKind.scroll);
    });
  });
}
