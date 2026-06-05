import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../reader/application/local/local_reader_entry_guard_service.dart';
import '../../reader/application/local/local_reader_identity.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/reader_preferences_service.dart';

class BookshelfPageRouteService {
  const BookshelfPageRouteService({
    required ReaderPreferencesService readerPreferencesService,
    required ReaderEntryRouteResolver readerEntryRouteResolver,
    LocalReaderEntryGuardService? localReaderEntryGuardService,
  }) : _readerPreferencesService = readerPreferencesService,
       _readerEntryRouteResolver = readerEntryRouteResolver,
       _localReaderEntryGuardService = localReaderEntryGuardService;

  final ReaderPreferencesService _readerPreferencesService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;
  final LocalReaderEntryGuardService? _localReaderEntryGuardService;

  Future<BookshelfPageRouteResolution> resolveLatestReadingRecordRoute(
    ReadingRecord record,
  ) async {
    final progress = await _readerPreferencesService.loadProgress(
      record.bookId,
    );
    final hasMatchedProgress =
        progress != null &&
        progress.sourceId.trim() == record.sourceId.trim() &&
        progress.detailUrl.trim() == record.detailUrl.trim();
    if (hasMatchedProgress) {
      final localGuard = await _guardLocalProgress(progress);
      if (localGuard != null) {
        return localGuard;
      }
      return BookshelfPageRouteResolution.open(resolveProgressRoute(progress));
    }

    final chapterId =
        record.lastChapterId?.trim().isNotEmpty == true
            ? record.lastChapterId!.trim()
            : '';
    final chapterUrl =
        record.lastChapterUrl?.trim().isNotEmpty == true
            ? record.lastChapterUrl!.trim()
            : '';
    final chapterTitle =
        record.lastChapterTitle?.trim().isNotEmpty == true
            ? record.lastChapterTitle!.trim()
            : record.bookTitle.trim();

    if (chapterId.isNotEmpty && chapterUrl.isNotEmpty) {
      final localGuard = await _guardLocalRecord(record);
      if (localGuard != null) {
        return localGuard;
      }
      return BookshelfPageRouteResolution.open(
        _readerEntryRouteResolver.buildChapterRoute(
          bookId: record.bookId,
          chapterId: chapterId,
          chapterUrl: chapterUrl,
          chapterTitle: chapterTitle,
          sourceId: record.sourceId,
          detailUrl: record.detailUrl,
          chapterIndex: record.lastChapterIndex,
        ),
      );
    }

    return BookshelfPageRouteResolution.open(
      buildBookDetailRoute(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title: record.bookTitle,
      ),
    );
  }

  String resolveReaderFallbackRoute(BookshelfBook book) {
    return _readerEntryRouteResolver.buildRouteFromBookshelfFallback(book);
  }

  String resolveProgressRoute(ReadingProgress progress) {
    return _readerEntryRouteResolver.buildRouteFromProgress(progress);
  }

  String resolveBookDetailRoute(
    BookshelfBook book, {
    String? heroTag,
    bool initialEditMode = false,
  }) {
    final normalizedSourceId = book.sourceId.trim();
    final normalizedBookId = book.bookId.trim();
    final titleHeroTag =
        'book_title_${normalizedSourceId}_${normalizedBookId}_${book.detailUrl.hashCode}';
    final metaHeroTag =
        'book_meta_${normalizedSourceId}_${normalizedBookId}_${book.detailUrl.hashCode}';
    return buildBookDetailRoute(
      bookId: book.bookId,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      heroTag: heroTag,
      titleHeroTag: titleHeroTag,
      metaHeroTag: metaHeroTag,
      initialEditMode: initialEditMode,
    );
  }

  Future<BookshelfPageRouteResolution?> _guardLocalProgress(
    ReadingProgress progress,
  ) async {
    final guardService = _localReaderEntryGuardService;
    if (guardService == null ||
        !LocalReaderIdentity.isLocalSourceId(progress.sourceId)) {
      return null;
    }
    return _toResolution(await guardService.guardProgress(progress));
  }

  Future<BookshelfPageRouteResolution?> _guardLocalRecord(
    ReadingRecord record,
  ) async {
    final guardService = _localReaderEntryGuardService;
    if (guardService == null ||
        !LocalReaderIdentity.isLocalSourceId(record.sourceId)) {
      return null;
    }
    return _toResolution(await guardService.guardRecord(record));
  }

  BookshelfPageRouteResolution _toResolution(
    LocalReaderEntryGuardResult result,
  ) {
    return switch (result.action) {
      LocalReaderEntryGuardAction.openReader ||
      LocalReaderEntryGuardAction
          .openDetail => BookshelfPageRouteResolution.open(
        result.route!,
        message: result.message,
      ),
      LocalReaderEntryGuardAction.unavailable =>
        BookshelfPageRouteResolution.unavailable(result.message ?? '本地图书暂不可用。'),
    };
  }
}

class BookshelfPageRouteResolution {
  const BookshelfPageRouteResolution._({
    required this.route,
    required this.unavailable,
    this.message,
  });

  const BookshelfPageRouteResolution.open(String route, {String? message})
    : this._(route: route, unavailable: false, message: message);

  const BookshelfPageRouteResolution.unavailable(String message)
    : this._(route: null, unavailable: true, message: message);

  final String? route;
  final bool unavailable;
  final String? message;
}
