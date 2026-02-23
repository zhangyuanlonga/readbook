import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/local_book_index_service.dart';

class LocalBookDetailResult {
  const LocalBookDetailResult({required this.book, required this.chapters});

  final LocalBook book;
  final List<LocalChapter> chapters;
}

class LocalBookDetailService {
  LocalBookDetailService({
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

  Future<LocalBookDetailResult> load({
    required String bookId,
    bool forceReindex = false,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: 'bookId 不能为空。',
      );
    }

    var book = await _localBookRepository.getBookById(normalizedBookId);
    if (book == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.detail,
        briefMessage: '未找到本地书籍：$normalizedBookId',
      );
    }

    final needsIndex =
        forceReindex ||
        book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0;

    if (needsIndex) {
      await _indexService.ensureIndexed(
        bookId: normalizedBookId,
        force: forceReindex,
      );
      final refreshed = await _localBookRepository.getBookById(
        normalizedBookId,
      );
      if (refreshed != null) {
        book = refreshed;
      }
    }

    final chapters = await _localBookRepository.getChapters(normalizedBookId);

    return LocalBookDetailResult(book: book, chapters: chapters);
  }
}
