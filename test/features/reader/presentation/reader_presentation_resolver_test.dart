import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_document_render_model.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_metrics.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_presentation_resolver.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';

void main() {
  group('ReaderPresentationResolver', () {
    const resolver = ReaderPresentationResolver();
    const palette = ReaderPresentationPalette(
      backgroundColor: Color(0xFFFFFFFF),
      surfaceColor: Color(0xFFFFFFFF),
      primaryTextColor: Color(0xFF111111),
      secondaryTextColor: Color(0xFF666666),
    );
    const settings = ReaderSettings();
    const surfaceMetrics = ReaderSurfaceMetrics(
      viewportSize: Size(390, 844),
      safeInsets: EdgeInsets.only(top: 12, bottom: 18),
      bodyPadding: EdgeInsets.fromLTRB(16, 18, 24, 20),
      headerPadding: EdgeInsets.fromLTRB(8, 4, 10, 6),
      footerPadding: EdgeInsets.fromLTRB(7, 3, 9, 5),
      scrollBodyPadding: EdgeInsets.fromLTRB(16, 18, 24, 52),
      pinnedHeaderHeight: 52,
      pagedHeaderReserve: 24,
      pagedFooterReserve: 114,
      bottomProgressReserve: 96,
      effectivePagePadding: EdgeInsets.fromLTRB(16, 18, 24, 20),
      contentRect: Rect.fromLTWH(16, 70, 350, 640),
      contentWidth: 350,
      contentHeight: 640,
    );

    const seed = ReaderSessionSeed(
      contentMode: ReaderContentMode.text,
      bookId: 'book-1',
      sourceId: 'source-a',
      detailUrl: 'detail://a',
      bookTitle: '示例书',
      bookAuthor: '作者',
      bookCoverUrl: 'cover://a',
      chapterId: 'chapter-1',
      chapterUrl: 'chapter://1',
      chapterTitle: '第一章',
      chapterIndex: 0,
      chapters: <Chapter>[
        Chapter(
          id: 'chapter-1',
          bookId: 'book-1',
          title: '第一章',
          chapterUrl: 'chapter://1',
          index: 0,
        ),
      ],
    );

    test('creates fallback content session from seed', () {
      final session = resolver.resolveContentSession(seed: seed);

      expect(session.bookId, 'book-1');
      expect(session.sourceId, 'source-a');
      expect(session.chapterTitle, '第一章');
      expect(session.chapters, hasLength(1));
    });

    test('reuses current content session when provided', () {
      const currentSession = ReaderContentSession(
        contentMode: ReaderContentMode.comic,
        bookId: 'existing-book',
        sourceId: 'existing-source',
        detailUrl: 'detail://existing',
        bookTitle: '旧会话',
        chapterId: 'existing-chapter',
      );

      final resolved = resolver.resolveContentSession(
        seed: seed,
        currentSession: currentSession,
      );

      expect(identical(resolved, currentSession), isTrue);
    });

    test('builds shell model from resolved parts', () {
      final session = resolver.resolveContentSession(seed: seed);
      final model = resolver.buildShellModel(
        contentSession: session,
        settings: settings,
        surfaceMetrics: surfaceMetrics,
        viewportKind: ReaderPresentationViewportKind.textPaged,
        palette: palette,
        parts: const ReaderShellParts(
          background: SizedBox.shrink(),
          chrome: ReaderShellChromeSlots(bottom: SizedBox.shrink()),
        ),
      );

      expect(model.contentSession, same(session));
      expect(model.viewportKind, ReaderPresentationViewportKind.textPaged);
      expect(model.surfaceMetrics, same(surfaceMetrics));
      expect(model.chrome.bottom, isNotNull);
    });

    test('builds text scroll, paged, and manga models from shared session', () {
      final session = resolver.resolveContentSession(seed: seed);
      final document = ReaderDocument.fromContent(content: '第一段\n\n第二段');
      const paginationSpec = ReaderPaginationSpec(
        contentWidth: 350,
        contentHeight: 640,
        contentRectLeft: 16,
        contentRectTop: 70,
        pagePaddingTop: 18,
        pagePaddingRight: 24,
        pagePaddingBottom: 20,
        pagePaddingLeft: 16,
        pinnedHeaderHeight: 52,
        fontSize: 18,
        lineHeight: 1.7,
        paragraphSpacing: 14,
        paragraphIndent: 0,
        letterSpacing: 0,
        textFullJustifyEnabled: false,
        bodyTextItalicEnabled: false,
        fontWeightLevel: ReaderFontWeightLevel.regular,
        fontWeightValue: null,
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
        fontFamilyKey: null,
      );
      const renderItems = <ReaderRenderBlockItem>[
        ReaderRenderTextItem(
          text: '第一段',
          kind: ReaderRenderTextKind.paragraph,
          paragraphIndex: 0,
        ),
      ];

      final scrollModel = resolver.buildTextScrollModel(
        contentSession: session,
        settings: settings,
        document: document,
        surfaceMetrics: surfaceMetrics,
        palette: palette,
        renderItems: renderItems,
        contentPadding: const EdgeInsets.all(20),
      );
      final pagedModel = resolver.buildTextPagedModel(
        contentSession: session,
        settings: settings,
        surfaceMetrics: surfaceMetrics,
        paginationSpec: paginationSpec,
        palette: palette,
        pageCount: 3,
        currentPageIndex: 1,
        document: document,
        paragraphs: const <String>['第一段', '第二段'],
        textItemsByParagraph: const <int, ReaderRenderTextItem>{
          0: ReaderRenderTextItem(
            text: '第一段',
            kind: ReaderRenderTextKind.paragraph,
            paragraphIndex: 0,
          ),
        },
      );
      final mangaModel = resolver.buildMangaModel(
        contentSession: session,
        settings: settings,
        surfaceMetrics: surfaceMetrics,
        palette: palette,
        imageUrls: const <String>['a.png', 'b.png'],
        currentIndex: 1,
        continuousPadding: const EdgeInsets.all(12),
        pagedPagePadding: const EdgeInsets.all(8),
        continuousCacheExtent: 1800,
      );

      expect(scrollModel.contentSession, same(session));
      expect(scrollModel.renderItems, renderItems);
      expect(scrollModel.contentPadding, const EdgeInsets.all(20));

      expect(pagedModel.contentSession, same(session));
      expect(pagedModel.pageCount, 3);
      expect(pagedModel.currentPageIndex, 1);
      expect(pagedModel.paragraphs, hasLength(2));

      expect(mangaModel.contentSession, same(session));
      expect(mangaModel.imageUrls, hasLength(2));
      expect(mangaModel.currentIndex, 1);
    });
  });
}
