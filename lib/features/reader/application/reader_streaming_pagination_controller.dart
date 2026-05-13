import 'dart:async';

import 'reader_pagination_engine.dart';
import 'reader_pagination_models.dart';

enum ReaderStreamingPaginationEventType {
  currentPageReady,
  nearbyPageReady,
  complete,
  cancelled,
}

class ReaderStreamingPaginationEvent {
  const ReaderStreamingPaginationEvent({
    required this.type,
    required this.pages,
    required this.completed,
  });

  final ReaderStreamingPaginationEventType type;
  final List<List<ReaderPagedSlice>> pages;
  final bool completed;
}

class ReaderBlockStreamingPaginationEvent {
  const ReaderBlockStreamingPaginationEvent({
    required this.type,
    required this.pages,
    required this.completed,
  });

  final ReaderStreamingPaginationEventType type;
  final List<List<ReaderPagedBlock>> pages;
  final bool completed;
}

class ReaderStreamingPaginationController {
  const ReaderStreamingPaginationController({
    ReaderPaginationEngine engine = const ReaderPaginationEngine(),
  }) : _engine = engine;

  final ReaderPaginationEngine _engine;

  Stream<ReaderStreamingPaginationEvent> paginateText(
    ReaderPaginationRequest request, {
    double targetRatio = 0,
    int nearbyPageRadius = 1,
  }) {
    final controller = StreamController<ReaderStreamingPaginationEvent>();
    unawaited(
      _paginateTextIntoController(
        controller: controller,
        request: request,
        targetRatio: targetRatio,
        nearbyPageRadius: nearbyPageRadius,
      ),
    );
    return controller.stream;
  }

  Future<void> _paginateTextIntoController({
    required StreamController<ReaderStreamingPaginationEvent> controller,
    required ReaderPaginationRequest request,
    required double targetRatio,
    required int nearbyPageRadius,
  }) async {
    final pagesSoFar = <List<ReaderPagedSlice>>[];
    final targetParagraphIndex = _paragraphIndexForRatio(
      targetRatio,
      request.paragraphs.length,
    );
    var currentPageEmitted = false;
    var currentPageCount = 0;
    var nearbyPageEmitted = false;

    try {
      final result = await _engine.paginateParagraphs(
        request,
        onPageReady: (page, pageIndex) {
          pagesSoFar.add(page);
          if (!currentPageEmitted &&
              _textPageReachesTarget(page, targetParagraphIndex)) {
            currentPageEmitted = true;
            currentPageCount = pagesSoFar.length;
            controller.add(
              ReaderStreamingPaginationEvent(
                type: ReaderStreamingPaginationEventType.currentPageReady,
                pages: List<List<ReaderPagedSlice>>.unmodifiable(pagesSoFar),
                completed: false,
              ),
            );
          }
          if (currentPageEmitted &&
              !nearbyPageEmitted &&
              pagesSoFar.length >= currentPageCount + nearbyPageRadius) {
            nearbyPageEmitted = true;
            controller.add(
              ReaderStreamingPaginationEvent(
                type: ReaderStreamingPaginationEventType.nearbyPageReady,
                pages: List<List<ReaderPagedSlice>>.unmodifiable(pagesSoFar),
                completed: false,
              ),
            );
          }
        },
      );
      if (result == null) {
        controller.add(
          const ReaderStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.cancelled,
            pages: <List<ReaderPagedSlice>>[],
            completed: false,
          ),
        );
        return;
      }
      final pages = result.pages;
      if (pages.isEmpty) {
        controller.add(
          const ReaderStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.complete,
            pages: <List<ReaderPagedSlice>>[],
            completed: true,
          ),
        );
        return;
      }
      if (!currentPageEmitted) {
        controller.add(
          ReaderStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.currentPageReady,
            pages: _prefixThrough(
              pages,
              _pageIndexForRatio(targetRatio, pages.length),
            ),
            completed: false,
          ),
        );
      }
      controller.add(
        ReaderStreamingPaginationEvent(
          type: ReaderStreamingPaginationEventType.complete,
          pages: pages,
          completed: true,
        ),
      );
    } finally {
      await controller.close();
    }
  }

  Stream<ReaderBlockStreamingPaginationEvent> paginateBlocks(
    ReaderBlockPaginationRequest request, {
    double targetRatio = 0,
    int nearbyPageRadius = 1,
  }) {
    final controller = StreamController<ReaderBlockStreamingPaginationEvent>();
    unawaited(
      _paginateBlocksIntoController(
        controller: controller,
        request: request,
        targetRatio: targetRatio,
        nearbyPageRadius: nearbyPageRadius,
      ),
    );
    return controller.stream;
  }

  Future<void> _paginateBlocksIntoController({
    required StreamController<ReaderBlockStreamingPaginationEvent> controller,
    required ReaderBlockPaginationRequest request,
    required double targetRatio,
    required int nearbyPageRadius,
  }) async {
    final pagesSoFar = <List<ReaderPagedBlock>>[];
    final targetParagraphIndex = _paragraphIndexForRatio(
      targetRatio,
      request.paragraphs.length,
    );
    var currentPageEmitted = false;
    var currentPageCount = 0;
    var nearbyPageEmitted = false;

    try {
      final result = await _engine.paginateBlocks(
        request,
        onPageReady: (page, pageIndex) {
          pagesSoFar.add(page);
          if (!currentPageEmitted &&
              _blockPageReachesTarget(page, targetParagraphIndex)) {
            currentPageEmitted = true;
            currentPageCount = pagesSoFar.length;
            controller.add(
              ReaderBlockStreamingPaginationEvent(
                type: ReaderStreamingPaginationEventType.currentPageReady,
                pages: List<List<ReaderPagedBlock>>.unmodifiable(pagesSoFar),
                completed: false,
              ),
            );
          }
          if (currentPageEmitted &&
              !nearbyPageEmitted &&
              pagesSoFar.length >= currentPageCount + nearbyPageRadius) {
            nearbyPageEmitted = true;
            controller.add(
              ReaderBlockStreamingPaginationEvent(
                type: ReaderStreamingPaginationEventType.nearbyPageReady,
                pages: List<List<ReaderPagedBlock>>.unmodifiable(pagesSoFar),
                completed: false,
              ),
            );
          }
        },
      );
      if (result == null) {
        controller.add(
          const ReaderBlockStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.cancelled,
            pages: <List<ReaderPagedBlock>>[],
            completed: false,
          ),
        );
        return;
      }
      final pages = result.pages;
      if (pages.isEmpty) {
        controller.add(
          const ReaderBlockStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.complete,
            pages: <List<ReaderPagedBlock>>[],
            completed: true,
          ),
        );
        return;
      }
      if (!currentPageEmitted) {
        controller.add(
          ReaderBlockStreamingPaginationEvent(
            type: ReaderStreamingPaginationEventType.currentPageReady,
            pages: _prefixThrough(
              pages,
              _pageIndexForRatio(targetRatio, pages.length),
            ),
            completed: false,
          ),
        );
      }
      controller.add(
        ReaderBlockStreamingPaginationEvent(
          type: ReaderStreamingPaginationEventType.complete,
          pages: pages,
          completed: true,
        ),
      );
    } finally {
      await controller.close();
    }
  }

  static int _pageIndexForRatio(double ratio, int pageCount) {
    if (pageCount <= 1) {
      return 0;
    }
    return (ratio.clamp(0.0, 1.0) * (pageCount - 1)).round().clamp(
      0,
      pageCount - 1,
    );
  }

  static int _paragraphIndexForRatio(double ratio, int paragraphCount) {
    if (paragraphCount <= 1) {
      return 0;
    }
    return (ratio.clamp(0.0, 1.0) * (paragraphCount - 1)).round().clamp(
      0,
      paragraphCount - 1,
    );
  }

  static bool _textPageReachesTarget(
    List<ReaderPagedSlice> page,
    int targetParagraphIndex,
  ) {
    return page.any((slice) => slice.paragraphIndex >= targetParagraphIndex);
  }

  static bool _blockPageReachesTarget(
    List<ReaderPagedBlock> page,
    int targetParagraphIndex,
  ) {
    if (targetParagraphIndex <= 0) {
      return true;
    }
    return page.any(
      (block) =>
          block.kind == ReaderPagedBlockKind.text &&
          (block.paragraphIndex ?? 0) >= targetParagraphIndex,
    );
  }

  static List<List<T>> _prefixThrough<T>(List<List<T>> pages, int pageIndex) {
    final safeIndex = pageIndex.clamp(0, pages.length - 1);
    return pages.take(safeIndex + 1).toList(growable: false);
  }
}
