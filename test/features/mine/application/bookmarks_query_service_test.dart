import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookmark.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/domain/repositories/bookmark_repository.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:shuxiang_reading_next/features/mine/application/bookmarks_query_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('loads bookmarks and bookshelf index together', () async {
    final service = BookmarksQueryService(
      bookmarkRepository: _FakeBookmarkRepository(),
      bookshelfService: _FakeBookshelfService(),
    );

    final result = await service.loadPageData(
      timeout: const Duration(seconds: 1),
    );

    expect(result.bookmarks, hasLength(1));
    expect(result.bookshelfIndex['book_1']?.title, '书架书');
    expect(result.groups, hasLength(1));
    expect(result.groups.first.displayTitle, '书架书');
  });
}

class _FakeBookmarkRepository implements BookmarkRepository {
  @override
  Future<void> addBookmark(Bookmark bookmark) => throw UnimplementedError();

  @override
  Future<List<Bookmark>> listAllBookmarks() async {
    return <Bookmark>[
      Bookmark(
        id: 'bookmark_1',
        bookId: 'book_1',
        chapterId: 'chapter_1',
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 10,
        snippet: '片段',
        createdAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
        updatedAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
      ),
    ];
  }

  @override
  Future<List<Bookmark>> listBookmarks(String bookId) =>
      throw UnimplementedError();

  @override
  Future<void> removeBookmark(String bookmarkId) => throw UnimplementedError();
}

class _FakeBookshelfService extends BookshelfService {
  @override
  Future<List<BookshelfBook>> getAll() async {
    return <BookshelfBook>[
      BookshelfBook(
        bookId: 'book_1',
        sourceId: 'source_a',
        detailUrl: '/detail/1',
        title: '书架书',
        addedAt: DateTime.parse('2026-04-27T00:00:00.000Z'),
      ),
    ];
  }
}
