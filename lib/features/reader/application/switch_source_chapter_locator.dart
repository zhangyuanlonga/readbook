import '../../../domain/entities/chapter.dart';

class SwitchSourceChapterLocator {
  const SwitchSourceChapterLocator();

  static final RegExp _spacePattern = RegExp(r'[\u3000\s]+');
  static final RegExp _symbolPattern = RegExp(
    r'''[·•\-_:：|/\\\(\)\[\]【】<>《》"'‘’,.，。!?！？]''',
  );

  int resolveTargetChapterIndex({
    required List<Chapter> chapters,
    required String? previousChapterTitle,
    required int? previousChapterIndex,
  }) {
    if (chapters.isEmpty) {
      return 0;
    }

    final normalizedPreviousTitle = _normalize(previousChapterTitle ?? '');
    if (normalizedPreviousTitle.isNotEmpty) {
      var bestIndex = -1;
      var bestScore = 0;

      for (var index = 0; index < chapters.length; index++) {
        final normalizedTitle = _normalize(chapters[index].title);
        if (normalizedTitle.isEmpty) {
          continue;
        }

        var score = 0;
        if (normalizedTitle == normalizedPreviousTitle) {
          score = 1000;
        } else if (normalizedTitle.startsWith(normalizedPreviousTitle) ||
            normalizedPreviousTitle.startsWith(normalizedTitle)) {
          score = 800;
        } else if (normalizedTitle.contains(normalizedPreviousTitle) ||
            normalizedPreviousTitle.contains(normalizedTitle)) {
          score = 600;
        }

        if (score > bestScore) {
          bestScore = score;
          bestIndex = index;
        }
      }

      if (bestIndex >= 0 && bestScore > 0) {
        return bestIndex;
      }
    }

    if (previousChapterIndex != null) {
      return previousChapterIndex.clamp(0, chapters.length - 1);
    }
    return 0;
  }

  String _normalize(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(_spacePattern, '')
        .replaceAll(_symbolPattern, '');
  }
}
