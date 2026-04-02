import '../../../domain/entities/chapter.dart';
import 'reader_chapter_navigation.dart';
import 'reader_logical_position.dart';
import 'switch_source_position_resolver.dart';

class ReaderSourceSwitchTarget {
  const ReaderSourceSwitchTarget({
    required this.targetChapterIndex,
    required this.logicalPosition,
    required this.positionDecision,
  });

  final int targetChapterIndex;
  final ReaderLogicalPosition logicalPosition;
  final SwitchSourcePositionDecision positionDecision;
}

class ReaderSourceSwitchTargetResolver {
  const ReaderSourceSwitchTargetResolver({
    SwitchSourcePositionResolver positionResolver =
        const SwitchSourcePositionResolver(),
    ReaderChapterNavigation chapterNavigation = const ReaderChapterNavigation(),
  }) : _positionResolver = positionResolver,
       _chapterNavigation = chapterNavigation;

  final SwitchSourcePositionResolver _positionResolver;
  final ReaderChapterNavigation _chapterNavigation;

  ReaderSourceSwitchTarget resolve({
    required List<Chapter> currentChapters,
    required List<Chapter> targetChapters,
    required String? previousChapterTitle,
    required int? previousChapterIndex,
    required ReaderLogicalPosition? previousLogicalPosition,
    required int lagTolerance,
  }) {
    final positionDecision = _positionResolver.resolve(
      currentChapters: currentChapters,
      targetChapters: targetChapters,
      previousChapterTitle: previousChapterTitle,
      previousChapterIndex: previousChapterIndex,
      lagTolerance: lagTolerance,
    );

    final targetChapterIndex = _chapterNavigation.resolveNearestReadableChapterIndex(
      targetChapters,
      positionDecision.targetIndex.clamp(0, targetChapters.length - 1),
      preferForward: true,
    );
    if (targetChapterIndex == null) {
      throw StateError('目标书源暂无可读章节。');
    }

    final logicalPosition =
        previousLogicalPosition?.copyWith(
          chapterIndex: targetChapterIndex,
          clearPageIndex: true,
        ) ??
        ReaderLogicalPosition(
          chapterIndex: targetChapterIndex,
          blockIndex: 0,
          offsetInBlock: 0,
          chapterPositionRatio: 0,
        );

    return ReaderSourceSwitchTarget(
      targetChapterIndex: targetChapterIndex,
      logicalPosition: logicalPosition,
      positionDecision: positionDecision,
    );
  }
}
