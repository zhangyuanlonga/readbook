import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/reader/application/content_provider.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_mode_model.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_presentation_facade.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';

void main() {
  group('ReaderSessionPresentationFacade', () {
    const facade = ReaderSessionPresentationFacade();

    test('delegates mode capability resolution', () {
      final capabilities = facade.resolveModeCapabilities(
        contentMode: ReaderContentMode.text,
        contentCapabilities: const ContentCapabilities(canCacheChapter: true),
        hasInlineImageParagraphs: false,
      );

      expect(capabilities.canAutoRead, isTrue);
      expect(capabilities.canCacheChapter, isTrue);
      expect(capabilities.supportsCatalogContentSearch, isTrue);
    });

    test('resolves scroll viewport state with clamped ratio', () {
      final state = facade.resolveViewportState(
        contentMode: ReaderContentMode.text,
        mode: const ReaderModeModel(
          contentKind: ReaderContentKind.text,
          layoutMode: ReaderLayoutMode.scroll,
          viewportKind: ReaderModeViewportKind.textScroll,
          supportsTextSelection: true,
          supportsZoomGesture: false,
          supportsAutoRead: true,
          sourcePageTurnMode: ReaderPageTurnMode.scroll,
          tapTurnEnabled: true,
          swipeTurnEnabled: false,
          pageAnimationStyle: null,
        ),
        chapterPositionRatio: 1.6,
        scrollOffset: 120,
        maxScrollExtent: 900,
      );

      expect(state.isScroll, isTrue);
      expect(state.chapterPositionRatio, 1.0);
      expect(state.scrollOffset, 120);
    });

    test('returns null content session when identity is incomplete', () {
      final session = facade.resolveContentSession(
        contentMode: ReaderContentMode.text,
        bookId: 'book_1',
        sourceId: null,
        detailUrl: 'detail://1',
        bookTitle: '测试书',
        bookAuthor: null,
        bookCoverUrl: null,
        chapterId: 'chapter_1',
        chapterUrl: null,
        chapterTitle: null,
        chapterIndex: 0,
        resolvedContentType: null,
        hybridSubMode: null,
        sourceFilePath: null,
        totalPageCount: null,
        audioUrl: null,
        audioManifestUrl: null,
        audioHeaders: const <String, String>{},
        executionContext: null,
        chapters: const [],
        sessionState: null,
        bootstrapProgress: null,
        readingRecordSession: null,
      );

      expect(session, isNull);
    });
  });
}
