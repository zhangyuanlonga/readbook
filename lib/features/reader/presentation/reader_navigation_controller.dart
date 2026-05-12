import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/bookmark.dart';
import '../application/reader_chapter_flow.dart';

class ReaderNavigationController {
  const ReaderNavigationController({
    ReaderChapterFlow chapterFlow = const ReaderChapterFlow(),
  }) : _chapterFlow = chapterFlow;

  final ReaderChapterFlow _chapterFlow;

  ReaderAdjacentChapterDecision resolveAdjacentChapter({
    required List<Chapter> chapters,
    required int? currentChapterIndex,
    required bool forward,
    double? initialScrollRatio,
  }) {
    return _chapterFlow.resolveAdjacentChapter(
      chapters: chapters,
      currentChapterIndex: currentChapterIndex,
      forward: forward,
      initialScrollRatio: initialScrollRatio,
    );
  }

  Bookmark? findPendingBookmark({
    required String pendingBookmarkId,
    required Iterable<Bookmark> bookmarks,
  }) {
    for (final bookmark in bookmarks) {
      if (bookmark.id == pendingBookmarkId) {
        return bookmark;
      }
    }
    return null;
  }
}
