import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';

class ReaderLayoutProgressAnchorMapper {
  const ReaderLayoutProgressAnchorMapper({
    this.hitTestService = const ReaderLayoutHitTestService(),
  });

  final ReaderLayoutHitTestService hitTestService;

  ReaderLayoutAnchoredPosition? fromLegacyProgress({
    required List<ReaderLayoutPage> layoutPages,
    required double chapterProgressRatio,
    int? chapterOffset,
    String? sourceId,
  }) {
    if (layoutPages.isEmpty) {
      return null;
    }
    final offset =
        chapterOffset ?? _offsetForRatio(layoutPages, chapterProgressRatio);
    final position = hitTestService.chapterOffsetToPosition(
      layoutPages,
      offset,
    );
    if (position == null) {
      return null;
    }
    return ReaderLayoutAnchoredPosition(
      kind: ReaderLayoutAnchorKind.progress,
      position: position,
      chapterProgressRatio: _ratioForOffset(
        layoutPages,
        position.chapterOffset,
      ),
      layoutSignature: _layoutSignatureFor(layoutPages, position.pageIndex),
      sourceId: sourceId,
      totalPageCount: layoutPages.length,
    );
  }

  ReaderLayoutLegacyProgressSnapshot toLegacyProgress({
    required List<ReaderLayoutPage> layoutPages,
    required ReaderLayoutPosition position,
  }) {
    if (layoutPages.isEmpty) {
      return ReaderLayoutLegacyProgressSnapshot(
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
    return ReaderLayoutLegacyProgressSnapshot(
      chapterOffset: offset,
      chapterPositionRatio: _ratioForOffset(layoutPages, offset),
      pageIndex: position.pageIndex.clamp(0, layoutPages.length - 1),
      totalPageCount: layoutPages.length,
    );
  }

  int _offsetForRatio(List<ReaderLayoutPage> layoutPages, double ratio) {
    final first = layoutPages.first.startOffset;
    final last = layoutPages.last.endOffset;
    if (last <= first) {
      return first;
    }
    return first + ((last - first) * ratio.clamp(0.0, 1.0)).round();
  }

  double _ratioForOffset(List<ReaderLayoutPage> layoutPages, int offset) {
    final first = layoutPages.first.startOffset;
    final last = layoutPages.last.endOffset;
    if (last <= first) {
      return 0;
    }
    return ((offset - first) / (last - first)).clamp(0.0, 1.0);
  }

  String? _layoutSignatureFor(
    List<ReaderLayoutPage> layoutPages,
    int pageIndex,
  ) {
    for (final page in layoutPages) {
      if (page.pageIndex == pageIndex) {
        return page.layoutSignature;
      }
    }
    return layoutPages.first.layoutSignature;
  }
}
