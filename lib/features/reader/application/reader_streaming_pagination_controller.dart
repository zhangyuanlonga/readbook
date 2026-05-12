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
  }) async* {
    final result = await _engine.paginateParagraphs(request);
    if (result == null) {
      yield const ReaderStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.cancelled,
        pages: <List<ReaderPagedSlice>>[],
        completed: false,
      );
      return;
    }
    final pages = result.pages;
    if (pages.isEmpty) {
      yield const ReaderStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.complete,
        pages: <List<ReaderPagedSlice>>[],
        completed: true,
      );
      return;
    }
    final targetPage = _pageIndexForRatio(targetRatio, pages.length);
    final currentPages = _prefixThrough(pages, targetPage);
    yield ReaderStreamingPaginationEvent(
      type: ReaderStreamingPaginationEventType.currentPageReady,
      pages: currentPages,
      completed: currentPages.length == pages.length,
    );

    final nearbyEnd = (targetPage + nearbyPageRadius).clamp(
      0,
      pages.length - 1,
    );
    if (nearbyEnd >= currentPages.length) {
      final nearbyPages = _prefixThrough(pages, nearbyEnd);
      yield ReaderStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.nearbyPageReady,
        pages: nearbyPages,
        completed: nearbyPages.length == pages.length,
      );
    }

    if (currentPages.length < pages.length) {
      yield ReaderStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.complete,
        pages: pages,
        completed: true,
      );
    }
  }

  Stream<ReaderBlockStreamingPaginationEvent> paginateBlocks(
    ReaderBlockPaginationRequest request, {
    double targetRatio = 0,
    int nearbyPageRadius = 1,
  }) async* {
    final result = await _engine.paginateBlocks(request);
    if (result == null) {
      yield const ReaderBlockStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.cancelled,
        pages: <List<ReaderPagedBlock>>[],
        completed: false,
      );
      return;
    }
    final pages = result.pages;
    if (pages.isEmpty) {
      yield const ReaderBlockStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.complete,
        pages: <List<ReaderPagedBlock>>[],
        completed: true,
      );
      return;
    }
    final targetPage = _pageIndexForRatio(targetRatio, pages.length);
    final currentPages = _prefixThrough(pages, targetPage);
    yield ReaderBlockStreamingPaginationEvent(
      type: ReaderStreamingPaginationEventType.currentPageReady,
      pages: currentPages,
      completed: currentPages.length == pages.length,
    );
    final nearbyEnd = (targetPage + nearbyPageRadius).clamp(
      0,
      pages.length - 1,
    );
    if (nearbyEnd >= currentPages.length) {
      final nearbyPages = _prefixThrough(pages, nearbyEnd);
      yield ReaderBlockStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.nearbyPageReady,
        pages: nearbyPages,
        completed: nearbyPages.length == pages.length,
      );
    }
    if (currentPages.length < pages.length) {
      yield ReaderBlockStreamingPaginationEvent(
        type: ReaderStreamingPaginationEventType.complete,
        pages: pages,
        completed: true,
      );
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

  static List<List<T>> _prefixThrough<T>(List<List<T>> pages, int pageIndex) {
    final safeIndex = pageIndex.clamp(0, pages.length - 1);
    return pages.take(safeIndex + 1).toList(growable: false);
  }
}
