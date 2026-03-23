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
import 'txt_toc_rule_settings_service.dart';

class LocalBookIndexService {
  LocalBookIndexService({
    LocalBookRepository? localBookRepository,
    List<LocalBookParser>? parsers,
    AppLogger? logger,
    ReaderSystemSettingsService? readerSystemSettingsService,
    TxtTocRuleSettingsService? txtTocRuleSettingsService,
  }) : _localBookRepository =
           localBookRepository ?? LocalBookRepositoryImpl(AppDatabase.instance),
       _parsers =
           parsers ??
           <LocalBookParser>[
             TxtLocalBookParser(
               ruleSettingsService:
                   txtTocRuleSettingsService ?? TxtTocRuleSettingsService(),
             ),
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
    LocalBook book = loadedBook;

    final originalBook = book;
    final refreshResult = await _refreshBookFile(book);
    book = refreshResult.book;
    var effectiveForce = force || refreshResult.shouldReindex;

    if (book.format == LocalBookFormat.txt) {
      final splitLongChapterEnabled =
          await _readerSystemSettingsService
              .loadLocalTxtSplitLongChapterEnabled();
      if (book.splitLongChapter != splitLongChapterEnabled) {
        book = book.copyWith(
          splitLongChapter: splitLongChapterEnabled,
          updatedAt: DateTime.now(),
        );
        effectiveForce = true;
      }
    }

    if (_requiresBookPersistence(originalBook, book) && !effectiveForce) {
      await _localBookRepository.upsertBook(book);
    }

    if (!effectiveForce &&
        book.indexStatus == LocalBookIndexStatus.ready &&
        book.chapterCount > 0) {
      final chapters = await _localBookRepository.getChapters(normalizedBookId);
      if (chapters.isNotEmpty) {
        return chapters;
      }
    }

    final parser = _parsers.firstWhere(
      (item) => item.supports(book.format),
      orElse: () => _UnsupportedLocalBookParser(book.format),
    );

    await _localBookRepository.updateBookIndexState(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.indexing,
      clearLastError: true,
    );

    try {
      final parsed = await parser.parse(book);
      if (parsed.chapters.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '解析完成但没有可用章节。',
        );
      }

      final now = DateTime.now();
      final storageStat = await _statOrNull(File(book.storagePath));
      final sourceStat = await _statOrNullFromPath(book.sourcePath);
      final parsedCharset = _nonEmptyOrNull(parsed.charset, fallback: null);
      final parsedRulePattern = _nonEmptyOrNull(
        parsed.txtTocRulePattern,
        fallback: null,
      );
      final parsedRuleName = _nonEmptyOrNull(
        parsed.txtTocRuleName,
        fallback: null,
      );
      final parsedCoverPath = _nonEmptyOrNull(
        parsed.coverPath,
        fallback: book.coverPath,
      );
      final updatedBook = book.copyWith(
        title: _nonEmptyOrFallback(parsed.title, fallback: book.title),
        author: _nonEmptyOrNull(parsed.author, fallback: book.author),
        coverPath: parsedCoverPath,
        clearCoverPath: parsedCoverPath == null,
        charset: parsedCharset,
        clearCharset: parsedCharset == null,
        indexStatus: LocalBookIndexStatus.ready,
        chapterCount: parsed.chapters.length,
        fileSize: storageStat?.size ?? book.fileSize,
        sourceFileSize: sourceStat?.size ?? book.sourceFileSize,
        sourceFileLastModifiedMs:
            sourceStat?.modified.millisecondsSinceEpoch ??
            book.sourceFileLastModifiedMs,
        storageFileLastModifiedMs:
            storageStat?.modified.millisecondsSinceEpoch ??
            book.storageFileLastModifiedMs,
        txtTocRuleName: parsedRuleName,
        clearTxtTocRuleName: parsedRulePattern == null,
        txtTocRulePattern: parsedRulePattern,
        clearTxtTocRulePattern: parsedRulePattern == null,
        updatedAt: now,
        clearLastError: true,
      );

      final chapters = parsed.chapters
          .asMap()
          .entries
          .map((entry) {
            final chapter = entry.value;
            return LocalChapter(
              id: '${normalizedBookId}_${entry.key}',
              bookId: normalizedBookId,
              chapterIndex: entry.key,
              title: _nonEmptyOrFallback(
                chapter.title,
                fallback: '第 ${entry.key + 1} 章',
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
        bookId: normalizedBookId,
        chapters: chapters,
      );
      await _localBookRepository.updateBookIndexState(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.ready,
        chapterCount: chapters.length,
        clearLastError: true,
      );

      return chapters;
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

  String _nonEmptyOrFallback(String? value, {required String fallback}) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String? _nonEmptyOrNull(String? value, {required String? fallback}) {
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

  Future<_LocalBookFileRefreshResult> _refreshBookFile(LocalBook book) async {
    var nextBook = book;
    var shouldReindex = false;
    final normalizedSourcePath = book.sourcePath?.trim() ?? '';
    if (normalizedSourcePath.isNotEmpty) {
      final sourceFile = File(normalizedSourcePath);
      if (await sourceFile.exists()) {
        final sourceStat = await sourceFile.stat();
        final sourceModifiedMs = sourceStat.modified.millisecondsSinceEpoch;
        final sourceChanged =
            book.sourceFileSize != sourceStat.size ||
            book.sourceFileLastModifiedMs != sourceModifiedMs;
        if (sourceChanged) {
          final targetFile = File(book.storagePath);
          if (await targetFile.exists()) {
            await targetFile.delete();
          }
          await sourceFile.copy(targetFile.path);
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
      return _LocalBookFileRefreshResult(book: nextBook, shouldReindex: true);
    }

    final storageModifiedMs = storageStat.modified.millisecondsSinceEpoch;
    final storageChanged =
        nextBook.fileSize != storageStat.size ||
        nextBook.storageFileLastModifiedMs != storageModifiedMs;
    if (storageChanged) {
      shouldReindex = true;
      nextBook = nextBook.copyWith(
        fileSize: storageStat.size,
        storageFileLastModifiedMs: storageModifiedMs,
        updatedAt: DateTime.now(),
      );
    }

    return _LocalBookFileRefreshResult(
      book: nextBook,
      shouldReindex: shouldReindex,
    );
  }

  bool _requiresBookPersistence(LocalBook previous, LocalBook next) {
    return previous.fileSize != next.fileSize ||
        previous.sourceFileSize != next.sourceFileSize ||
        previous.sourceFileLastModifiedMs != next.sourceFileLastModifiedMs ||
        previous.storageFileLastModifiedMs != next.storageFileLastModifiedMs ||
        previous.updatedAt != next.updatedAt ||
        previous.charset != next.charset;
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

class _LocalBookFileRefreshResult {
  const _LocalBookFileRefreshResult({
    required this.book,
    required this.shouldReindex,
  });

  final LocalBook book;
  final bool shouldReindex;
}

class _UnsupportedLocalBookParser implements LocalBookParser {
  const _UnsupportedLocalBookParser(this.format);

  final LocalBookFormat format;

  @override
  Future<LocalParsedBook> parse(LocalBook book) {
    throw AppException(
      code: ErrorCode.validation,
      stage: ErrorStage.content,
      briefMessage: '暂不支持 ${format.name} 格式的章节解析。',
    );
  }

  @override
  bool supports(LocalBookFormat format) {
    return this.format == format;
  }
}
