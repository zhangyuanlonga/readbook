import 'dart:io';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../data/datasources/local/app_database.dart';
import '../../../../data/repositories/local_book_repository_impl.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import '../reader_system_settings_service.dart';
import 'epub_local_book_parser.dart';
import 'local_book_parser.dart';
import 'txt_local_book_parser.dart';

class LocalBookIndexService {
  LocalBookIndexService({
    LocalBookRepository? localBookRepository,
    List<LocalBookParser>? parsers,
    AppLogger? logger,
    ReaderSystemSettingsService? readerSystemSettingsService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _parsers =
           parsers ??
           <LocalBookParser>[
             const TxtLocalBookParser(),
             const EpubLocalBookParser(),
           ],
       _readerSystemSettingsService =
           readerSystemSettingsService ?? ReaderSystemSettingsService(),
       _logger = logger ?? AppLogger.instance;

  final LocalBookRepository _localBookRepository;
  final List<LocalBookParser> _parsers;
  final ReaderSystemSettingsService _readerSystemSettingsService;
  final AppLogger _logger;

  Future<List<LocalChapter>> ensureIndexed({
    required String bookId,
    bool force = false,
  }) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: 'bookId 不能为空。',
      );
    }

    final loadedBook = await _localBookRepository.getBookById(normalizedBookId);
    if (loadedBook == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '未找到本地书籍：$normalizedBookId',
      );
    }

    final refreshed = await _refreshBookBeforeIndex(loadedBook);
    final shouldForceIndex = force || refreshed.shouldReindex;
    final preparedBook = refreshed.book;

    if (_shouldReturnExistingChapters(
      book: preparedBook,
      force: shouldForceIndex,
    )) {
      final chapters = await _localBookRepository.getChapters(normalizedBookId);
      if (chapters.isNotEmpty) {
        return chapters;
      }
    }

    await _localBookRepository.updateBookIndexState(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.indexing,
      clearLastError: true,
    );

    final parser = _resolveParser(preparedBook.format);
    try {
      final parsedBook = await parser.parse(preparedBook);
      if (parsedBook.chapters.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '解析完成但没有可用章节。',
        );
      }

      final persisted = await _persistParsedBook(
        book: preparedBook,
        parsedBook: parsedBook,
      );
      return persisted;
    } on AppException catch (error) {
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.failed,
        chapterCount: 0,
        lastError: error.briefMessage,
      );
      rethrow;
    } catch (error) {
      final message = '本地书籍索引失败：$error';
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.failed,
        chapterCount: 0,
        lastError: message,
      );
      _logger.error(
        'Local book indexing failed',
        exception: AppException(
          code: ErrorCode.unknown,
          stage: ErrorStage.content,
          briefMessage: message,
          cause: error,
        ),
      );
      throw AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.content,
        briefMessage: message,
        cause: error,
      );
    }
  }

  Future<_PreparedBookResult> _refreshBookBeforeIndex(LocalBook book) async {
    var prepared = book;
    var shouldReindex = false;

    final refreshedFile = await _refreshStorageFromSourceIfChanged(prepared);
    prepared = refreshedFile.book;
    shouldReindex = shouldReindex || refreshedFile.shouldReindex;

    if (prepared.format == LocalBookFormat.txt) {
      final splitLongChapterEnabled =
          await _readerSystemSettingsService
              .loadLocalTxtSplitLongChapterEnabled();
      if (prepared.splitLongChapter != splitLongChapterEnabled) {
        prepared = prepared.copyWith(
          splitLongChapter: splitLongChapterEnabled,
          updatedAt: DateTime.now(),
        );
        shouldReindex = true;
      }
    }

    if (_isBookMetaChanged(previous: book, next: prepared) && !shouldReindex) {
      await _localBookRepository.upsertBook(prepared);
    }

    return _PreparedBookResult(book: prepared, shouldReindex: shouldReindex);
  }

  Future<_PreparedBookResult> _refreshStorageFromSourceIfChanged(
    LocalBook book,
  ) async {
    var nextBook = book;
    var shouldReindex = false;

    final normalizedSourcePath = (book.sourcePath ?? '').trim();
    if (normalizedSourcePath.isNotEmpty) {
      final sourceFile = File(normalizedSourcePath);
      if (await sourceFile.exists()) {
        final sourceStat = await sourceFile.stat();
        final sourceModifiedMs = sourceStat.modified.millisecondsSinceEpoch;
        final sourceChanged =
            book.sourceFileSize != sourceStat.size ||
            book.sourceFileLastModifiedMs != sourceModifiedMs;

        if (sourceChanged) {
          final storageFile = File(book.storagePath);
          if (await storageFile.exists()) {
            await storageFile.delete();
          }
          await sourceFile.copy(storageFile.path);
          shouldReindex = true;
        }

        final storageStat = await _statOrNull(File(book.storagePath));
        nextBook = nextBook.copyWith(
          fileSize: storageStat?.size ?? sourceStat.size,
          sourceFileSize: sourceStat.size,
          sourceFileLastModifiedMs: sourceModifiedMs,
          storageFileLastModifiedMs:
              storageStat?.modified.millisecondsSinceEpoch ??
              nextBook.storageFileLastModifiedMs,
          updatedAt: sourceChanged ? DateTime.now() : nextBook.updatedAt,
        );
      }
    }

    final storageStat = await _statOrNull(File(nextBook.storagePath));
    if (storageStat == null) {
      return _PreparedBookResult(book: nextBook, shouldReindex: true);
    }

    final storageModifiedMs = storageStat.modified.millisecondsSinceEpoch;
    final storageChanged =
        nextBook.fileSize != storageStat.size ||
        nextBook.storageFileLastModifiedMs != storageModifiedMs;
    if (!storageChanged) {
      return _PreparedBookResult(book: nextBook, shouldReindex: shouldReindex);
    }

    nextBook = nextBook.copyWith(
      fileSize: storageStat.size,
      storageFileLastModifiedMs: storageModifiedMs,
      updatedAt: DateTime.now(),
    );
    return _PreparedBookResult(book: nextBook, shouldReindex: true);
  }

  bool _shouldReturnExistingChapters({
    required LocalBook book,
    required bool force,
  }) {
    if (force) {
      return false;
    }
    return book.indexStatus == LocalBookIndexStatus.ready &&
        book.chapterCount > 0;
  }

  LocalBookParser _resolveParser(LocalBookFormat format) {
    return _parsers.firstWhere(
      (parser) => parser.supports(format),
      orElse: () => _UnsupportedLocalBookParser(format),
    );
  }

  Future<List<LocalChapter>> _persistParsedBook({
    required LocalBook book,
    required LocalParsedBook parsedBook,
  }) async {
    final now = DateTime.now();
    final storageStat = await _statOrNull(File(book.storagePath));
    final sourceStat = await _statOrNullFromPath(book.sourcePath);

    final parsedCharset = _normalizeOptional(
      parsedBook.charset,
      fallback: null,
    );
    final parsedCoverPath = _normalizeOptional(
      parsedBook.coverPath,
      fallback: book.coverPath,
    );

    final updatedBook = book.copyWith(
      title: _normalizeRequired(parsedBook.title, fallback: book.title),
      author: _normalizeOptional(parsedBook.author, fallback: book.author),
      coverPath: parsedCoverPath,
      clearCoverPath: parsedCoverPath == null,
      charset: parsedCharset,
      clearCharset: parsedCharset == null,
      indexStatus: LocalBookIndexStatus.ready,
      chapterCount: parsedBook.chapters.length,
      fileSize: storageStat?.size ?? book.fileSize,
      sourceFileSize: sourceStat?.size ?? book.sourceFileSize,
      sourceFileLastModifiedMs:
          sourceStat?.modified.millisecondsSinceEpoch ??
          book.sourceFileLastModifiedMs,
      storageFileLastModifiedMs:
          storageStat?.modified.millisecondsSinceEpoch ??
          book.storageFileLastModifiedMs,
      updatedAt: now,
      clearLastError: true,
    );

    final chapters = parsedBook.chapters
        .asMap()
        .entries
        .map((entry) {
          final chapter = entry.value;
          final index = entry.key;
          final chapterId = '${book.id}_$index';
          return LocalChapter(
            id: chapterId,
            bookId: book.id,
            chapterIndex: index,
            title: _normalizeRequired(
              chapter.title,
              fallback: '第 ${index + 1} 章',
            ),
            content:
                book.format == LocalBookFormat.txt &&
                        chapter.startOffset != null &&
                        chapter.endOffset != null &&
                        chapter.endOffset! > chapter.startOffset!
                    ? ''
                    : chapter.content,
            imageUrls: chapter.imageUrls,
            createdAt: now,
            updatedAt: now,
            startOffset: chapter.startOffset,
            endOffset: chapter.endOffset,
          );
        })
        .toList(growable: false);

    await _localBookRepository.upsertBook(updatedBook);
    await _localBookRepository.replaceChapters(
      bookId: book.id,
      chapters: chapters,
    );
    await _localBookRepository.updateBookIndexState(
      bookId: book.id,
      status: LocalBookIndexStatus.ready,
      chapterCount: chapters.length,
      clearLastError: true,
    );
    return chapters;
  }

  bool _isBookMetaChanged({
    required LocalBook previous,
    required LocalBook next,
  }) {
    return previous.fileSize != next.fileSize ||
        previous.sourceFileSize != next.sourceFileSize ||
        previous.sourceFileLastModifiedMs != next.sourceFileLastModifiedMs ||
        previous.storageFileLastModifiedMs != next.storageFileLastModifiedMs ||
        previous.updatedAt != next.updatedAt ||
        previous.charset != next.charset ||
        previous.splitLongChapter != next.splitLongChapter;
  }

  String _normalizeRequired(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String? _normalizeOptional(String? value, {required String? fallback}) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
    final fallbackNormalized = fallback?.trim();
    if (fallbackNormalized == null || fallbackNormalized.isEmpty) {
      return null;
    }
    return fallbackNormalized;
  }

  Future<FileStat?> _statOrNull(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      return file.stat();
    } catch (_) {
      return null;
    }
  }

  Future<FileStat?> _statOrNullFromPath(String? path) async {
    final normalized = path?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return _statOrNull(File(normalized));
  }
}

class _PreparedBookResult {
  const _PreparedBookResult({required this.book, required this.shouldReindex});

  final LocalBook book;
  final bool shouldReindex;
}

class _UnsupportedLocalBookParser implements LocalBookParser {
  const _UnsupportedLocalBookParser(this.format);

  final LocalBookFormat format;

  @override
  bool supports(LocalBookFormat format) => this.format == format;

  @override
  Future<LocalParsedBook> parse(LocalBook book) {
    throw AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.content,
      briefMessage: '暂不支持 ${format.name} 格式的章节解析。',
    );
  }
}
