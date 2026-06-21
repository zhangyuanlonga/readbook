import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/paged_transition_controller.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_content_session.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_pagination_spec.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_surface_metrics.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/paged_animation/reader_paged_animation_surface.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_paper_curl_paged_view.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_paged_viewport_support.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_shell.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_text_paged_view.dart';

void main() {
  group('ReaderPagedViewportInput', () {
    test('clamps page index and compares stable paging surface', () {
      const input = ReaderPagedViewportInput(
        chapterId: 'chapter-1',
        pageIndex: 99,
        pageCount: 8,
        pageSize: Size(320, 640),
        animationStyle: ReaderPageAnimationStyle.paperCurl,
        viewportMetricsHash: 1001,
      );

      const sameSurface = ReaderPagedViewportInput(
        chapterId: 'chapter-1',
        pageIndex: 2,
        pageCount: 8,
        pageSize: Size(320, 640),
        animationStyle: ReaderPageAnimationStyle.paperCurl,
        viewportMetricsHash: 1001,
      );

      const differentSurface = ReaderPagedViewportInput(
        chapterId: 'chapter-1',
        pageIndex: 2,
        pageCount: 8,
        pageSize: Size(360, 640),
        animationStyle: ReaderPageAnimationStyle.paperCurl,
        viewportMetricsHash: 1001,
      );

      expect(input.safePageIndex, 7);
      expect(input.hasPages, isTrue);
      expect(input.isSamePagingSurface(sameSurface), isTrue);
      expect(input, sameSurface);
      expect(input.hashCode, sameSurface.hashCode);
      expect(input.isSamePagingSurface(differentSurface), isFalse);
    });

    test('keeps empty viewport safe page at zero', () {
      const input = ReaderPagedViewportInput(
        chapterId: 'empty',
        pageIndex: 3,
        pageCount: 0,
        pageSize: Size(320, 640),
        animationStyle: ReaderPageAnimationStyle.none,
        viewportMetricsHash: 0,
      );

      expect(input.safePageIndex, 0);
      expect(input.hasPages, isFalse);
    });
  });

  group('ReaderPagedViewportTransitionResolver', () {
    const resolver = ReaderPagedViewportTransitionResolver();

    test('keeps none animation as static page without decoration', () {
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.none,
        pageCount: 8,
        currentPageIndex: 99,
        pagedTransition: const PagedTransitionState(),
      );

      expect(plan.renderMode, ReaderPagedViewportRenderMode.staticPage);
      expect(plan.safePageIndex, 7);
      expect(plan.includeBackgroundDecorationOnPrimaryPage, isFalse);
      expect(plan.selectionMode, ReaderPagedViewportSelectionMode.enabled);
    });

    test('builds animated transition plan for valid active transition', () {
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.fade,
        pageCount: 8,
        currentPageIndex: 2,
        pagedTransition: const PagedTransitionState(
          isAnimating: true,
          style: ReaderPageAnimationStyle.cover,
          direction: 1,
          fromIndex: 2,
          toIndex: 3,
        ),
      );

      expect(plan.renderMode, ReaderPagedViewportRenderMode.animatedTransition);
      expect(plan.renderedAnimationStyle, ReaderPageAnimationStyle.cover);
      expect(plan.fromPageIndex, 2);
      expect(plan.toPageIndex, 3);
      expect(plan.includeBackgroundDecorationOnPrimaryPage, isTrue);
    });

    test(
      'falls back to decorated static page when transition indices are invalid',
      () {
        final plan = resolver.resolve(
          requestedAnimationStyle: ReaderPageAnimationStyle.fade,
          pageCount: 8,
          currentPageIndex: 2,
          pagedTransition: const PagedTransitionState(
            isAnimating: true,
            style: ReaderPageAnimationStyle.fade,
            direction: 1,
            fromIndex: 2,
            toIndex: 8,
          ),
        );

        expect(plan.renderMode, ReaderPagedViewportRenderMode.staticPage);
        expect(plan.includeBackgroundDecorationOnPrimaryPage, isTrue);
        expect(plan.fromPageIndex, isNull);
        expect(plan.toPageIndex, isNull);
      },
    );

    test(
      'builds boundary transition plan for same-page cross chapter animation',
      () {
        final plan = resolver.resolve(
          requestedAnimationStyle: ReaderPageAnimationStyle.cover,
          pageCount: 8,
          currentPageIndex: 7,
          pagedTransition: const PagedTransitionState(
            isAnimating: true,
            style: ReaderPageAnimationStyle.cover,
            direction: 1,
            fromIndex: 7,
            toIndex: 7,
            isCrossChapter: true,
          ),
        );

        expect(
          plan.renderMode,
          ReaderPagedViewportRenderMode.animatedTransition,
        );
        expect(plan.fromPageIndex, 7);
        expect(plan.toPageIndex, 7);
        expect(plan.direction, 1);
      },
    );

    test('builds curl plan and disables selection while curl is active', () {
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.curl,
        pageCount: 8,
        currentPageIndex: 3,
        pagedTransition: const PagedTransitionState(),
        curlState: const ReaderPagedViewportCurlState(
          isPreview: true,
          direction: 1,
          fromIndex: 3,
          toIndex: 4,
          previewProgress: 0.45,
        ),
      );

      expect(plan.renderMode, ReaderPagedViewportRenderMode.curlTransition);
      expect(plan.selectionMode, ReaderPagedViewportSelectionMode.disabled);
      expect(plan.fromPageIndex, 3);
      expect(plan.toPageIndex, 4);
      expect(plan.direction, 1);
    });

    test('builds curl boundary plan for same-page cross chapter curl', () {
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.curl,
        pageCount: 8,
        currentPageIndex: 7,
        pagedTransition: const PagedTransitionState(),
        curlState: const ReaderPagedViewportCurlState(
          isAnimating: true,
          direction: 1,
          fromIndex: 7,
          toIndex: 7,
          isCrossChapter: true,
        ),
      );

      expect(plan.renderMode, ReaderPagedViewportRenderMode.curlTransition);
      expect(plan.selectionMode, ReaderPagedViewportSelectionMode.disabled);
      expect(plan.fromPageIndex, 7);
      expect(plan.toPageIndex, 7);
    });

    test('routes paper curl through dedicated paper surface mode', () {
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.paperCurl,
        pageCount: 8,
        currentPageIndex: 2,
        pagedTransition: const PagedTransitionState(),
      );

      expect(plan.renderMode, ReaderPagedViewportRenderMode.paperCurlSurface);
      expect(plan.selectionMode, ReaderPagedViewportSelectionMode.disabled);
      expect(plan.includeBackgroundDecorationOnPrimaryPage, isTrue);
    });
  });

  group('ReaderPagedPageFrame', () {
    test(
      'requires a background decoration when page background is enabled',
      () {
        expect(
          () => ReaderPagedPageFrame(
            pageSize: const Size(300, 400),
            includeBackgroundDecoration: true,
            body: const Text('body'),
          ),
          throwsAssertionError,
        );
      },
    );

    testWidgets('renders frame sections and optional decoration', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ReaderPagedPageFrame(
            pageSize: const Size(300, 400),
            includeBackgroundDecoration: true,
            backgroundDecoration: const BoxDecoration(color: Color(0xFFEFE7D3)),
            pinnedHeader: const Text('pinned'),
            header: const Text('header'),
            body: const Text('body'),
            footer: const Text('footer'),
          ),
        ),
      );

      expect(find.text('pinned'), findsOneWidget);
      expect(find.text('header'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      expect(find.text('footer'), findsOneWidget);
      expect(find.byType(DecoratedBox), findsOneWidget);
    });
  });

  group('ReaderPagedViewportTransitionStack', () {
    testWidgets('wraps static page with selection wrapper', (tester) async {
      const resolver = ReaderPagedViewportTransitionResolver();
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.none,
        pageCount: 5,
        currentPageIndex: 1,
        pagedTransition: const PagedTransitionState(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ReaderPagedViewportTransitionStack(
            plan: plan,
            pageBuilder:
                ({
                  required int pageIndex,
                  required bool includeBackgroundDecoration,
                }) => Text('page $pageIndex / $includeBackgroundDecoration'),
            pagedTransitionAnimation: const AlwaysStoppedAnimation<double>(0),
            curlAnimation: const AlwaysStoppedAnimation<double>(0),
            switchInCurve: Curves.linear,
            selectionWrapper:
                (child) =>
                    KeyedSubtree(key: const Key('selection'), child: child),
            disabledSelectionWrapper:
                (child) =>
                    KeyedSubtree(key: const Key('disabled'), child: child),
          ),
        ),
      );

      expect(find.byKey(const Key('selection')), findsOneWidget);
      expect(find.byKey(const Key('disabled')), findsNothing);
      expect(find.text('page 1 / false'), findsOneWidget);
    });

    testWidgets('wraps curl transition with disabled selection', (
      tester,
    ) async {
      const resolver = ReaderPagedViewportTransitionResolver();
      const curlState = ReaderPagedViewportCurlState(
        isPreview: true,
        direction: 1,
        fromIndex: 1,
        toIndex: 2,
        previewProgress: 0.4,
      );
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.curl,
        pageCount: 5,
        currentPageIndex: 1,
        pagedTransition: const PagedTransitionState(),
        curlState: curlState,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ReaderPagedViewportTransitionStack(
            plan: plan,
            pageBuilder:
                ({
                  required int pageIndex,
                  required bool includeBackgroundDecoration,
                }) => Text('page $pageIndex / $includeBackgroundDecoration'),
            pagedTransitionAnimation: const AlwaysStoppedAnimation<double>(0),
            curlAnimation: const AlwaysStoppedAnimation<double>(0),
            switchInCurve: Curves.linear,
            curlState: curlState,
            selectionWrapper:
                (child) =>
                    KeyedSubtree(key: const Key('selection'), child: child),
            disabledSelectionWrapper:
                (child) =>
                    KeyedSubtree(key: const Key('disabled'), child: child),
          ),
        ),
      );

      expect(find.byKey(const Key('selection')), findsNothing);
      expect(find.byKey(const Key('disabled')), findsWidgets);
      expect(find.text('page 1 / true'), findsWidgets);
      expect(find.text('page 2 / true'), findsOneWidget);
    });

    testWidgets('unified surface routes paper curl to snapshot component', (
      tester,
    ) async {
      const resolver = ReaderPagedViewportTransitionResolver();
      final plan = resolver.resolve(
        requestedAnimationStyle: ReaderPageAnimationStyle.paperCurl,
        pageCount: 3,
        currentPageIndex: 1,
        pagedTransition: const PagedTransitionState(),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ReaderPagedAnimationSurface(
            model: _pagedModel,
            plan: plan,
            pageBuilder:
                ({
                  required int pageIndex,
                  required bool includeBackgroundDecoration,
                }) => Text('fallback $pageIndex'),
            pagedTransitionAnimation: const AlwaysStoppedAnimation<double>(0),
            curlAnimation: const AlwaysStoppedAnimation<double>(0),
            switchInCurve: Curves.linear,
            paperCurlSurface: ReaderPaperCurlPagedSurface(
              surfaceToken: 'chapter-a',
              pageCount: 3,
              currentPageIndex: 1,
              pageBuilder: (context, pageIndex) => Text('paper $pageIndex'),
            ),
            onPaperCurlPageCommitted: (_) {},
          ),
        ),
      );

      expect(find.byType(ReaderPaperCurlPagedView), findsOneWidget);
      expect(find.text('paper 1'), findsOneWidget);
      expect(find.text('fallback 1'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}

ReaderContentSession _session() {
  return const ReaderContentSession(
    contentMode: ReaderContentMode.text,
    bookId: 'book',
    sourceId: 'source',
    detailUrl: 'detail',
    bookTitle: 'book',
    chapterId: 'chapter',
  );
}

final _pagedModel = ReaderTextPagedViewModel(
  contentSession: _session(),
  settings: const ReaderSettings(),
  surfaceMetrics: _metrics,
  paginationSpec: _paginationSpec,
  palette: _palette,
  pageCount: 3,
  currentPageIndex: 1,
);

const _palette = ReaderPresentationPalette(
  backgroundColor: Color(0xFFFFFFFF),
  surfaceColor: Color(0xFFFFFFFF),
  primaryTextColor: Color(0xFF000000),
  secondaryTextColor: Color(0x99000000),
);

const _metrics = ReaderSurfaceMetrics(
  viewportSize: Size(320, 640),
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
  contentRect: Rect.fromLTWH(0, 0, 320, 640),
  contentWidth: 320,
  contentHeight: 640,
);

const _paginationSpec = ReaderPaginationSpec(
  contentWidth: 320,
  contentHeight: 640,
  contentRectLeft: 0,
  contentRectTop: 0,
  pagePaddingTop: 0,
  pagePaddingRight: 0,
  pagePaddingBottom: 0,
  pagePaddingLeft: 0,
  pinnedHeaderHeight: 0,
  fontSize: 18,
  lineHeight: 1.6,
  paragraphSpacing: 0,
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
