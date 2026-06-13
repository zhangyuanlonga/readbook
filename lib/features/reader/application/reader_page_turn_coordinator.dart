import '../../../domain/entities/reader_document.dart';
import '../../../domain/entities/reader_settings.dart';
import 'paged_transition_controller.dart';
import 'text_reader_renderer.dart';

enum ReaderPageTurnRequestSource {
  navigationCommand,
  chrome,
  audio,
  autoRead,
  tapZone,
  keyboard,
  swipe,
  volumeKey,
  scrollEdge,
  catalog,
  unknown,
}

enum ReaderPageTurnExecutionType {
  rejected,
  ignored,
  paperCurl,
  crossChapter,
  curl,
  immediate,
  animated,
}

enum ReaderPageTurnRejectReason {
  unsupportedViewport,
  paginating,
  noPages,
  missingAction,
  pageTurnBusy,
  paperCurlUnavailable,
  paperCurlRejected,
  noAdjacentChapter,
  crossChapterCancelled,
}

enum ReaderPageTurnResultType {
  started,
  committed,
  rejected,
  ignored,
  boundary,
  snapshotFailed,
  timedOut,
  fallbackCommitted,
}

class ReaderPageTurnRequest {
  const ReaderPageTurnRequest({
    required this.direction,
    this.source = ReaderPageTurnRequestSource.unknown,
  });

  final int direction;
  final ReaderPageTurnRequestSource source;

  int get safeDirection => direction >= 0 ? 1 : -1;
}

class ReaderPageTurnCoordinatorSnapshot {
  const ReaderPageTurnCoordinatorSnapshot({
    required this.isTextPagedViewport,
    required this.isPaginating,
    required this.pageCount,
    required this.currentPageIndex,
    required this.usesPaperCurlAnimation,
    required this.pagedTransitionAnimating,
  });

  final bool isTextPagedViewport;
  final bool isPaginating;
  final int pageCount;
  final int currentPageIndex;
  final bool usesPaperCurlAnimation;
  final bool pagedTransitionAnimating;
}

class ReaderPageTurnPlan {
  const ReaderPageTurnPlan._({
    required this.executionType,
    required this.request,
    this.action,
    this.rejectReason,
    this.message,
  });

  const ReaderPageTurnPlan.rejected({
    required ReaderPageTurnRequest request,
    required ReaderPageTurnRejectReason reason,
    String? message,
  }) : this._(
         executionType: ReaderPageTurnExecutionType.rejected,
         request: request,
         rejectReason: reason,
         message: message,
       );

  const ReaderPageTurnPlan.ignored({required ReaderPageTurnRequest request})
    : this._(
        executionType: ReaderPageTurnExecutionType.ignored,
        request: request,
      );

  const ReaderPageTurnPlan.execute({
    required ReaderPageTurnRequest request,
    required ReaderPageTurnExecutionType executionType,
    PagedTransitionAction? action,
  }) : this._(executionType: executionType, request: request, action: action);

  final ReaderPageTurnExecutionType executionType;
  final ReaderPageTurnRequest request;
  final PagedTransitionAction? action;
  final ReaderPageTurnRejectReason? rejectReason;
  final String? message;

  int get safeDirection => request.safeDirection;
  int? get targetPageIndex => action?.targetPageIndex;
}

class ReaderPageTurnResult {
  const ReaderPageTurnResult({
    required this.type,
    required this.request,
    this.executionType,
    this.targetPageIndex,
    this.rejectReason,
    this.message,
  });

  final ReaderPageTurnResultType type;
  final ReaderPageTurnRequest request;
  final ReaderPageTurnExecutionType? executionType;
  final int? targetPageIndex;
  final ReaderPageTurnRejectReason? rejectReason;
  final String? message;

  bool get isFailure =>
      type == ReaderPageTurnResultType.rejected ||
      type == ReaderPageTurnResultType.snapshotFailed ||
      type == ReaderPageTurnResultType.timedOut;
}

typedef ReaderPageTurnPlanExecutor =
    Future<ReaderPageTurnResult?> Function(ReaderPageTurnPlan plan);

class ReaderPageTurnExecutionHandlers {
  const ReaderPageTurnExecutionHandlers({
    this.prepareForTurn,
    this.markFirstPageTurnRequested,
    this.onSettleRequired,
    required this.executePaperCurl,
    required this.executeCrossChapter,
    required this.executeCurl,
    required this.executeImmediate,
    required this.executeAnimated,
  });

  final void Function()? prepareForTurn;
  final void Function()? markFirstPageTurnRequested;
  final void Function()? onSettleRequired;
  final ReaderPageTurnPlanExecutor executePaperCurl;
  final ReaderPageTurnPlanExecutor executeCrossChapter;
  final ReaderPageTurnPlanExecutor executeCurl;
  final ReaderPageTurnPlanExecutor executeImmediate;
  final ReaderPageTurnPlanExecutor executeAnimated;
}

class ReaderPageTurnCoordinator {
  const ReaderPageTurnCoordinator({
    this.pagedTransitionController = const PagedTransitionController(),
  });

  final PagedTransitionController pagedTransitionController;

  ReaderPageTurnPlan resolvePagedTextTurn({
    required ReaderPageTurnRequest request,
    required ReaderPageTurnCoordinatorSnapshot snapshot,
    required ReaderSettings settings,
    required PagedTextReaderRenderer renderer,
    ReaderDocument? document,
  }) {
    if (!snapshot.isTextPagedViewport) {
      return ReaderPageTurnPlan.rejected(
        request: request,
        reason: ReaderPageTurnRejectReason.unsupportedViewport,
      );
    }
    if (snapshot.isPaginating) {
      return ReaderPageTurnPlan.rejected(
        request: request,
        reason: ReaderPageTurnRejectReason.paginating,
        message: '分页处理中，请稍后再试。',
      );
    }
    if (snapshot.pageCount <= 0) {
      return ReaderPageTurnPlan.rejected(
        request: request,
        reason: ReaderPageTurnRejectReason.noPages,
      );
    }
    if (snapshot.usesPaperCurlAnimation) {
      return ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.paperCurl,
      );
    }

    final action = pagedTransitionController.planTurn(
      direction: request.safeDirection,
      currentPageIndex: snapshot.currentPageIndex,
      pageCount: snapshot.pageCount,
      settings: settings,
      isAnimating: snapshot.pagedTransitionAnimating,
      renderer: renderer,
      document: document,
    );

    return switch (action.type) {
      PagedTransitionActionType.ignored => ReaderPageTurnPlan.ignored(
        request: request,
      ),
      PagedTransitionActionType.crossChapter => ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.crossChapter,
        action: action,
      ),
      PagedTransitionActionType.curl => ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.curl,
        action: action,
      ),
      PagedTransitionActionType.paperCurl => ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.paperCurl,
        action: action,
      ),
      PagedTransitionActionType.immediate => ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.immediate,
        action: action,
      ),
      PagedTransitionActionType.animated => ReaderPageTurnPlan.execute(
        request: request,
        executionType: ReaderPageTurnExecutionType.animated,
        action: action,
      ),
    };
  }

  ReaderPageTurnResult resultFromPlan(
    ReaderPageTurnPlan plan, {
    required ReaderPageTurnResultType type,
    String? message,
  }) {
    return ReaderPageTurnResult(
      type: type,
      request: plan.request,
      executionType: plan.executionType,
      targetPageIndex: plan.targetPageIndex,
      rejectReason: plan.rejectReason,
      message: message ?? plan.message,
    );
  }

  Future<List<ReaderPageTurnResult>> executePlan({
    required ReaderPageTurnPlan plan,
    required ReaderPageTurnExecutionHandlers handlers,
  }) async {
    if (plan.executionType == ReaderPageTurnExecutionType.rejected) {
      return <ReaderPageTurnResult>[
        resultFromPlan(plan, type: ReaderPageTurnResultType.rejected),
      ];
    }
    if (plan.executionType == ReaderPageTurnExecutionType.ignored) {
      return <ReaderPageTurnResult>[
        resultFromPlan(plan, type: ReaderPageTurnResultType.ignored),
      ];
    }

    handlers.prepareForTurn?.call();
    final results = <ReaderPageTurnResult>[
      resultFromPlan(plan, type: ReaderPageTurnResultType.started),
    ];
    handlers.markFirstPageTurnRequested?.call();

    final result = await switch (plan.executionType) {
      ReaderPageTurnExecutionType.rejected ||
      ReaderPageTurnExecutionType
          .ignored => Future<ReaderPageTurnResult?>.value(null),
      ReaderPageTurnExecutionType.paperCurl => handlers.executePaperCurl(plan),
      ReaderPageTurnExecutionType.crossChapter => handlers.executeCrossChapter(
        plan,
      ),
      ReaderPageTurnExecutionType.curl => handlers.executeCurl(plan),
      ReaderPageTurnExecutionType.immediate => handlers.executeImmediate(plan),
      ReaderPageTurnExecutionType.animated => handlers.executeAnimated(plan),
    };

    if (result != null) {
      results.add(result);
      if (result.isFailure) {
        handlers.onSettleRequired?.call();
      }
    }
    return results;
  }
}
