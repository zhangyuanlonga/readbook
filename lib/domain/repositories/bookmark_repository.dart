import '../entities/bookmark.dart';

abstract class BookmarkRepository {
  Future<void> addBookmark(Bookmark bookmark);

  Future<List<Bookmark>> listBookmarks(String bookId);

  Future<List<Bookmark>> listAllBookmarks();

  Future<void> removeBookmark(String bookmarkId);
}
