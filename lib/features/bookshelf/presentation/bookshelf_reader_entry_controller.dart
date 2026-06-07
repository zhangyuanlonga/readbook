import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/bookshelf_page_route_service.dart';
import '../application/bookshelf_reader_open_service.dart';

class BookshelfReaderEntryController {
  const BookshelfReaderEntryController({
    required BookshelfReaderOpenService readerOpenService,
    required BookshelfPageRouteService pageRouteService,
    required String localBookSourceId,
  }) : _readerOpenService = readerOpenService,
       _pageRouteService = pageRouteService,
       _localBookSourceId = localBookSourceId;

  final BookshelfReaderOpenService _readerOpenService;
  final BookshelfPageRouteService _pageRouteService;
  final String _localBookSourceId;

  Future<BookshelfReaderOpenPlan> resolveOpenPlan({
    required BookshelfBook book,
    required int openRequestedAtMs,
    required ReadingProgress? progressHint,
    required LocalBook? localBookHint,
    required Duration onlinePlanTimeout,
    required void Function() onOnlinePlanTimeout,
  }) {
    final resolveFuture = _readerOpenService.resolve(
      book: book,
      openRequestedAtMs: openRequestedAtMs,
      progressHint: progressHint,
      localBookHint: localBookHint,
    );
    if (book.sourceId == _localBookSourceId) {
      return resolveFuture;
    }
    return resolveFuture.timeout(
      onlinePlanTimeout,
      onTimeout: () {
        onOnlinePlanTimeout();
        return fallbackPlan(book);
      },
    );
  }

  BookshelfReaderOpenPlan fallbackPlan(BookshelfBook book) {
    return BookshelfReaderOpenPlan(
      action: BookshelfReaderOpenAction.openReader,
      kind: BookshelfReaderOpenKind.readerFallback,
      readerRoute: _pageRouteService.resolveReaderFallbackRoute(book),
    );
  }

  ReadingProgress? matchingProgressAfterExit({
    required ReadingProgress? latestProgress,
    required BookshelfBook book,
  }) {
    if (latestProgress == null) {
      return null;
    }
    final sourceMatches =
        latestProgress.sourceId.trim() == book.sourceId.trim();
    final detailUrlMatches =
        latestProgress.detailUrl.trim() == book.detailUrl.trim();
    return sourceMatches && detailUrlMatches ? latestProgress : null;
  }
}
