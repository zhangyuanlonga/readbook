import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'local_book_index_service.dart';

class LocalChapterContentService {
  LocalChapterContentService({
    LocalBookRepository? localBookRepository,
    LocalBookIndexService? indexService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _indexService =
           indexService ??
           LocalBookIndexService(
             localBookRepository:
                 localBookRepository ??
                 LocalBookRepositoryImpl(AppDatabase.instance),
           );

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;

  Future<LocalChapter> load({
    required String bookId,
    String? chapterId,
    int? chapterIndex,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地书籍信息缺失。',
      );
    }

    var book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍，请确认文件是否已移除。',
      );
    }

    if (book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0) {
      await _indexService.ensureIndexed(bookId: normalizedBookId);
      final refreshed = await _localBookRepository.getBookById(
        normalizedBookId,
      );
      if (refreshed != null) {
        book = refreshed;
      }
    }

    LocalChapter? chapter;
    final normalizedChapterId = (chapterId ?? '').trim();
    if (normalizedChapterId.isNotEmpty) {
      chapter = await _localBookRepository.getChapterById(normalizedChapterId);
    }

    if (chapter == null && chapterIndex != null) {
      final rawIndex = chapterIndex < 0 ? 0 : chapterIndex;
      var safeIndex = rawIndex;
      if (book.chapterCount > 0) {
        safeIndex = rawIndex.clamp(0, book.chapterCount - 1).toInt();
      }

      chapter = await _localBookRepository.getChapterByIndex(
        normalizedBookId,
        safeIndex,
      );

      if (chapter == null && safeIndex != rawIndex) {
        chapter = await _localBookRepository.getChapterByIndex(
          normalizedBookId,
          rawIndex,
        );
      }

      if (chapter == null) {
        final chapters =
            await _localBookRepository.getChapters(normalizedBookId);
        if (chapters.isNotEmpty) {
          final fallbackIndex =
              rawIndex.clamp(0, chapters.length - 1).toInt();
          chapter = chapters[fallbackIndex];
        }
      }
    }

    if (chapter == null) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未找到本地章节内容，请重新索引后重试。',
      );
    }

    return chapter;
  }
}
