import '../entities/bookmark.dart';
import '../repositories/bookmark_repository.dart';

class ListBookmarks {
  const ListBookmarks(this._repository);

  final BookmarkRepository _repository;

  Future<List<Bookmark>> call({required String bookId}) {
    return _repository.listBookmarks(bookId);
  }
}
