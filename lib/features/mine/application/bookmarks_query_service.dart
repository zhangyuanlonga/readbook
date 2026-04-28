import '../../../domain/entities/bookmark.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../book/application/book_display_state.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../bookshelf/application/bookshelf_service.dart';

class BookmarksPageData {
  const BookmarksPageData({
    required this.bookmarks,
    required this.bookshelfIndex,
    required this.groups,
  });

  final List<Bookmark> bookmarks;
  final Map<String, BookshelfBook> bookshelfIndex;
  final List<BookmarkBookGroupData> groups;
}

class BookmarkBookGroupData {
  const BookmarkBookGroupData({
    required this.bookId,
    required this.book,
    required this.bookmarks,
    required this.latestTime,
    required this.displayTitle,
    required this.displayAuthor,
    this.displayState,
  });

  final String bookId;
  final BookshelfBook? book;
  final List<Bookmark> bookmarks;
  final DateTime latestTime;
  final String displayTitle;
  final String displayAuthor;
  final BookDisplayState? displayState;
}

class BookmarksQueryService {
  BookmarksQueryService({
    required BookmarkRepository bookmarkRepository,
    required BookshelfService bookshelfService,
    BookMetadataPresentationResolver resolver =
        const BookMetadataPresentationResolver(),
  }) : _bookmarkRepository = bookmarkRepository,
       _bookshelfService = bookshelfService,
       _resolver = resolver;

  final BookmarkRepository _bookmarkRepository;
  final BookshelfService _bookshelfService;
  final BookMetadataPresentationResolver _resolver;

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
      groups: buildGroups(
        bookmarks: bookmarks,
        bookshelfIndex: <String, BookshelfBook>{
          for (final book in books) book.bookId: book,
        },
      ),
    );
  }

  List<BookmarkBookGroupData> buildGroups({
    required List<Bookmark> bookmarks,
    required Map<String, BookshelfBook> bookshelfIndex,
  }) {
    if (bookmarks.isEmpty) {
      return const <BookmarkBookGroupData>[];
    }

    final grouped = <String, List<Bookmark>>{};
    for (final bookmark in bookmarks) {
      grouped.putIfAbsent(bookmark.bookId, () => <Bookmark>[]).add(bookmark);
    }

    final groups = <BookmarkBookGroupData>[];
    for (final entry in grouped.entries) {
      final items = entry.value.toList(growable: false);
      final latestTime = _latestTime(items);
      final book = bookshelfIndex[entry.key];
      final displayState =
          book == null ? null : _resolver.resolveBookshelfBook(book: book);
      groups.add(
        BookmarkBookGroupData(
          bookId: entry.key,
          book: book,
          bookmarks: items,
          latestTime: latestTime,
          displayState: displayState,
          displayTitle: _resolveTitle(
            book: book,
            displayState: displayState,
            fallbackBookmarks: items,
          ),
          displayAuthor: _resolveAuthor(
            book: book,
            displayState: displayState,
            fallbackBookmarks: items,
          ),
        ),
      );
    }

    groups.sort((a, b) => b.latestTime.compareTo(a.latestTime));
    return groups;
  }

  DateTime _latestTime(List<Bookmark> bookmarks) {
    var latest = bookmarks.first.updatedAt;
    for (final bookmark in bookmarks.skip(1)) {
      if (bookmark.updatedAt.isAfter(latest)) {
        latest = bookmark.updatedAt;
      }
    }
    return latest;
  }

  String _resolveTitle({
    required BookshelfBook? book,
    required BookDisplayState? displayState,
    required List<Bookmark> fallbackBookmarks,
  }) {
    final displayTitle = displayState?.displayTitle.trim() ?? '';
    if (displayTitle.isNotEmpty) {
      return displayTitle;
    }
    final rawTitle = (book?.title ?? '').trim();
    if (rawTitle.isNotEmpty) {
      return rawTitle;
    }
    final fallback = fallbackBookmarks.firstOrNull?.displaySnippet ?? '';
    return fallback.isEmpty ? '未知书籍' : '已移除书籍';
  }

  String _resolveAuthor({
    required BookshelfBook? book,
    required BookDisplayState? displayState,
    required List<Bookmark> fallbackBookmarks,
  }) {
    final displayAuthor = displayState?.displayAuthor?.trim() ?? '';
    if (displayAuthor.isNotEmpty) {
      return displayAuthor;
    }
    final rawAuthor = (book?.author ?? '').trim();
    if (rawAuthor.isNotEmpty) {
      return rawAuthor;
    }
    return book == null ? '书籍已从书架移除' : '作者未知';
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
