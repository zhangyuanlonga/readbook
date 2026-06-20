import '../domain/entities/reader_layout_models.dart';
import 'reader_layout_anchor_models.dart';
import 'reader_layout_hit_test_service.dart';
import 'reader_selection_runtime.dart';

enum ReaderReadAloudAdvanceUnit { line, block }

class ReaderReadAloudAnchorStep {
  const ReaderReadAloudAnchorStep({
    required this.current,
    required this.nextPosition,
    required this.isChapterEnd,
  });

  final ReaderLayoutAnchoredRange current;
  final ReaderLayoutPosition? nextPosition;
  final bool isChapterEnd;
}

class ReaderReadAloudAnchorMapper {
  const ReaderReadAloudAnchorMapper({
    this.hitTestService = const ReaderLayoutHitTestService(),
    this.selectionRuntime = const ReaderSelectionRuntime(),
  });

  final ReaderLayoutHitTestService hitTestService;
  final ReaderSelectionRuntime selectionRuntime;

  ReaderReadAloudAnchorStep? resolveStep({
    required List<ReaderLayoutPage> layoutPages,
    required int chapterOffset,
    ReaderReadAloudAdvanceUnit unit = ReaderReadAloudAdvanceUnit.line,
  }) {
    if (layoutPages.isEmpty) {
      return null;
    }
    final position = hitTestService.chapterOffsetToPosition(
      layoutPages,
      chapterOffset,
    );
    if (position == null) {
      return null;
    }
    final line = _lineAt(layoutPages, position);
    if (line == null) {
      return null;
    }
    final bounds = switch (unit) {
      ReaderReadAloudAdvanceUnit.line => (
        start: line.chapterOffset,
        end: line.endChapterOffset,
      ),
      ReaderReadAloudAdvanceUnit.block => _blockBounds(layoutPages, line),
    };
    final snapshot = selectionRuntime.selectOffsets(
      layoutPages: layoutPages,
      startOffset: bounds.start,
      endOffset: bounds.end,
      kind: ReaderLayoutAnchorKind.readAloud,
    );
    if (snapshot == null || snapshot.isCollapsed) {
      return null;
    }
    final nextPosition = _nextPositionAfter(layoutPages, bounds.end);
    return ReaderReadAloudAnchorStep(
      current: snapshot.anchor,
      nextPosition: nextPosition,
      isChapterEnd: nextPosition == null,
    );
  }

  ReaderLayoutLine? _lineAt(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutPosition position,
  ) {
    for (final page in layoutPages) {
      if (page.pageIndex != position.pageIndex) {
        continue;
      }
      for (final line in page.lines) {
        if (line.lineIndex == position.lineIndex) {
          return line;
        }
      }
    }
    return null;
  }

  ({int start, int end}) _blockBounds(
    List<ReaderLayoutPage> layoutPages,
    ReaderLayoutLine target,
  ) {
    var start = target.chapterOffset;
    var end = target.endChapterOffset;
    for (final page in layoutPages) {
      for (final line in page.lines) {
        if (line.paragraphIndex != target.paragraphIndex) {
          continue;
        }
        if (line.chapterOffset < start) {
          start = line.chapterOffset;
        }
        if (line.endChapterOffset > end) {
          end = line.endChapterOffset;
        }
      }
    }
    return (start: start, end: end);
  }

  ReaderLayoutPosition? _nextPositionAfter(
    List<ReaderLayoutPage> layoutPages,
    int chapterOffset,
  ) {
    for (final page in layoutPages) {
      for (final line in page.lines) {
        if (line.endChapterOffset <= chapterOffset) {
          continue;
        }
        return hitTestService.chapterOffsetToPosition(
          layoutPages,
          line.chapterOffset,
        );
      }
    }
    return null;
  }
}
