import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_document_render_model.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_image_decode_budget.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_models.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_metrics.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_manga_view.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_text_paged_view.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_text_scroll_view.dart';

const _imageUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

void main() {
  testWidgets('renders EPUB text scroll with inline image budget', (
    tester,
  ) async {
    final document = ReaderDocument(
      blocks: const <ReaderBlock>[
        ReaderTextBlock(text: '正文'),
        ReaderImageBlock(imageUrl: _imageUrl),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        ReaderTextScrollView(
          model: ReaderTextScrollViewModel(
            contentSession: _session(ReaderContentMode.text),
            settings: const ReaderSettings(),
            document: document,
            surfaceMetrics: _metrics,
            palette: _palette,
            renderItems: buildReaderRenderBlockItems(document),
            imageDecodeBudget: _decodeBudget,
          ),
        ),
      ),
    );

    expect(find.byType(ReaderTextScrollView), findsOneWidget);
    expect(find.text('正文'), findsOneWidget);
  });

  testWidgets('renders EPUB paged block text and image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderTextPagedView(
          model: ReaderTextPagedViewModel(
            contentSession: _session(ReaderContentMode.text),
            settings: const ReaderSettings(),
            surfaceMetrics: _metrics,
            paginationSpec: _paginationSpec,
            palette: _palette,
            pageCount: 1,
            currentPageIndex: 0,
            paragraphs: const <String>['图文正文'],
            pagedBlockPages: const <List<ReaderPagedBlock>>[
              <ReaderPagedBlock>[
                ReaderPagedBlock.text(
                  paragraphIndex: 0,
                  start: 0,
                  end: 4,
                  height: 32,
                ),
                ReaderPagedBlock.image(imageUrl: _imageUrl, height: 80),
              ],
            ],
            imageDecodeBudget: _decodeBudget,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ReaderTextPagedView), findsOneWidget);
    expect(find.byType(ReaderPagedPageContent), findsOneWidget);
  });

  testWidgets('renders pure manga paged mode', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ReaderMangaView(
          model: _mangaModel(
            const ReaderSettings(mangaReadMode: ReaderMangaReadMode.paged),
          ),
        ),
      ),
    );

    expect(find.byType(ReaderMangaView), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('renders pure manga continuous mode', (tester) async {
    await tester.pumpWidget(
      _wrap(ReaderMangaView(model: _mangaModel(const ReaderSettings()))),
    );

    expect(find.byType(ReaderMangaView), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SizedBox(width: 360, height: 640, child: child)),
  );
}

ReaderMangaViewModel _mangaModel(ReaderSettings settings) {
  return ReaderMangaViewModel(
    contentSession: _session(ReaderContentMode.comic),
    settings: settings,
    surfaceMetrics: _metrics,
    palette: _palette,
    imageUrls: const <String>[_imageUrl, _imageUrl],
    imageDecodeBudget: _decodeBudget,
  );
}

ReaderContentSession _session(ReaderContentMode mode) {
  return ReaderContentSession(
    contentMode: mode,
    bookId: 'book',
    sourceId: 'source',
    detailUrl: 'detail',
    bookTitle: 'book',
    chapterId: 'chapter',
  );
}

const _decodeBudget = ReaderImageDecodeBudget(
  cacheWidth: 320,
  cacheHeight: 480,
  maxDataUriBytes: 1024 * 1024,
  imageCacheMaximumSize: 80,
  imageCacheMaximumSizeBytes: 48 * 1024 * 1024,
);

const _palette = ReaderPresentationPalette(
  backgroundColor: Colors.white,
  surfaceColor: Colors.white,
  primaryTextColor: Colors.black,
  secondaryTextColor: Colors.black54,
);

const _metrics = ReaderSurfaceMetrics(
  viewportSize: Size(360, 640),
  safeInsets: EdgeInsets.zero,
  bodyPadding: EdgeInsets.zero,
  headerPadding: EdgeInsets.zero,
  footerPadding: EdgeInsets.zero,
  scrollBodyPadding: EdgeInsets.all(12),
  pinnedHeaderHeight: 0,
  pagedHeaderReserve: 0,
  pagedFooterReserve: 0,
  bottomProgressReserve: 0,
  effectivePagePadding: EdgeInsets.all(12),
  contentRect: Rect.fromLTWH(0, 0, 336, 616),
  contentWidth: 336,
  contentHeight: 616,
);

const _paginationSpec = ReaderPaginationSpec(
  contentWidth: 336,
  contentHeight: 616,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 12,
  pagePaddingRight: 12,
  pagePaddingBottom: 12,
  pagePaddingLeft: 12,
  pinnedHeaderHeight: 0,
  fontSize: 18,
  lineHeight: 1.67,
  paragraphSpacing: 2,
  paragraphIndent: 2,
  letterSpacing: ReaderSettings.defaultLetterSpacing,
  textFullJustifyEnabled: true,
  bodyTextItalicEnabled: false,
  fontWeightLevel: ReaderFontWeightLevel.regular,
  fontSource: ReaderFontSource.system,
  systemFontPreset: ReaderSystemFontPreset.defaultSans,
  fontWeightValue: null,
  fontFamilyKey: null,
);
