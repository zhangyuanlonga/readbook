import '../entities/local_book.dart';
import '../entities/local_chapter.dart';

abstract class LocalBookRepository {
  Future<void> upsertBook(LocalBook book);

  Future<LocalBook?> getBookById(String bookId);

  Future<List<LocalBook>> getAllBooks();

  Future<void> updateBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  });

  Future<void> replaceChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  });

  Future<List<LocalChapter>> getChapters(String bookId);

  Future<List<LocalChapter>> getChapterMetas(String bookId);

  Future<LocalChapter?> getChapterById(String chapterId);

  Future<LocalChapter?> getChapterByIndex(String bookId, int chapterIndex);

  Future<void> deleteBook(String bookId);
}
