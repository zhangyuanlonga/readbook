import '../../domain/entities/local_book.dart';
import '../../domain/entities/local_chapter.dart';
import '../../domain/entities/reader_document.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../../data/datasources/local/app_database.dart';

class LocalBookRepositoryImpl implements LocalBookRepository {
  LocalBookRepositoryImpl(this._database);

  final AppDatabase _database;

  @override
  Future<void> deleteBook(String bookId) => _database.deleteLocalBook(bookId);

  @override
  Future<List<LocalBook>> getAllBooks() => _database.getAllLocalBooks();

  @override
  Stream<List<LocalBook>> watchAllBooks() => _database.watchAllLocalBooks();

  @override
  Future<LocalBook?> getBookById(String bookId) =>
      _database.getLocalBookById(bookId);

  @override
  Future<LocalBook?> getBookBySourcePath(String sourcePath) =>
      _database.getLocalBookBySourcePath(sourcePath);

  @override
  Future<LocalChapter?> getChapterById(String chapterId) =>
      _database.getLocalChapterById(chapterId);

  @override
  Future<List<LocalChapter>> getChapters(String bookId) =>
      _database.getLocalChapters(bookId);

  @override
  Future<List<LocalChapter>> getChapterMetas(String bookId) =>
      _database.getLocalChapterMetas(bookId);

  @override
  Future<LocalChapter?> getChapterByIndex(String bookId, int chapterIndex) =>
      _database.getLocalChapterByIndex(
        bookId: bookId,
        chapterIndex: chapterIndex,
      );

  @override
  Future<LocalChapter?> getChapterMetaByIndex(
    String bookId,
    int chapterIndex,
  ) => _database.getLocalChapterMetaByIndex(
    bookId: bookId,
    chapterIndex: chapterIndex,
  );

  @override
  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  }) => _database.updateLocalChapterContent(
    chapterId: chapterId,
    content: content,
    imageUrls: imageUrls,
    document: document,
  );

  @override
  Future<void> replaceChapters({
    required String bookId,
    required List<LocalChapter> chapters,
  }) {
    return _database.replaceLocalChapters(bookId: bookId, chapters: chapters);
  }

  @override
  Future<void> updateBookIndexState({
    required String bookId,
    required LocalBookIndexStatus status,
    int? chapterCount,
    String? lastError,
    bool clearLastError = false,
  }) {
    return _database.updateLocalBookIndexState(
      bookId: bookId,
      status: status,
      chapterCount: chapterCount,
      lastError: lastError,
      clearLastError: clearLastError,
    );
  }

  @override
  Future<void> upsertBook(LocalBook book) => _database.upsertLocalBook(book);
}
