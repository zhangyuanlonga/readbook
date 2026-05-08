import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_session_state.dart';
import 'package:shuxiang_reading_next/features/reader/application/text_reader_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScrollTextReaderRenderer', () {
    const renderer = ScrollTextReaderRenderer();

    test('captures scroll progress from metrics', () {
      const metrics = ReaderRenderMetrics(
        hasScrollClients: true,
        maxScrollExtent: 400,
        scrollOffset: 120,
      );

      expect(renderer.kind, TextReaderRendererKind.scroll);
      expect(renderer.captureProgress(metrics), closeTo(0.3, 0.0001));
    });

    test('plans restore offset for scroll mode', () {
      const metrics = ReaderRenderMetrics(
        hasScrollClients: true,
        maxScrollExtent: 500,
      );

      final plan = renderer.planRestore(ratio: 0.64, metrics: metrics);

      expect(plan.shouldDefer, isFalse);
      expect(plan.scrollOffset, closeTo(320, 0.0001));
    });
  });

  group('PagedTextReaderRenderer', () {
    const renderer = PagedTextReaderRenderer();

    test('captures page progress from page index', () {
      const metrics = ReaderRenderMetrics(pageCount: 5, currentPageIndex: 3);

      expect(renderer.kind, TextReaderRendererKind.paged);
      expect(renderer.captureProgress(metrics), closeTo(0.75, 0.0001));
    });

    test('defers restore when page count is not ready', () {
      const metrics = ReaderRenderMetrics(pageCount: 0);

      final plan = renderer.planRestore(ratio: 0.5, metrics: metrics);

      expect(plan.shouldDefer, isTrue);
      expect(plan.pageIndex, isNull);
      expect(plan.normalizedRatio, 0.5);
    });

    test('restores conservatively without jumping to the next page early', () {
      const metrics = ReaderRenderMetrics(pageCount: 8);

      final plan = renderer.planRestore(ratio: 0.125, metrics: metrics);

      expect(plan.shouldDefer, isFalse);
      expect(plan.pageIndex, 1);
    });

    test('keeps early first-page progress on the first page', () {
      const metrics = ReaderRenderMetrics(pageCount: 8);

      final plan = renderer.planRestore(ratio: 0.12, metrics: metrics);

      expect(plan.shouldDefer, isFalse);
      expect(plan.pageIndex, 0);
    });

    test('resolves animated turn decision with settings style', () {
      final decision = renderer.resolveTurnDecision(
        direction: 1,
        currentPageIndex: 2,
        pageCount: 8,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.translate,
        ),
      );

      expect(decision.type, PagedTurnDecisionType.animated);
      expect(decision.targetPageIndex, 3);
      expect(decision.animationStyle, ReaderPageAnimationStyle.translate);
    });

    test('resolves curl turn and cross chapter decisions', () {
      final curlDecision = renderer.resolveTurnDecision(
        direction: -1,
        currentPageIndex: 3,
        pageCount: 8,
        settings: const ReaderSettings(
          pageAnimationStyle: ReaderPageAnimationStyle.curl,
        ),
      );
      final crossChapterDecision = renderer.resolveTurnDecision(
        direction: 1,
        currentPageIndex: 7,
        pageCount: 8,
        settings: const ReaderSettings(),
      );

      expect(curlDecision.type, PagedTurnDecisionType.curl);
      expect(curlDecision.targetPageIndex, 2);
      expect(crossChapterDecision.type, PagedTurnDecisionType.crossChapter);
      expect(crossChapterDecision.targetPageIndex, 7);
    });

    test('exposes animation motion spec for style', () {
      final motion = renderer.motionSpecForStyle(ReaderPageAnimationStyle.fade);
      final disabled = renderer.motionSpecForStyle(
        ReaderPageAnimationStyle.none,
      );

      expect(motion.duration, const Duration(milliseconds: 380));
      expect(disabled.duration, Duration.zero);
    });
  });
}
