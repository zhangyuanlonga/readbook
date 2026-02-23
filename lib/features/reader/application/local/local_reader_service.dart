import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'local_book_index_service.dart';

class LocalReaderLoadResult {
  const LocalReaderLoadResult({
    required this.book,
    required this.chapters,
    required this.currentChapter,
    required this.currentIndex,
  });

  final LocalBook book;
  final List<LocalChapter> chapters;
  final LocalChapter currentChapter;
  final int currentIndex;
}

class LocalReaderService {
  LocalReaderService({
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

  Future<LocalReaderLoadResult> load({
    required String bookId,
    required String chapterId,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'bookId 不能为空。',
      );
    }

    var book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍：$normalizedBookId',
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

    final chapters = await _localBookRepository.getChapters(normalizedBookId);
    if (chapters.isEmpty) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '章节列表为空，无法进入阅读。',
      );
    }

    final normalizedChapterId = chapterId.trim();
    final currentIndex =
        normalizedChapterId.isEmpty
            ? 0
            : chapters.indexWhere((item) => item.id == normalizedChapterId);
    final safeIndex = currentIndex < 0 ? 0 : currentIndex;

    return LocalReaderLoadResult(
      book: book,
      chapters: chapters,
      currentChapter: chapters[safeIndex],
      currentIndex: safeIndex,
    );
  }
}
