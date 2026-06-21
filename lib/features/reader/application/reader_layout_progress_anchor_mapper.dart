import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';

class ReaderLayoutProgressAnchorMapper {
  const ReaderLayoutProgressAnchorMapper({
    this.hitTestService = const ReaderLayoutHitTestService(),
  });

  final ReaderLayoutHitTestService hitTestService;

  ReaderLayoutProgressSnapshot toProgressSnapshot({
    required List<ReaderLayoutPage> layoutPages,
    required ReaderLayoutPosition position,
  }) {
    if (layoutPages.isEmpty) {
      return ReaderLayoutProgressSnapshot(
        chapterOffset: position.chapterOffset,
        chapterPositionRatio: 0,
        pageIndex: position.pageIndex,
        totalPageCount: 0,
      );
    }
    final offset = hitTestService.positionToChapterOffset(
      position,
      layoutPages: layoutPages,
    );
    return ReaderLayoutProgressSnapshot(
      chapterOffset: offset,
      chapterPositionRatio: _ratioForOffset(layoutPages, offset),
      pageIndex: position.pageIndex.clamp(0, layoutPages.length - 1),
      totalPageCount: layoutPages.length,
    );
  }

  double _ratioForOffset(List<ReaderLayoutPage> layoutPages, int offset) {
    final first = layoutPages.first.startOffset;
    final last = layoutPages.last.endOffset;
    if (last <= first) {
      return 0;
    }
    return ((offset - first) / (last - first)).clamp(0.0, 1.0);
  }
}
