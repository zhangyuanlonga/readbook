import 'dart:async';
import 'dart:io';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import 'local_book_index_service.dart';
import 'local_book_storage_service.dart';
import 'local_text_encoding_detector.dart';

class LocalChapterContentService {
  LocalChapterContentService({
    LocalBookRepository? localBookRepository,
    LocalBookIndexService? indexService,
    LocalBookStorageService? storageService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _indexService =
           indexService ??
           LocalBookIndexService(
             localBookRepository:
                 localBookRepository ??
                 LocalBookRepositoryImpl(AppDatabase.instance),
           ),
       _storageService = storageService ?? LocalBookStorageService();

  final LocalBookRepository _localBookRepository;
  final LocalBookIndexService _indexService;
  final LocalBookStorageService _storageService;
  final LocalTextEncodingDetector _textEncodingDetector =
      const LocalTextEncodingDetector();

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

    final originalBook = await _localBookRepository.getBookById(
      normalizedBookId,
    );
    if (originalBook == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍，请确认文件是否已移除。',
      );
    }

    final refreshedBook = await _indexService.refreshBookState(
      bookId: normalizedBookId,
    );
    final book = refreshedBook ?? originalBook;
    final normalizedChapterId = (chapterId ?? '').trim().toLowerCase();
    if (normalizedChapterId == 'bootstrap') {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'TXT 预览已迁移到独立预览服务，请通过预览入口打开。',
      );
    }
    final chapter = await _resolveChapter(
      book: book,
      chapterId: chapterId,
      chapterIndex: chapterIndex,
    );
    if (_needsReindex(book)) {
      if (chapter != null &&
          _canUseLegacyTxtOffsetFallback(
            originalBook: originalBook,
            refreshedBook: refreshedBook,
            chapter: chapter,
          )) {
        unawaited(_indexService.ensureIndexed(bookId: normalizedBookId));
        final readableBook = await _hydrateReadableBook(book);
        final hydratedContent = await _loadTxtChapterContentByOffsets(
          chapter: chapter,
          book: readableBook,
        );
        return chapter.copyWith(content: hydratedContent);
      }

      _ensureBookReadyForReading(book);
    }

    if (chapter == null) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '未找到本地章节内容，请重新索引后重试。',
      );
    }

    if (_canUseStoredChapterContent(chapter: chapter)) {
      return chapter;
    }

    throw AppException(
      code: ErrorCode.ruleMatchEmpty,
      stage: ErrorStage.content,
      briefMessage: '本地章节正文缺失，请重建目录或重新导入后重试。',
    );
  }

  bool _needsReindex(LocalBook book) {
    return book.indexStatus != LocalBookIndexStatus.ready ||
        book.chapterCount <= 0;
  }

  void _ensureBookReadyForReading(LocalBook book) {
    if (!_needsReindex(book)) {
      return;
    }

    switch (book.indexStatus) {
      case LocalBookIndexStatus.pending:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书目录尚未建立完成，请稍后重试。',
        );
      case LocalBookIndexStatus.indexing:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书正在建立目录，请稍后重试。',
        );
      case LocalBookIndexStatus.stale:
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地图书目录已过期，请先重新索引。',
        );
      case LocalBookIndexStatus.failed:
        final lastError = book.lastError?.trim();
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage:
              (lastError != null && lastError.isNotEmpty)
                  ? '本地图书索引失败：$lastError'
                  : '本地图书索引失败，请先重新索引。',
        );
      case LocalBookIndexStatus.ready:
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '未解析到可读章节，请重新索引后重试。',
        );
    }
  }

  Future<LocalChapter?> _resolveChapter({
    required LocalBook book,
    required String? chapterId,
    required int? chapterIndex,
  }) async {
    final normalizedChapterId = (chapterId ?? '').trim();
    if (normalizedChapterId.isNotEmpty) {
      final byId = await _localBookRepository.getChapterById(
        normalizedChapterId,
      );
      if (byId != null) {
        if (byId.bookId.trim() != book.id.trim()) {
          throw AppException(
            code: ErrorCode.validation,
            stage: ErrorStage.content,
            briefMessage: '章节与书籍不匹配，请重新进入阅读页。',
          );
        }
        return byId;
      }
    }

    if (chapterIndex != null) {
      final safeIndex = _safeChapterIndex(
        chapterIndex,
        chapterCount: book.chapterCount,
      );
      final byIndex = await _localBookRepository.getChapterByIndex(
        book.id,
        safeIndex,
      );
      if (byIndex != null) {
        return byIndex;
      }
    }

    final chapters = await _localBookRepository.getChapters(book.id);
    if (chapters.isEmpty) {
      return null;
    }
    if (chapterIndex == null) {
      return chapters.first;
    }
    final fallbackIndex = _safeChapterIndex(
      chapterIndex,
      chapterCount: chapters.length,
    );
    return chapters[fallbackIndex];
  }

  int _safeChapterIndex(int chapterIndex, {required int chapterCount}) {
    if (chapterCount <= 0) {
      return chapterIndex < 0 ? 0 : chapterIndex;
    }
    return chapterIndex.clamp(0, chapterCount - 1).toInt();
  }

  bool _canUseStoredChapterContent({required LocalChapter chapter}) {
    return chapter.hasReadablePayload;
  }

  bool _canUseLegacyTxtOffsetFallback({
    required LocalBook originalBook,
    required LocalBook? refreshedBook,
    required LocalChapter chapter,
  }) {
    if (originalBook.format != LocalBookFormat.txt ||
        originalBook.indexStatus != LocalBookIndexStatus.ready ||
        !chapter.hasOffsetRange ||
        chapter.hasReadablePayload) {
      return false;
    }
    final nextBook = refreshedBook;
    if (nextBook == null ||
        nextBook.indexStatus != LocalBookIndexStatus.stale) {
      return false;
    }
    final metadataChanged =
        originalBook.sourceFileSize != nextBook.sourceFileSize ||
        originalBook.sourceFileLastModifiedMs !=
            nextBook.sourceFileLastModifiedMs ||
        originalBook.storageFileLastModifiedMs !=
            nextBook.storageFileLastModifiedMs ||
        originalBook.fileSize != nextBook.fileSize ||
        originalBook.splitLongChapter != nextBook.splitLongChapter;
    return !metadataChanged;
  }

  Future<LocalBook> _hydrateReadableBook(LocalBook book) async {
    final resolvedStoragePath = await _storageService.resolveStoragePath(
      book.storagePath,
    );
    if (resolvedStoragePath == book.storagePath) {
      return book;
    }
    return book.copyWith(storagePath: resolvedStoragePath);
  }

  Future<String> _loadTxtChapterContentByOffsets({
    required LocalChapter chapter,
    required LocalBook book,
  }) async {
    final startOffset = chapter.startOffset;
    final endOffset = chapter.endOffset;
    if (startOffset == null || endOffset == null || endOffset <= startOffset) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节缺少有效偏移信息，请重新索引后重试。',
      );
    }

    final file = File(book.storagePath);
    if (!await file.exists()) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地文件不存在：${book.storagePath}',
      );
    }

    final fileLength = await file.length();
    var safeStart = startOffset.clamp(0, fileLength).toInt();
    var safeEnd = endOffset.clamp(0, fileLength).toInt();
    final normalizedCharset = LocalTextEncodingDetector.normalizeCharsetName(
      book.charset,
    );
    if (normalizedCharset == 'utf-16' ||
        normalizedCharset == 'utf-16le' ||
        normalizedCharset == 'utf-16be') {
      if (safeStart.isOdd) {
        safeStart -= 1;
      }
      if (safeEnd.isOdd) {
        safeEnd -= 1;
      }
    }
    if (safeEnd <= safeStart) {
      throw AppException(
        code: ErrorCode.ruleMatchEmpty,
        stage: ErrorStage.content,
        briefMessage: '本地章节内容为空，请重新索引后重试。',
      );
    }

    final handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(safeStart);
      final bytes = await handle.read(safeEnd - safeStart);
      final decoded = _decodeTxtBytesWithBookCharset(bytes: bytes, book: book);
      final text = decoded?.text.trim() ?? '';
      if (text.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '本地章节内容为空，请重新索引后重试。',
        );
      }
      return text;
    } finally {
      await handle.close();
    }
  }

  LocalTextDecodeResult? _decodeTxtBytesWithBookCharset({
    required List<int> bytes,
    required LocalBook book,
  }) {
    final normalizedCharset = LocalTextEncodingDetector.normalizeCharsetName(
      book.charset,
    );
    if (normalizedCharset != null) {
      return _textEncodingDetector.decodeWithFrozenCharset(
        bytes,
        charsetName: normalizedCharset,
      );
    }
    return _textEncodingDetector.decodeDirectBytes(
      bytes,
      preferredCharset: book.charset,
      hintedCharset: book.charset,
    );
  }
}
