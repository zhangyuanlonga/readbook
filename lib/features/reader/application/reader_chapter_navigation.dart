import '../../../domain/entities/chapter.dart';

class ReaderChapterNavigation {
  const ReaderChapterNavigation();

  bool isReadableChapter(Chapter chapter) {
    return !chapter.isVolume && chapter.chapterUrl.trim().isNotEmpty;
  }

  List<Chapter> readableChapters(List<Chapter> chapters) {
    return chapters.where(isReadableChapter).toList(growable: false);
  }

  int? findReadableChapterIndex(
    List<Chapter> chapters,
    int startIndex, {
    required bool forward,
  }) {
    if (chapters.isEmpty || startIndex < 0 || startIndex >= chapters.length) {
      return null;
    }

    if (forward) {
      for (var index = startIndex; index < chapters.length; index++) {
        if (isReadableChapter(chapters[index])) {
          return index;
        }
      }
      return null;
    }

    for (var index = startIndex; index >= 0; index--) {
      if (isReadableChapter(chapters[index])) {
        return index;
      }
    }
    return null;
  }

  int? resolveNearestReadableChapterIndex(
    List<Chapter> chapters,
    int startIndex, {
    required bool preferForward,
  }) {
    return preferForward
        ? findReadableChapterIndex(chapters, startIndex, forward: true) ??
            findReadableChapterIndex(chapters, startIndex, forward: false)
        : findReadableChapterIndex(chapters, startIndex, forward: false) ??
            findReadableChapterIndex(chapters, startIndex, forward: true);
  }
}
