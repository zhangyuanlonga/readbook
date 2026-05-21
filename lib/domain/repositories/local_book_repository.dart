import '../entities/local_book.dart';
import '../entities/local_chapter.dart';
import '../entities/reader_document.dart';

abstract class LocalBookRepository {
  Future<void> upsertBook(LocalBook book);

  Future<LocalBook?> getBookById(String bookId);

  Future<LocalBook?> getBookBySourcePath(String sourcePath);

  Future<LocalBook?> findBookByImportFingerprint({
    required LocalBookFormat format,
    required String title,
    required int sourceFileSize,
  });

  Future<List<LocalBook>> getAllBooks();

  Stream<List<LocalBook>> watchAllBooks();

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

  /// Returns chapters with persisted body payloads when available.
  ///
  /// This is the heavy query path and should only be used by正文读取、
  /// 索引校验等确实需要内容本身的场景。
  Future<List<LocalChapter>> getChapters(String bookId);

  /// Returns directory metadata only.
  ///
  /// Callers must prefer this method in书架、目录、详情等非正文场景，
  /// 避免把 `content` / `document` 一并读出。
  Future<List<LocalChapter>> getChapterMetas(String bookId);

  Future<LocalChapter?> getChapterById(String chapterId);

  Future<LocalChapter?> getChapterMetaById(String chapterId);

  Future<LocalChapter?> getChapterByIndex(String bookId, int chapterIndex);

  /// Returns a single directory entry without loading正文内容。
  Future<LocalChapter?> getChapterMetaByIndex(String bookId, int chapterIndex);

  /// Returns正文内容，但不强制解码结构化 document。
  ///
  /// 用于阅读器首屏正文恢复、正文预览等场景，尽量避免把 `document`
  /// 一并解码到主线程。
  Future<LocalChapter?> getChapterContentById(String chapterId);

  /// Returns正文内容，但不强制解码结构化 document。
  Future<LocalChapter?> getChapterContentByIndex(
    String bookId,
    int chapterIndex,
  );

  Future<void> updateChapterContent({
    required String chapterId,
    required String content,
    List<String> imageUrls = const <String>[],
    ReaderDocument? document,
  });

  Future<void> deleteBook(String bookId);
}
