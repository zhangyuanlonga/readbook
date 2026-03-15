import '../repositories/bookmark_repository.dart';

class RemoveBookmark {
  const RemoveBookmark(this._repository);

  final BookmarkRepository _repository;

  Future<void> call(String bookmarkId) {
    return _repository.removeBookmark(bookmarkId);
  }
}
