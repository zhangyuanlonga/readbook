import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_navigation_entry_resolver.dart';

void main() {
  group('ReaderNavigationEntryResolver', () {
    const resolver = ReaderNavigationEntryResolver();
    final chapters = <Chapter>[
      const Chapter(
        id: 'c1',
        bookId: 'book',
        title: '卷一',
        chapterUrl: 'u1',
        index: 0,
        isVolume: true,
      ),
      const Chapter(
        id: 'c2',
        bookId: 'book',
        title: '第一章',
        chapterUrl: 'u2',
        index: 1,
      ),
      const Chapter(
        id: 'c3',
        bookId: 'book',
        title: '第二章',
        chapterUrl: 'u3',
        index: 2,
      ),
    ];

    test('resolves progress selection to restore current request', () {
      final request = resolver.resolveProgressSelection(scrollRatio: 0.42);

      expect(request.type, ReaderNavigationRequestType.restoreCurrent);
      expect(request.initialScrollRatio, 0.42);
    });

    test('resolves catalog search entry to readable jump request', () {
      final request = resolver.resolveCatalogSearchEntry(
        entry: const ReaderCatalogSearchEntryAdapter(
          chapterIndex: 0,
          targetChapterIndex: 1,
          isVolume: true,
          isContent: false,
        ),
        chapters: chapters,
      );

      expect(request, isNotNull);
      expect(request!.type, ReaderNavigationRequestType.jumpChapter);
      expect(request.targetChapterIndex, 1);
    });

    test('resolves bookmark chapter index through readable chapter lookup', () {
      final bookmark = Bookmark(
        id: 'b1',
        bookId: 'book',
        chapterId: 'c1',
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 2,
        snippet: '片段',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final targetIndex = resolver.resolveBookmarkChapterIndex(
        bookmark: bookmark,
        chapters: chapters,
      );

      expect(targetIndex, 1);
    });
  });
}
