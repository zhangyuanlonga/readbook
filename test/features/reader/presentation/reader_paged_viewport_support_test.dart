import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/paged_transition_controller.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_paged_viewport_support.dart';

void main() {
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
  });

  group('ReaderPagedPageFrame', () {
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
  });
}
