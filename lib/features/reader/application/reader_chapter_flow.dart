import '../../../domain/entities/chapter.dart';
import 'reader_chapter_navigation.dart';

enum ReaderAdjacentChapterDecisionType { noCurrent, boundary, jump }

class ReaderAdjacentChapterDecision {
  const ReaderAdjacentChapterDecision._({
    required this.type,
    this.targetChapterIndex,
    this.initialScrollRatio,
    this.isFirstBoundary = false,
  });

  const ReaderAdjacentChapterDecision.noCurrent()
    : this._(type: ReaderAdjacentChapterDecisionType.noCurrent);

  const ReaderAdjacentChapterDecision.boundary({required bool isFirst})
    : this._(
        type: ReaderAdjacentChapterDecisionType.boundary,
        isFirstBoundary: isFirst,
      );

  const ReaderAdjacentChapterDecision.jump({
    required int targetChapterIndex,
    required double initialScrollRatio,
  }) : this._(
         type: ReaderAdjacentChapterDecisionType.jump,
         targetChapterIndex: targetChapterIndex,
         initialScrollRatio: initialScrollRatio,
       );

  final ReaderAdjacentChapterDecisionType type;
  final int? targetChapterIndex;
  final double? initialScrollRatio;
  final bool isFirstBoundary;
}

class ReaderChapterFlow {
  const ReaderChapterFlow({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;

  ReaderAdjacentChapterDecision resolveAdjacentChapter({
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    required bool forward,
    double? initialScrollRatio,
  }) {
    if (currentChapterIndex == null) {
      return const ReaderAdjacentChapterDecision.noCurrent();
    }

    final targetChapterIndex = _chapterNavigation.findReadableChapterIndex(
      chapters,
      currentChapterIndex + (forward ? 1 : -1),
      forward: forward,
    );
    if (targetChapterIndex == null) {
      return ReaderAdjacentChapterDecision.boundary(isFirst: !forward);
    }

    return ReaderAdjacentChapterDecision.jump(
      targetChapterIndex: targetChapterIndex,
      initialScrollRatio: initialScrollRatio ?? (forward ? 0 : 1),
    );
  }
}
