import '../../../data/datasources/local/app_database.dart';
import '../../book/application/book_presentation_query_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../source/application/source_runtime_facade.dart';
import 'local_book_import_service.dart';

class BookshelfPresentationQueryService {
  BookshelfPresentationQueryService({
    required AppDatabase database,
    required BookPresentationQueryService bookPresentationQueryService,
    required LocalBookRepository localBookRepository,
    required SourceRuntimeFacade sourceRuntimeFacade,
  }) : _database = database,
       _bookPresentationQueryService = bookPresentationQueryService,
       _localBookRepository = localBookRepository,
       _sourceRuntimeFacade = sourceRuntimeFacade;

  final AppDatabase _database;
  final BookPresentationQueryService _bookPresentationQueryService;
  final LocalBookRepository _localBookRepository;
  final SourceRuntimeFacade _sourceRuntimeFacade;
  final BookDisplayStateResolver _presentationResolver =
      const BookDisplayStateResolver();

  Future<Map<String, BookMetadataOverride>> loadBookMetadataOverrideMap(
    List<BookshelfBook> books,
  ) async {
    return _bookPresentationQueryService.loadMetadataOverrideMapForBooks(books);
  }

  Future<Map<String, LocalBook>> loadLocalBookMap(
    List<BookshelfBook> books,
  ) async {
    final localBookIds =
        books
            .where(
              (book) =>
                  book.sourceId == LocalBookImportService.localBookSourceId,
            )
            .map((book) => book.bookId.trim())
            .where((bookId) => bookId.isNotEmpty)
            .toSet();
    if (localBookIds.isEmpty) {
      return const <String, LocalBook>{};
    }

    final localBooks = await _localBookRepository.getAllBooks();
    return <String, LocalBook>{
      for (final book in localBooks)
        if (localBookIds.contains(book.id)) book.id: book,
    };
  }

  Map<String, BookDisplayState> buildBookshelfPresentationMap({
    required List<BookshelfBook> books,
    required Map<String, LocalBook> localBooksById,
    required Map<String, BookMetadataOverride> metadataOverridesByTargetKey,
  }) {
    if (books.isEmpty) {
      return const <String, BookDisplayState>{};
    }

    final result = <String, BookDisplayState>{};
    for (final book in books) {
      final localBook =
          book.sourceId == LocalBookImportService.localBookSourceId
              ? localBooksById[book.bookId.trim()]
              : null;
      final targetKey =
          book.sourceId == LocalBookImportService.localBookSourceId
              ? BookMetadataOverride.localTargetKey(book.bookId)
              : BookMetadataOverride.remoteTargetKey(
                sourceId: book.sourceId,
                detailUrl: book.detailUrl,
              );
      result[_bookKey(book)] = _presentationResolver.resolveBookshelfBook(
        book: book,
        localBook: localBook,
        metadataOverride: metadataOverridesByTargetKey[targetKey],
      );
    }
    return result;
  }

  Future<Map<String, String>> loadLatestCachedChapterTitles(
    List<MapEntry<String, String>> pairs,
  ) {
    return _database.getLatestCachedChapterTitlesByBookSource(pairs);
  }

  Future<Map<String, int>> loadCachedChapterCounts(
    List<MapEntry<String, String>> pairs,
  ) {
    return _database.getCachedChapterCountsByBookSource(pairs);
  }

  Future<List<ReadingRecord>> listLatestReadingRecords() {
    return _database.listLatestReadingRecords();
  }

  Future<Map<String, int>> loadSourceTypeMap({
    required Duration timeout,
    required int Function(RegisteredSource source) inferRuntimeSourceType,
    required int Function(String sourceCode) inferPersistedSourceType,
  }) async {
    final sourceTypeBySourceId = <String, int>{};

    final runtimeSources = _sourceRuntimeFacade.registeredScriptSources(
      enabledOnly: false,
    );
    for (final source in runtimeSources) {
      sourceTypeBySourceId[source.runtime.id] = inferRuntimeSourceType(source);
    }

    try {
      final persistedSources = await _sourceRuntimeFacade
          .listScriptSources()
          .timeout(timeout);
      for (final source in persistedSources) {
        sourceTypeBySourceId[source.id] = inferPersistedSourceType(
          source.sourceCode,
        );
      }
    } catch (_) {
      // Keep runtime-derived metadata when persisted source loading fails.
    }

    return sourceTypeBySourceId;
  }

  String _bookKey(BookshelfBook book) {
    return '${book.sourceId.trim()}::${book.bookId.trim()}::${book.detailUrl.trim()}';
  }
}
