import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_page_turn_coordinator.dart';
import 'package:shuxiang_reading_next/features/reader/application/text_reader_renderer.dart';

void main() {
  group('ReaderPageTurnCoordinator', () {
    const coordinator = ReaderPageTurnCoordinator();
    const request = ReaderPageTurnRequest(
      direction: 1,
      source: ReaderPageTurnRequestSource.navigationCommand,
    );

    test('rejects unsupported viewport before planning animation', () {
      final plan = coordinator.resolvePagedTextTurn(
        request: request,
        snapshot: _snapshot(isTextPagedViewport: false),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      expect(plan.executionType, ReaderPageTurnExecutionType.rejected);
      expect(plan.rejectReason, ReaderPageTurnRejectReason.unsupportedViewport);
    });

    test('rejects while pagination is running', () {
      final plan = coordinator.resolvePagedTextTurn(
        request: request,
        snapshot: _snapshot(isPaginating: true),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      expect(plan.executionType, ReaderPageTurnExecutionType.rejected);
      expect(plan.rejectReason, ReaderPageTurnRejectReason.paginating);
      expect(plan.message, '分页处理中，请稍后再试。');
    });

    test('routes paper curl before normal transition planning', () {
      final plan = coordinator.resolvePagedTextTurn(
        request: request,
        snapshot: _snapshot(usesPaperCurlAnimation: true),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      expect(plan.executionType, ReaderPageTurnExecutionType.paperCurl);
      expect(plan.safeDirection, 1);
    });

    test('normalizes negative direction', () {
      final plan = coordinator.resolvePagedTextTurn(
        request: const ReaderPageTurnRequest(direction: -8),
        snapshot: _snapshot(usesPaperCurlAnimation: true),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      expect(plan.safeDirection, -1);
    });

    test('executor returns rejected result without running handlers', () async {
      var prepared = false;
      final plan = coordinator.resolvePagedTextTurn(
        request: request,
        snapshot: _snapshot(isPaginating: true),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      final results = await coordinator.executePlan(
        plan: plan,
        handlers: _handlers(
          prepareForTurn: () => prepared = true,
          executePaperCurl:
              (_) => throw StateError('paper curl should not execute'),
        ),
      );

      expect(prepared, isFalse);
      expect(results, hasLength(1));
      expect(results.single.type, ReaderPageTurnResultType.rejected);
      expect(results.single.request.source, request.source);
    });

    test('executor emits started result then delegates paper curl', () async {
      var prepared = false;
      var markedFirstTurn = false;
      const tapZoneRequest = ReaderPageTurnRequest(
        direction: 1,
        source: ReaderPageTurnRequestSource.tapZone,
      );
      final plan = coordinator.resolvePagedTextTurn(
        request: tapZoneRequest,
        snapshot: _snapshot(usesPaperCurlAnimation: true),
        settings: const ReaderSettings(),
        renderer: const PagedTextReaderRenderer(),
      );

      final results = await coordinator.executePlan(
        plan: plan,
        handlers: _handlers(
          prepareForTurn: () => prepared = true,
          markFirstPageTurnRequested: () => markedFirstTurn = true,
          executePaperCurl:
              (plan) async => ReaderPageTurnResult(
                type: ReaderPageTurnResultType.committed,
                request: plan.request,
                executionType: plan.executionType,
                targetPageIndex: 2,
              ),
        ),
      );

      expect(prepared, isTrue);
      expect(markedFirstTurn, isTrue);
      expect(results.map((result) => result.type), [
        ReaderPageTurnResultType.started,
        ReaderPageTurnResultType.committed,
      ]);
      expect(results.first.request.source, ReaderPageTurnRequestSource.tapZone);
      expect(results.last.request.source, ReaderPageTurnRequestSource.tapZone);
    });
  });
}

ReaderPageTurnExecutionHandlers _handlers({
  void Function()? prepareForTurn,
  void Function()? markFirstPageTurnRequested,
  ReaderPageTurnPlanExecutor? executePaperCurl,
}) {
  Future<ReaderPageTurnResult?> noop(ReaderPageTurnPlan plan) async => null;

  return ReaderPageTurnExecutionHandlers(
    prepareForTurn: prepareForTurn,
    markFirstPageTurnRequested: markFirstPageTurnRequested,
    executePaperCurl: executePaperCurl ?? noop,
    executeCrossChapter: noop,
    executeCurl: noop,
    executeImmediate: noop,
    executeAnimated: noop,
  );
}

ReaderPageTurnCoordinatorSnapshot _snapshot({
  bool isTextPagedViewport = true,
  bool isPaginating = false,
  int pageCount = 3,
  int currentPageIndex = 1,
  bool usesPaperCurlAnimation = false,
  bool pagedTransitionAnimating = false,
}) {
  return ReaderPageTurnCoordinatorSnapshot(
    isTextPagedViewport: isTextPagedViewport,
    isPaginating: isPaginating,
    pageCount: pageCount,
    currentPageIndex: currentPageIndex,
    usesPaperCurlAnimation: usesPaperCurlAnimation,
    pagedTransitionAnimating: pagedTransitionAnimating,
  );
}
