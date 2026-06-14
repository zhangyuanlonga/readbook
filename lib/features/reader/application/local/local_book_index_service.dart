import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_codes.dart';
import '../../../../core/errors/error_stage.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/bookshelf_book.dart';
import '../../../../domain/entities/local_book.dart';
import '../../../../domain/entities/local_chapter.dart';
import '../../../../domain/repositories/local_book_repository.dart';
import '../../../bookshelf/application/bookshelf_service.dart';
import '../reading_record_service.dart';
import '../reader_system_settings_service.dart';
import 'epub_local_book_parser.dart';
import 'html_local_book_parser.dart';
import 'kindle_local_book_parser.dart';
import 'local_book_parser.dart';
import 'local_reader_identity.dart';
import 'local_book_storage_service.dart';
import 'local_book_workflow_policy.dart';
import 'markdown_local_book_parser.dart';
import 'pdf_local_book_parser.dart';
import 'txt_local_book_parser.dart';

class LocalBookIndexService {
  LocalBookIndexService({
    required LocalBookRepository localBookRepository,
    List<LocalBookParser>? parsers,
    AppLogger? logger,
    required ReaderSystemSettingsService readerSystemSettingsService,
    required LocalBookStorageService storageService,
    required BookshelfService bookshelfService,
    required ReadingRecordService readingRecordService,
    Duration indexTimeout = const Duration(minutes: 3),
  }) : _localBookRepository = localBookRepository,
       _parsers =
           parsers ??
           <LocalBookParser>[
             const TxtLocalBookParser(),
             const EpubLocalBookParser(),
             const MarkdownLocalBookParser(),
             const HtmlLocalBookParser(),
             const PdfLocalBookParser(),
             const KindleLocalBookParser(),
           ],
       _readerSystemSettingsService = readerSystemSettingsService,
       _storageService = storageService,
       _bookshelfService = bookshelfService,
       _readingRecordService = readingRecordService,
       _logger = logger ?? AppLogger.instance,
       _indexTimeout = indexTimeout;

  final LocalBookRepository _localBookRepository;
  final List<LocalBookParser> _parsers;
  final ReaderSystemSettingsService _readerSystemSettingsService;
  final LocalBookStorageService _storageService;
  final BookshelfService _bookshelfService;
  final ReadingRecordService _readingRecordService;
  final AppLogger _logger;
  final Duration _indexTimeout;
  static final Pool _indexPool = Pool(2);
  static final Map<String, Future<List<LocalChapter>>> _activeIndexTasks =
      <String, Future<List<LocalChapter>>>{};
  static final StreamController<LocalBookIndexEvent> _eventController =
      StreamController<LocalBookIndexEvent>.broadcast();

  static Stream<LocalBookIndexEvent> get watchEvents => _eventController.stream;

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

    final activeTask = _activeIndexTasks[normalizedBookId];
    if (activeTask != null) {
      return activeTask;
    }

    _emitIndexEvent(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.pending,
      chapterCount: 0,
      stage: LocalBookIndexEventStage.queued,
      message: '已加入后台解析队列',
    );

    final task = _indexPool.withResource(
      () => _ensureIndexedInternal(
        normalizedBookId: normalizedBookId,
        force: force,
      ),
    );
    _activeIndexTasks[normalizedBookId] = task;
    try {
      return await task;
    } finally {
      if (identical(_activeIndexTasks[normalizedBookId], task)) {
        _activeIndexTasks.remove(normalizedBookId);
      }
    }
  }

  Future<LocalBook?> refreshBookState({required String bookId}) async {
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return null;
    }
    final loadedBook = await _localBookRepository.getBookById(normalizedBookId);
    if (loadedBook == null) {
      return null;
    }
    final refreshed = await _refreshBookBeforeIndex(loadedBook);
    final nextBook =
        refreshed.shouldReindex &&
                refreshed.book.indexStatus == LocalBookIndexStatus.ready
            ? refreshed.book.copyWith(
              indexStatus: LocalBookIndexStatus.stale,
              updatedAt: DateTime.now(),
            )
            : refreshed.book;
    if (_isBookMetaChanged(previous: loadedBook, next: nextBook)) {
      await _localBookRepository.upsertBook(nextBook);
      _emitIndexEvent(
        bookId: normalizedBookId,
        status: nextBook.indexStatus,
        chapterCount: nextBook.chapterCount,
        stage: LocalBookIndexEventStage.preparing,
        current: nextBook.chapterCount > 0 ? nextBook.chapterCount : null,
        total: nextBook.chapterCount > 0 ? nextBook.chapterCount : null,
        message: LocalBookWorkflowPolicy.statusDescription(nextBook),
      );
    }
    return nextBook;
  }

  Future<List<LocalChapter>> _ensureIndexedInternal({
    required String normalizedBookId,
    required bool force,
  }) async {
    final startedAt = DateTime.now();
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
        _emitIndexEvent(
          bookId: normalizedBookId,
          status: LocalBookIndexStatus.ready,
          chapterCount: chapters.length,
          stage: LocalBookIndexEventStage.ready,
          current: chapters.length,
          total: chapters.length,
          message: '目录已存在，共 ${chapters.length} 章',
        );
        return chapters;
      }
    }

    await _localBookRepository.updateBookIndexState(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.indexing,
      clearLastError: true,
    );
    _emitIndexEvent(
      bookId: normalizedBookId,
      status: LocalBookIndexStatus.indexing,
      chapterCount: preparedBook.chapterCount,
      stage: LocalBookIndexEventStage.preparing,
      message: '正在准备${preparedBook.format.displayLabel}解析任务',
      estimatedSeconds: _estimateIndexSeconds(preparedBook),
    );

    final parser = _resolveParser(preparedBook.format);
    final timelineTask =
        developer.TimelineTask()..start(
          'reader.local.index',
          arguments: <String, Object?>{
            'bookId': normalizedBookId,
            'format': preparedBook.format.name,
            'force': force,
          },
        );
    try {
      final bookForParsing = await _hydrateReadableBook(preparedBook);
      final parserInput = LocalBookParserInput.fromBook(bookForParsing);
      _emitIndexEvent(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.indexing,
        chapterCount: preparedBook.chapterCount,
        stage: LocalBookIndexEventStage.parsing,
        current: 0,
        message: _indexingMessageForFormat(preparedBook.format),
        estimatedSeconds: _estimateIndexSeconds(preparedBook),
      );
      final parsedBook = await parseLocalBookInput(
        parser: parser,
        input: parserInput,
      ).timeout(_indexTimeout);
      if (parsedBook.chapters.isEmpty) {
        throw AppException(
          code: ErrorCode.ruleMatchEmpty,
          stage: ErrorStage.content,
          briefMessage: '解析完成但没有可用章节。',
        );
      }

      _emitIndexEvent(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.indexing,
        chapterCount: parsedBook.chapters.length,
        stage: LocalBookIndexEventStage.persisting,
        current: parsedBook.chapters.length,
        total: parsedBook.chapters.length,
        message: '正在写入目录，共 ${parsedBook.chapters.length} 章',
      );
      final persisted = await _persistParsedBook(
        book: preparedBook,
        parsedBook: parsedBook,
      );
      _logger.info(
        'Local book indexed',
        context: {
          'bookId': normalizedBookId,
          'format': preparedBook.format.name,
          'size': preparedBook.fileSize,
          'chapterCount': persisted.length,
          'force': force,
          'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
          'stage': LocalBookIndexEventStage.ready.name,
          'result': 'ready',
        },
      );
      _emitIndexEvent(
        bookId: normalizedBookId,
        status: LocalBookIndexStatus.ready,
        chapterCount: persisted.length,
        stage: LocalBookIndexEventStage.ready,
        current: persisted.length,
        total: persisted.length,
        message: '目录已建立，共 ${persisted.length} 章',
      );
      timelineTask.finish(
        arguments: <String, Object?>{
          'status': 'ready',
          'chapterCount': persisted.length,
          'costMs': DateTime.now().difference(startedAt).inMilliseconds,
          'format': preparedBook.format.name,
          'size': preparedBook.fileSize,
          'stage': LocalBookIndexEventStage.ready.name,
          'result': 'ready',
        },
      );
      return persisted;
    } on AppException catch (error, stackTrace) {
      await _markIndexFailed(
        bookId: normalizedBookId,
        book: preparedBook,
        force: force,
        startedAt: startedAt,
        timelineTask: timelineTask,
        failure: error.copyWith(cause: error.cause ?? error),
        cause: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error, stackTrace) {
      final failure = _classifyIndexFailure(error);
      await _markIndexFailed(
        bookId: normalizedBookId,
        book: preparedBook,
        force: force,
        startedAt: startedAt,
        timelineTask: timelineTask,
        failure: failure,
        cause: error,
        stackTrace: stackTrace,
      );
      Error.throwWithStackTrace(failure, stackTrace);
    }
  }

  Future<_PreparedBookResult> _refreshBookBeforeIndex(LocalBook book) async {
    var prepared = book;
    var shouldReindex = false;

    final refreshedFile = await _refreshStorageFromSourceIfChanged(prepared);
    prepared = refreshedFile.book;
    shouldReindex = shouldReindex || refreshedFile.shouldReindex;

    if (prepared.indexStatus == LocalBookIndexStatus.ready &&
        prepared.chapterCount > 0) {
      final chapters = await _localBookRepository.getChapters(prepared.id);
      final hasUnreadablePayload = chapters.any(
        (chapter) => !_hasReadableIndexedPayload(prepared, chapter),
      );
      if (hasUnreadablePayload) {
        prepared = prepared.copyWith(
          indexStatus: LocalBookIndexStatus.stale,
          updatedAt: DateTime.now(),
        );
        shouldReindex = true;
      }
    }

    if (prepared.format == LocalBookFormat.txt) {
      final splitLongChapterEnabled =
          await _readerSystemSettingsService
              .loadLocalTxtSplitLongChapterEnabled();
      if (prepared.splitLongChapter != splitLongChapterEnabled) {
        prepared = prepared.copyWith(
          indexStatus:
              prepared.indexStatus == LocalBookIndexStatus.ready
                  ? LocalBookIndexStatus.stale
                  : prepared.indexStatus,
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

  bool _hasReadableIndexedPayload(LocalBook book, LocalChapter chapter) {
    return chapter.hasReadablePayload ||
        (book.format == LocalBookFormat.txt && chapter.hasOffsetRange) ||
        (book.format == LocalBookFormat.epub &&
            (chapter.sourceRef?.trim().isNotEmpty ?? false));
  }

  Future<_PreparedBookResult> _refreshStorageFromSourceIfChanged(
    LocalBook book,
  ) async {
    final restored = await _storageService.restoreStorageFromSourceIfNeeded(
      book,
    );
    var nextBook = restored.book;
    var shouldReindex = restored.shouldReindex;
    if (shouldReindex && nextBook.indexStatus == LocalBookIndexStatus.ready) {
      nextBook = nextBook.copyWith(
        indexStatus: LocalBookIndexStatus.stale,
        updatedAt: DateTime.now(),
      );
    }

    final resolvedStorageFile = await _storageService.resolveStorageFile(
      nextBook,
    );
    final storageStat = await _statOrNull(resolvedStorageFile);
    if (storageStat == null) {
      final normalizedSourcePath = (book.sourcePath ?? '').trim();
      final sourceUnavailable =
          normalizedSourcePath.isEmpty ||
          !await File(normalizedSourcePath).exists();
      if (sourceUnavailable) {
        throw AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地书籍文件已失效，原文件也不可用，请重新导入。',
        );
      }
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

  Future<LocalBook> _hydrateReadableBook(LocalBook book) async {
    final resolvedStoragePath = await _storageService.resolveStoragePath(
      book.storagePath,
    );
    if (resolvedStoragePath == book.storagePath) {
      return book;
    }
    return book.copyWith(storagePath: resolvedStoragePath);
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

  String _indexingMessageForFormat(LocalBookFormat format) {
    return switch (format) {
      LocalBookFormat.epub => '正在解析 EPUB 结构、资源和目录',
      LocalBookFormat.html => '正在解析 HTML 结构和图片资源',
      LocalBookFormat.md => '正在解析 Markdown 内容',
      LocalBookFormat.pdf => '正在建立 PDF 页面索引',
      LocalBookFormat.mobi ||
      LocalBookFormat.azw ||
      LocalBookFormat.azw3 => '正在解析 Kindle 电子书结构',
      LocalBookFormat.txt => '正在识别文本编码并切分章节',
    };
  }

  int? _estimateIndexSeconds(LocalBook book) {
    if (book.fileSize <= 0) {
      return null;
    }
    final sizeMb = book.fileSize / (1024 * 1024);
    final baseSeconds = switch (book.format) {
      LocalBookFormat.txt => 2,
      LocalBookFormat.md || LocalBookFormat.html => 3,
      LocalBookFormat.epub => 5,
      LocalBookFormat.pdf => 4,
      LocalBookFormat.mobi || LocalBookFormat.azw || LocalBookFormat.azw3 => 8,
    };
    final estimate = (baseSeconds + sizeMb * 1.5).ceil();
    return estimate.clamp(2, 180).toInt();
  }

  AppException _classifyIndexFailure(Object error) {
    if (error is AppException) {
      return error;
    }
    if (error is TimeoutException) {
      return AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '本地书籍解析超时，请重试或重新导入。',
        cause: error,
      );
    }
    if (error is FileSystemException) {
      final osMessage = error.osError?.message.toLowerCase() ?? '';
      final rawMessage = error.message.toLowerCase();
      final path = error.path?.trim();
      final suffix = path == null || path.isEmpty ? '' : '：${p.basename(path)}';
      if (osMessage.contains('permission') ||
          rawMessage.contains('permission')) {
        return AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地书籍文件权限不足，请重新授权或重新导入$suffix。',
          cause: error,
        );
      }
      if (osMessage.contains('no such file') ||
          rawMessage.contains('no such file') ||
          rawMessage.contains('cannot open file')) {
        return AppException(
          code: ErrorCode.validation,
          stage: ErrorStage.content,
          briefMessage: '本地书籍文件不存在或已被移动，请重新导入$suffix。',
          cause: error,
        );
      }
      return AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '无法读取本地书籍文件，请检查文件状态后重试$suffix。',
        cause: error,
      );
    }
    if (error is FormatException) {
      return AppException(
        code: ErrorCode.ruleParse,
        stage: ErrorStage.content,
        briefMessage: '本地书籍格式异常，无法建立目录。',
        cause: error,
      );
    }
    if (error is UnsupportedError) {
      return AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '暂不支持该本地书籍格式的解析能力。',
        cause: error,
      );
    }
    return AppException(
      code: ErrorCode.unknown,
      stage: ErrorStage.content,
      briefMessage: '本地书籍索引失败：$error',
      cause: error,
    );
  }

  Future<void> _markIndexFailed({
    required String bookId,
    required LocalBook book,
    required bool force,
    required DateTime startedAt,
    required developer.TimelineTask timelineTask,
    required AppException failure,
    required Object cause,
    required StackTrace stackTrace,
  }) async {
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    await _localBookRepository.updateBookIndexState(
      bookId: bookId,
      status: LocalBookIndexStatus.failed,
      chapterCount: 0,
      lastError: failure.briefMessage,
    );
    _emitIndexEvent(
      bookId: bookId,
      status: LocalBookIndexStatus.failed,
      chapterCount: 0,
      stage: LocalBookIndexEventStage.failed,
      message: failure.briefMessage,
    );
    final context = <String, Object?>{
      'bookId': bookId,
      'format': book.format.name,
      'size': book.fileSize,
      'durationMs': durationMs,
      'stage': LocalBookIndexEventStage.failed.name,
      'result': 'failed',
      'force': force,
      'error': failure.briefMessage,
      'errorCode': failure.code.name,
    };
    _logger.warn('Local book index failed', context: context);
    _logger.error(
      'Local book indexing failed',
      exception: failure.copyWith(cause: cause, stackTrace: stackTrace),
      context: context,
    );
    timelineTask.finish(
      arguments: <String, Object?>{
        'status': 'failed',
        'error': failure.briefMessage,
        'costMs': durationMs,
        'format': book.format.name,
        'size': book.fileSize,
        'stage': LocalBookIndexEventStage.failed.name,
        'result': 'failed',
      },
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
    final parsedDescription = _normalizeOptional(
      parsedBook.description,
      fallback: book.description,
    );
    final parsedCoverPath = _normalizeOptional(
      parsedBook.coverPath,
      fallback: book.coverPath,
    );

    final updatedBook = book.copyWith(
      title: _normalizeRequired(parsedBook.title, fallback: book.title),
      author: _normalizeOptional(parsedBook.author, fallback: book.author),
      description: parsedDescription,
      clearDescription: parsedDescription == null,
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
            content: chapter.content,
            imageUrls: chapter.imageUrls,
            sourceRef: chapter.sourceRef,
            createdAt: now,
            updatedAt: now,
            startOffset: chapter.startOffset,
            endOffset: chapter.endOffset,
            document: chapter.document,
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
    await _syncBookPresentation(previous: book, next: updatedBook);
    return chapters;
  }

  Future<void> _syncBookPresentation({
    required LocalBook previous,
    required LocalBook next,
  }) async {
    final previousTitle = previous.title.trim();
    final nextTitle = next.title.trim();
    final previousAuthor = (previous.author ?? '').trim();
    final nextAuthor = (next.author ?? '').trim();
    final previousCoverPath = (previous.coverPath ?? '').trim();
    final nextCoverPath = (next.coverPath ?? '').trim();
    final changed =
        previousTitle != nextTitle ||
        previousAuthor != nextAuthor ||
        previousCoverPath != nextCoverPath;
    if (!changed) {
      return;
    }

    final nextCoverUrl =
        nextCoverPath.isEmpty ? null : Uri.file(nextCoverPath).toString();

    await _syncBookshelfBookCover(nextBook: next, nextCoverUrl: nextCoverUrl);
    await _readingRecordService.syncBookPresentation(
      bookId: next.id,
      bookTitle: next.title,
      bookAuthor: next.author,
      coverUrl: nextCoverUrl,
    );
  }

  Future<void> _syncBookshelfBookCover({
    required LocalBook nextBook,
    required String? nextCoverUrl,
  }) async {
    final allBooks = await _bookshelfService.getAll();
    BookshelfBook? matched;
    final expectedDetailUrl = LocalReaderIdentity.buildBookDetailUrl(
      nextBook.id,
    );
    for (final book in allBooks) {
      if (book.bookId == nextBook.id &&
          book.sourceId == LocalReaderIdentity.localSourceId &&
          book.detailUrl.trim() == expectedDetailUrl) {
        matched = book;
        break;
      }
    }
    if (matched == null) {
      return;
    }

    final currentCoverUrl = matched.coverUrl?.trim();
    final normalizedNextCoverUrl = nextCoverUrl?.trim();
    if (currentCoverUrl == normalizedNextCoverUrl) {
      return;
    }

    await _bookshelfService.upsert(
      matched.copyWith(
        title: nextBook.title,
        author: nextBook.author,
        coverUrl: normalizedNextCoverUrl,
        clearCoverUrl:
            normalizedNextCoverUrl == null || normalizedNextCoverUrl.isEmpty,
      ),
    );
  }

  void _emitIndexEvent({
    required String bookId,
    required LocalBookIndexStatus status,
    required int chapterCount,
    required LocalBookIndexEventStage stage,
    int? current,
    int? total,
    String? message,
    int? estimatedSeconds,
  }) {
    if (_eventController.isClosed) {
      return;
    }
    _eventController.add(
      LocalBookIndexEvent(
        bookId: bookId,
        status: status,
        chapterCount: chapterCount,
        stage: stage,
        current: current,
        total: total,
        message: message,
        estimatedSeconds: estimatedSeconds,
      ),
    );
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

enum LocalBookIndexEventStage {
  queued,
  preparing,
  parsing,
  persisting,
  ready,
  failed,
}

class LocalBookIndexEvent {
  const LocalBookIndexEvent({
    required this.bookId,
    required this.status,
    required this.chapterCount,
    required this.stage,
    this.current,
    this.total,
    this.message,
    this.estimatedSeconds,
  });

  final String bookId;
  final LocalBookIndexStatus status;
  final int chapterCount;
  final LocalBookIndexEventStage stage;
  final int? current;
  final int? total;
  final String? message;
  final int? estimatedSeconds;
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
