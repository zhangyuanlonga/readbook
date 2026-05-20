import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reader_toc_snapshot.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../book/application/book_detail_service.dart';
import '../../reader/application/reader_chapter_navigation.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/reader_preferences_service.dart';
import '../../reader/application/local/local_book_workflow_policy.dart';
import 'local_book_import_service.dart';

enum BookshelfReaderOpenAction { openReader, openDetail }

enum BookshelfReaderOpenKind {
  progress,
  tocSnapshot,
  detailCache,
  remotePrefetch,
  localFirstChapterMeta,
  readerFallback,
  openDetail,
}

class BookshelfReaderOpenPlan {
  const BookshelfReaderOpenPlan({
    required this.action,
    required this.kind,
    this.readerRoute,
    this.latestProgress,
    this.localBook,
    this.feedbackMessage,
    this.shouldStartBackgroundIndex = false,
    this.tocSnapshotHit = false,
    this.detailCacheHit = false,
    this.localFirstChapterMetaHit = false,
  });

  final BookshelfReaderOpenAction action;
  final BookshelfReaderOpenKind kind;
  final String? readerRoute;
  final ReadingProgress? latestProgress;
  final LocalBook? localBook;
  final String? feedbackMessage;
  final bool shouldStartBackgroundIndex;
  final bool tocSnapshotHit;
  final bool detailCacheHit;
  final bool localFirstChapterMetaHit;
}

class BookshelfReaderOpenService {
  BookshelfReaderOpenService({
    required ReaderPreferencesService readerPreferencesService,
    required ReaderEntryRouteResolver readerEntryRouteResolver,
    required LocalBookRepository localBookRepository,
    required BookDetailService bookDetailService,
    AppLogger? logger,
  }) : _readerPreferencesService = readerPreferencesService,
       _readerEntryRouteResolver = readerEntryRouteResolver,
       _localBookRepository = localBookRepository,
       _bookDetailService = bookDetailService,
       _logger = logger ?? AppLogger.instance;

  static const Duration _progressLoadTimeout = Duration(seconds: 2);
  static const Duration _snapshotLoadTimeout = Duration(milliseconds: 600);

  final ReaderPreferencesService _readerPreferencesService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;
  final LocalBookRepository _localBookRepository;
  final BookDetailService _bookDetailService;
  final AppLogger _logger;
  final ReaderChapterNavigation _chapterNavigation =
      const ReaderChapterNavigation();

  Future<BookshelfReaderOpenPlan> resolve({
    required BookshelfBook book,
    required int openRequestedAtMs,
    ReadingProgress? progressHint,
    LocalBook? localBookHint,
  }) async {
    final stopwatch = Stopwatch()..start();
    final normalizedBookId = book.bookId.trim();
    final normalizedSourceId = book.sourceId.trim();
    final normalizedDetailUrl = book.detailUrl.trim();
    var progressLoadMs = 0;
    var snapshotLoadMs = 0;
    var localMetaLoadMs = 0;
    var progressHit = false;
    var tocSnapshotHit = false;
    var detailCacheHit = false;
    var localFirstChapterMetaHit = false;
    BookshelfReaderOpenPlan? plan;

    try {
      final progressStopwatch = Stopwatch()..start();
      final loadedProgress = await _readerPreferencesService
          .loadProgress(normalizedBookId)
          .timeout(_progressLoadTimeout);
      progressLoadMs = progressStopwatch.elapsedMilliseconds;
      final latestProgress =
          _isProgressMatchingBook(loadedProgress, book) ? loadedProgress : null;
      final effectiveProgress = latestProgress ?? progressHint;
      if (effectiveProgress != null) {
        progressHit = true;
        plan = BookshelfReaderOpenPlan(
          action: BookshelfReaderOpenAction.openReader,
          kind: BookshelfReaderOpenKind.progress,
          latestProgress: latestProgress,
          readerRoute: _readerEntryRouteResolver.buildRouteFromProgress(
            effectiveProgress,
            openRequestedAtMs: openRequestedAtMs,
            openRouteKind: BookshelfReaderOpenKind.progress.name,
          ),
        );
        return plan;
      }

      final snapshotStopwatch = Stopwatch()..start();
      final snapshot = await _loadTocSnapshot(
        book,
      ).timeout(_snapshotLoadTimeout);
      snapshotLoadMs = snapshotStopwatch.elapsedMilliseconds;
      final snapshotChapter = _firstReadableChapter(snapshot?.chapters);
      if (snapshotChapter != null) {
        tocSnapshotHit = true;
        plan = BookshelfReaderOpenPlan(
          action: BookshelfReaderOpenAction.openReader,
          kind: BookshelfReaderOpenKind.tocSnapshot,
          readerRoute: _readerEntryRouteResolver.buildRouteFromChapter(
            bookId: normalizedBookId,
            sourceId: normalizedSourceId,
            detailUrl: normalizedDetailUrl,
            chapter: snapshotChapter,
            openRequestedAtMs: openRequestedAtMs,
            openRouteKind: BookshelfReaderOpenKind.tocSnapshot.name,
          ),
          tocSnapshotHit: true,
        );
        return plan;
      }

      if (normalizedSourceId == LocalBookImportService.localBookSourceId) {
        final localBook =
            localBookHint ??
            await _localBookRepository.getBookById(normalizedBookId);
        if (localBook == null) {
          plan = const BookshelfReaderOpenPlan(
            action: BookshelfReaderOpenAction.openDetail,
            kind: BookshelfReaderOpenKind.openDetail,
            feedbackMessage: '未找到本地图书记录，请检查导入是否完成。',
          );
          return plan;
        }

        if (localBook.format == LocalBookFormat.txt &&
            localBook.indexStatus != LocalBookIndexStatus.ready) {
          plan = BookshelfReaderOpenPlan(
            action: BookshelfReaderOpenAction.openReader,
            kind: BookshelfReaderOpenKind.readerFallback,
            readerRoute: _readerEntryRouteResolver
                .buildRouteFromBookshelfFallback(
                  book,
                  openRequestedAtMs: openRequestedAtMs,
                  openRouteKind: BookshelfReaderOpenKind.readerFallback.name,
                ),
            localBook: localBook,
            feedbackMessage: '正文已打开，目录会在后台继续解析。',
            shouldStartBackgroundIndex: true,
          );
          return plan;
        }

        if (localBook.indexStatus != LocalBookIndexStatus.ready) {
          plan = BookshelfReaderOpenPlan(
            action: BookshelfReaderOpenAction.openDetail,
            kind: BookshelfReaderOpenKind.openDetail,
            localBook: localBook,
            feedbackMessage: LocalBookWorkflowPolicy.nonReadyOpenMessage(
              localBook,
            ),
          );
          return plan;
        }

        final localMetaStopwatch = Stopwatch()..start();
        final firstChapter = await _localBookRepository.getChapterMetaByIndex(
          normalizedBookId,
          0,
        );
        localMetaLoadMs = localMetaStopwatch.elapsedMilliseconds;
        if (firstChapter != null) {
          localFirstChapterMetaHit = true;
          final chapter = Chapter(
            id: firstChapter.id,
            bookId: firstChapter.bookId,
            title: firstChapter.title,
            chapterUrl: 'local://chapter/${firstChapter.id}',
            index: firstChapter.chapterIndex,
          );
          plan = BookshelfReaderOpenPlan(
            action: BookshelfReaderOpenAction.openReader,
            kind: BookshelfReaderOpenKind.localFirstChapterMeta,
            localBook: localBook,
            readerRoute: _readerEntryRouteResolver.buildRouteFromChapter(
              bookId: chapter.bookId,
              sourceId: normalizedSourceId,
              detailUrl: normalizedDetailUrl,
              chapter: chapter,
              openRequestedAtMs: openRequestedAtMs,
              openRouteKind: BookshelfReaderOpenKind.localFirstChapterMeta.name,
            ),
            localFirstChapterMetaHit: true,
          );
          return plan;
        }

        plan = const BookshelfReaderOpenPlan(
          action: BookshelfReaderOpenAction.openDetail,
          kind: BookshelfReaderOpenKind.openDetail,
          feedbackMessage: '本地图书目录尚未建立完成，请先在详情页重建目录。',
        );
        return plan;
      }

      final cachedDetail = _bookDetailService.peekCached(
        sourceId: normalizedSourceId,
        detailUrl: normalizedDetailUrl,
      );
      final cachedChapter = _firstReadableChapter(cachedDetail?.chapters);
      if (cachedChapter != null) {
        detailCacheHit = true;
        plan = BookshelfReaderOpenPlan(
          action: BookshelfReaderOpenAction.openReader,
          kind: BookshelfReaderOpenKind.detailCache,
          readerRoute: _readerEntryRouteResolver.buildRouteFromChapter(
            bookId: normalizedBookId,
            sourceId: normalizedSourceId,
            detailUrl: normalizedDetailUrl,
            chapter: cachedChapter,
            openRequestedAtMs: openRequestedAtMs,
            openRouteKind: BookshelfReaderOpenKind.detailCache.name,
          ),
          detailCacheHit: true,
        );
        return plan;
      }

      plan = BookshelfReaderOpenPlan(
        action: BookshelfReaderOpenAction.openDetail,
        kind: BookshelfReaderOpenKind.openDetail,
        feedbackMessage: '当前书籍缺少可直接打开的目录信息，请先进入详情页加载目录。',
      );
      return plan;
    } finally {
      _logger.info(
        'Bookshelf reader open plan resolved',
        context: <String, Object?>{
          'chain': 'reader_open',
          'step': 'plan',
          'bookId': normalizedBookId,
          'sourceId': normalizedSourceId,
          'detailUrl': normalizedDetailUrl,
          'kind': plan?.kind.name,
          'action': plan?.action.name,
          'progressHit': progressHit,
          'tocSnapshotHit': tocSnapshotHit,
          'detailCacheHit': detailCacheHit,
          'localFirstChapterMetaHit': localFirstChapterMetaHit,
          'progressLoadMs': progressLoadMs,
          'tocSnapshotLoadMs': snapshotLoadMs,
          'localFirstChapterMetaLoadMs': localMetaLoadMs,
          'resolveDurationMs': stopwatch.elapsedMilliseconds,
        },
      );
    }
  }

  Future<ReaderTocSnapshot?> _loadTocSnapshot(BookshelfBook book) {
    final normalizedSourceId = book.sourceId.trim();
    final normalizedDetailUrl = book.detailUrl.trim();
    if (normalizedSourceId.isEmpty || normalizedDetailUrl.isEmpty) {
      return Future<ReaderTocSnapshot?>.value();
    }
    return _readerPreferencesService.loadTocSnapshot(
      sourceId: normalizedSourceId,
      detailUrl: normalizedDetailUrl,
    );
  }

  Chapter? _firstReadableChapter(List<Chapter>? chapters) {
    if (chapters == null || chapters.isEmpty) {
      return null;
    }
    final index = _chapterNavigation.findReadableChapterIndex(
      chapters,
      0,
      forward: true,
    );
    if (index == null || index < 0 || index >= chapters.length) {
      return null;
    }
    return chapters[index];
  }

  bool _isProgressMatchingBook(ReadingProgress? progress, BookshelfBook book) {
    if (progress == null) {
      return false;
    }
    return progress.sourceId.trim() == book.sourceId.trim() &&
        progress.detailUrl.trim() == book.detailUrl.trim();
  }
}
