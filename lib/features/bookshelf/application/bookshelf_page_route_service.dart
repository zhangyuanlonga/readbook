import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/entities/reading_record.dart';
import '../../book/presentation/book_detail_route.dart';
import '../../reader/application/reader_entry_route_resolver.dart';
import '../../reader/application/reader_preferences_service.dart';

class BookshelfPageRouteService {
  const BookshelfPageRouteService({
    required ReaderPreferencesService readerPreferencesService,
    required ReaderEntryRouteResolver readerEntryRouteResolver,
  }) : _readerPreferencesService = readerPreferencesService,
       _readerEntryRouteResolver = readerEntryRouteResolver;

  final ReaderPreferencesService _readerPreferencesService;
  final ReaderEntryRouteResolver _readerEntryRouteResolver;

  Future<String> resolveLatestReadingRecordRoute(ReadingRecord record) async {
    final progress = await _readerPreferencesService.loadProgress(
      record.bookId,
    );
    final hasMatchedProgress =
        progress != null &&
        progress.sourceId.trim() == record.sourceId.trim() &&
        progress.detailUrl.trim() == record.detailUrl.trim();
    if (hasMatchedProgress) {
      return resolveProgressRoute(progress);
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
      return _readerEntryRouteResolver.buildChapterRoute(
        bookId: record.bookId,
        chapterId: chapterId,
        chapterUrl: chapterUrl,
        chapterTitle: chapterTitle,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        chapterIndex: record.lastChapterIndex,
      );
    }

    return buildBookDetailRoute(
      bookId: record.bookId,
      sourceId: record.sourceId,
      detailUrl: record.detailUrl,
      title: record.bookTitle,
    );
  }

  String resolveReaderFallbackRoute(BookshelfBook book) {
    return _readerEntryRouteResolver.buildRouteFromBookshelfFallback(book);
  }

  String resolveProgressRoute(ReadingProgress progress) {
    return _readerEntryRouteResolver.buildRouteFromProgress(progress);
  }

  String resolveBookDetailRoute(BookshelfBook book, {String? heroTag}) {
    return buildBookDetailRoute(
      bookId: book.bookId,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      title: book.title,
      author: book.author,
      coverUrl: book.coverUrl,
      heroTag: heroTag,
    );
  }
}
