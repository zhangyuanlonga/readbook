import '../../../domain/entities/chapter.dart';
import 'switch_source_chapter_locator.dart';

class SwitchSourcePositionDecision {
  const SwitchSourcePositionDecision({
    required this.targetIndex,
    required this.currentReadingChapterNo,
    required this.targetChapterCount,
    required this.isBehindCurrentReading,
    required this.isSignificantlyBehind,
  });

  final int targetIndex;
  final int currentReadingChapterNo;
  final int targetChapterCount;
  final bool isBehindCurrentReading;
  final bool isSignificantlyBehind;
}

class SwitchSourcePositionResolver {
  const SwitchSourcePositionResolver({
    SwitchSourceChapterLocator chapterLocator =
        const SwitchSourceChapterLocator(),
  }) : _chapterLocator = chapterLocator;

  final SwitchSourceChapterLocator _chapterLocator;

  SwitchSourcePositionDecision resolve({
    required List<Chapter> currentChapters,
    required List<Chapter> targetChapters,
    required String? previousChapterTitle,
    required int? previousChapterIndex,
    required int lagTolerance,
  }) {
    if (targetChapters.isEmpty) {
      throw StateError('新书享源目录为空。');
    }

    final currentReadingChapterNo = (previousChapterIndex ?? 0) + 1;
    final targetChapterCount = targetChapters.length;
    final isBehindCurrentReading = targetChapterCount < currentReadingChapterNo;
    final isSignificantlyBehind =
        currentChapters.isNotEmpty &&
        targetChapterCount + lagTolerance < currentChapters.length;

    final targetIndex = _chapterLocator.resolveTargetChapterIndex(
      chapters: targetChapters,
      previousChapterTitle: previousChapterTitle,
      previousChapterIndex: previousChapterIndex,
    );

    return SwitchSourcePositionDecision(
      targetIndex: targetIndex,
      currentReadingChapterNo: currentReadingChapterNo,
      targetChapterCount: targetChapterCount,
      isBehindCurrentReading: isBehindCurrentReading,
      isSignificantlyBehind: isSignificantlyBehind,
    );
  }
}
