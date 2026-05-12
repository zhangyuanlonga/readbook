import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/presentation/reader_navigation_controller.dart';

void main() {
  group('ReaderNavigationController', () {
    const controller = ReaderNavigationController();
    const chapters = <Chapter>[
      Chapter(
        id: 'chapter-1',
        bookId: 'book-1',
        title: '第一章',
        chapterUrl: 'chapter://1',
        index: 0,
      ),
      Chapter(
        id: 'chapter-2',
        bookId: 'book-1',
        title: '第二章',
        chapterUrl: 'chapter://2',
        index: 1,
      ),
    ];

    test('resolves adjacent chapter decision through chapter flow', () {
      final decision = controller.resolveAdjacentChapter(
        chapters: chapters,
        currentChapterIndex: 0,
        forward: true,
      );

      expect(decision.targetChapterIndex, 1);
    });

    test('finds pending bookmark by id', () {
      final bookmark = Bookmark(
        id: 'b1',
        bookId: 'book-1',
        chapterId: 'chapter-2',
        chapterIndex: 1,
        startOffset: 1,
        endOffset: 2,
        snippet: '片段',
        createdAt: DateTime(2026, 4, 26, 12),
        updatedAt: DateTime(2026, 4, 26, 12),
      );

      expect(
        controller.findPendingBookmark(
          pendingBookmarkId: 'b1',
          bookmarks: <Bookmark>[bookmark],
        ),
        bookmark,
      );
    });
  });
}
