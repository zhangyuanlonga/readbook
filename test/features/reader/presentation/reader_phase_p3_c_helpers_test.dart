import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_metrics.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_page_support_models.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_overlay_z_order.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/background/reader_background_layer.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/overlay/reader_overlay_layer_model.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/root/reader_root_scaffold.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/widgets/stack/reader_visual_stack.dart';
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

      expect(find.byType(ReaderRootScaffold), findsOneWidget);
      expect(find.byType(ReaderShell), findsOneWidget);
      expect(find.byType(ReaderVisualStack), findsOneWidget);
      expect(find.text('reader-content'), findsOneWidget);
    },
  );

  testWidgets('reader visual stack renders ordered visual slots', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderVisualStack(
          model: ReaderVisualStackModel(
            backgroundColor: Colors.white,
            contentSurfaceColor: Colors.transparent,
            background: Text('background'),
            backgroundOverlay: Text('background-overlay'),
            content: Text('content'),
            center: Text('center'),
            top: Text('top'),
            bottom: Text('bottom'),
            foregroundOverlay: Text('foreground'),
          ),
        ),
      ),
    );

    expect(find.text('background'), findsOneWidget);
    expect(find.text('background-overlay'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
    expect(find.text('center'), findsOneWidget);
    expect(find.text('top'), findsOneWidget);
    expect(find.text('bottom'), findsOneWidget);
    expect(find.text('foreground'), findsOneWidget);
  });

  testWidgets('reader background layer isolates repaint work', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderBackgroundLayer(
          model: ReaderBackgroundVisualModel(
            decoration: BoxDecoration(color: Colors.white),
          ),
        ),
      ),
    );

    expect(find.byType(ReaderBackgroundLayer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ReaderBackgroundLayer),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ReaderBackgroundLayer),
        matching: find.byType(DecoratedBox),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reader overlay layer renderer sorts visible layers by z-order', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReaderOverlayLayerRenderer(
          model: ReaderOverlayLayerModel(
            layers: [
              ReaderOverlayLayer(
                slot: ReaderForegroundOverlaySlot.bottomChrome,
                zOrder: 20,
                child: Text('bottom'),
                semanticRole: ReaderOverlaySemanticRole.chrome,
              ),
              ReaderOverlayLayer(
                slot: ReaderForegroundOverlaySlot.chapterLoading,
                zOrder: 0,
                child: Text('loading'),
                hitTestPolicy: ReaderOverlayHitTestPolicy.passThrough,
                semanticRole: ReaderOverlaySemanticRole.loading,
              ),
              ReaderOverlayLayer(
                slot: ReaderForegroundOverlaySlot.topChrome,
                zOrder: 10,
                visible: false,
                child: Text('hidden-top'),
                semanticRole: ReaderOverlaySemanticRole.chrome,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('loading'), findsOneWidget);
    expect(find.text('bottom'), findsOneWidget);
    expect(find.text('hidden-top'), findsNothing);
    expect(
      tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((widget) => widget.ignoring),
      isTrue,
    );
  });

  testWidgets('full-screen hit-test layer passes through when declared', (
    tester,
  ) async {
    var backgroundTapped = false;
    var overlayTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => backgroundTapped = true,
                child: const SizedBox.expand(),
              ),
            ),
            ReaderFullScreenHitTestLayer(
              strategy: ReaderFullScreenHitTestStrategy.passThrough,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => overlayTapped = true,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );

    await tester.tapAt(const Offset(100, 100));

    expect(backgroundTapped, isTrue);
    expect(overlayTapped, isFalse);
  });

  testWidgets('full-screen hit-test layer intercepts only while visible', (
    tester,
  ) async {
    var backgroundTapCount = 0;
    var overlayTapCount = 0;

    Future<void> pumpLayer({required bool visible}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => backgroundTapCount += 1,
                  child: const SizedBox.expand(),
                ),
              ),
              ReaderFullScreenHitTestLayer(
                strategy: ReaderFullScreenHitTestStrategy.interceptWhenVisible,
                visible: visible,
                onTap: () => overlayTapCount += 1,
                child: const SizedBox.expand(),
              ),
            ],
          ),
        ),
      );
    }

    await pumpLayer(visible: false);
    await tester.tapAt(const Offset(100, 100));

    await pumpLayer(visible: true);
    await tester.tapAt(const Offset(100, 100));

    expect(backgroundTapCount, 1);
    expect(overlayTapCount, 1);
  });
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
