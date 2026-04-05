import '../entities/local_book.dart';
import '../entities/local_chapter.dart';
import '../entities/reader_document.dart';

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

  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  });

  Future<void> deleteBook(String bookId);
}
