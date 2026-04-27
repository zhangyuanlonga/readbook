import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';

class BookmarksPageData {
  const BookmarksPageData({
    required this.bookmarks,
    required this.bookshelfIndex,
  });

  final List<Bookmark> bookmarks;
  final Map<String, BookshelfBook> bookshelfIndex;
}

class BookmarksQueryService {
  const BookmarksQueryService({
    required BookmarkRepository bookmarkRepository,
    required BookshelfService bookshelfService,
  }) : _bookmarkRepository = bookmarkRepository,
       _bookshelfService = bookshelfService;

  final BookmarkRepository _bookmarkRepository;
  final BookshelfService _bookshelfService;

  Future<BookmarksPageData> loadPageData({required Duration timeout}) async {
    final bookmarks = await _bookmarkRepository.listAllBookmarks().timeout(
      timeout,
      onTimeout: () => const <Bookmark>[],
    );
    final books = await _bookshelfService.getAll().timeout(
      timeout,
      onTimeout: () => const <BookshelfBook>[],
    );
    return BookmarksPageData(
      bookmarks: bookmarks,
      bookshelfIndex: <String, BookshelfBook>{
        for (final book in books) book.bookId: book,
      },
    );
  }
}
