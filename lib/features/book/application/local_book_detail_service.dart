import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/local_chapter.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/local_book_index_service.dart';

class LocalBookDetailResult {
  const LocalBookDetailResult({required this.book, required this.chapters});

  final LocalBook book;
  final List<LocalChapter> chapters;
}

enum LocalBookDetailLoadMode { directoryOnly, withContent }

class LocalBookDetailService {
  LocalBookDetailService({
    required LocalBookRepository localBookRepository,
    required LocalBookIndexService indexService,
  }) : _localBookRepository = localBookRepository,
       _indexService = indexService;

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;

  Future<LocalBookDetailResult> load({
    required String bookId,
    LocalBookDetailLoadMode mode = LocalBookDetailLoadMode.withContent,
    bool forceReindex = false,
    bool allowBackgroundIndex = false,
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

    final refreshedBook = await _indexService.refreshBookState(
      bookId: normalizedBookId,
    );
    if (refreshedBook != null) {
      book = refreshedBook;
    }

    final needsIndex =
        forceReindex ||
        book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0;

    if (needsIndex) {
      if (allowBackgroundIndex && !forceReindex) {
        unawaited(_indexService.ensureIndexed(bookId: normalizedBookId));
      } else {
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
    }

    final chapters =
        mode == LocalBookDetailLoadMode.withContent
            ? await _localBookRepository.getChapters(normalizedBookId)
            : await _localBookRepository.getChapterMetas(normalizedBookId);

    return LocalBookDetailResult(book: book, chapters: chapters);
  }
}
