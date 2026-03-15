import '../entities/bookmark.dart';
import '../repositories/bookmark_repository.dart';

class AddBookmark {
  const AddBookmark(this._repository);

  final BookmarkRepository _repository;

  Future<void> call(Bookmark bookmark) {
    return _repository.addBookmark(bookmark);
  }
}
