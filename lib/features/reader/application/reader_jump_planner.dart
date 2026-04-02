import '../../../domain/entities/chapter.dart';
import 'reader_chapter_navigation.dart';

enum ReaderJumpDecisionType { jump, boundary }

class ReaderJumpDecision {
  const ReaderJumpDecision._({
    required this.type,
    this.targetChapterIndex,
    this.isFirstBoundary = false,
  });

  const ReaderJumpDecision.jump({required int targetChapterIndex})
    : this._(
        type: ReaderJumpDecisionType.jump,
        targetChapterIndex: targetChapterIndex,
      );

  const ReaderJumpDecision.boundary({required bool isFirstBoundary})
    : this._(
        type: ReaderJumpDecisionType.boundary,
        isFirstBoundary: isFirstBoundary,
      );

  final ReaderJumpDecisionType type;
  final int? targetChapterIndex;
  final bool isFirstBoundary;
}

class ReaderJumpPlanner {
  const ReaderJumpPlanner({
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _chapterNavigation = chapterNavigation;

  final ReaderChapterNavigation _chapterNavigation;

  ReaderJumpDecision resolve({
    required List<Chapter> chapters,
    required int requestedChapterIndex,
    required int? currentChapterIndex,
  }) {
    final resolvedIndex =
        currentChapterIndex == null ||
                requestedChapterIndex == currentChapterIndex
            ? _chapterNavigation.resolveNearestReadableChapterIndex(
              chapters,
              requestedChapterIndex,
              preferForward: true,
            )
            : _chapterNavigation.findReadableChapterIndex(
              chapters,
              requestedChapterIndex,
              forward: requestedChapterIndex > currentChapterIndex,
            );
    if (resolvedIndex == null) {
      return ReaderJumpDecision.boundary(
        isFirstBoundary: requestedChapterIndex <= (currentChapterIndex ?? 0),
      );
    }
    return ReaderJumpDecision.jump(targetChapterIndex: resolvedIndex);
  }
}
