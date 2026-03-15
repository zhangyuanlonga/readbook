import '../../domain/entities/bookmark.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../datasources/local/app_database.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<void> addBookmark(Bookmark bookmark) {
    return _database.upsertBookmark(bookmark);
  }

  @override
  Future<List<Bookmark>> listBookmarks(String bookId) {
    return _database.getBookmarksByBookId(bookId);
  }

  @override
  Future<List<Bookmark>> listAllBookmarks() {
    return _database.getAllBookmarks();
  }

  @override
  Future<void> removeBookmark(String bookmarkId) {
    return _database.deleteBookmarkById(bookmarkId);
  }
}
