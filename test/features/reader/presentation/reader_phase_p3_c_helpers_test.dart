import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_metrics.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_support_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_overlay_z_order.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/viewport/reader_page_scaffold_shell.dart';

void main() {
  test('reader shell and foreground overlay z-order are explicit', () {
    expect(readerShellLayerOrder, const <ReaderShellLayerSlot>[
      ReaderShellLayerSlot.background,
      ReaderShellLayerSlot.backgroundOverlay,
      ReaderShellLayerSlot.content,
      ReaderShellLayerSlot.center,
      ReaderShellLayerSlot.top,
      ReaderShellLayerSlot.bottom,
      ReaderShellLayerSlot.leading,
      ReaderShellLayerSlot.trailing,
      ReaderShellLayerSlot.foregroundOverlay,
    ]);
    expect(readerForegroundOverlayOrder, const <ReaderForegroundOverlaySlot>[
      ReaderForegroundOverlaySlot.chapterLoading,
      ReaderForegroundOverlaySlot.autoReadStatus,
      ReaderForegroundOverlaySlot.overlayScrim,
      ReaderForegroundOverlaySlot.topChrome,
      ReaderForegroundOverlaySlot.bottomChrome,
    ]);
  });

  testWidgets(
    'reader page scaffold shell renders focused reader shell content',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPageScaffoldShell(
            colors: _colors,
            canPopRoute: true,
            onFallbackPop: () {},
            focusNode: focusNode,
            onKeyEvent: (_, _) => KeyEventResult.ignored,
            shellModel: _shellModel,
            child: const Text('reader-content'),
          ),
        ),
      );

      expect(find.byType(ReaderShell), findsOneWidget);
      expect(find.text('reader-content'), findsOneWidget);
    },
  );
}

const _colors = ReaderThemeColors(
  background: Colors.white,
  text: Colors.black,
  meta: Colors.black54,
  divider: Colors.black26,
  overlay: Colors.white,
);

const _shellModel = ReaderShellModel(
  contentSession: ReaderContentSession(
    contentMode: ReaderContentMode.text,
    bookId: 'book-1',
    sourceId: 'source-1',
    detailUrl: 'detail://book',
    bookTitle: '测试书',
    chapterId: 'chapter-1',
  ),
  settings: ReaderSettings(),
  surfaceMetrics: ReaderSurfaceMetrics(
    viewportSize: Size(390, 844),
    safeInsets: EdgeInsets.zero,
    bodyPadding: EdgeInsets.zero,
    headerPadding: EdgeInsets.zero,
    footerPadding: EdgeInsets.zero,
    scrollBodyPadding: EdgeInsets.zero,
    pinnedHeaderHeight: 0,
    pagedHeaderReserve: 0,
    pagedFooterReserve: 0,
    bottomProgressReserve: 0,
    effectivePagePadding: EdgeInsets.zero,
    contentRect: Rect.fromLTWH(0, 0, 390, 844),
    contentWidth: 390,
    contentHeight: 844,
  ),
  viewportKind: ReaderPresentationViewportKind.textScroll,
  palette: ReaderPresentationPalette(
    backgroundColor: Colors.white,
    surfaceColor: Colors.white,
    primaryTextColor: Colors.black,
    secondaryTextColor: Colors.black54,
  ),
);
