import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_record.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../source/application/source_runtime_facade.dart';

class BookshelfPresentationQueryService {
  BookshelfPresentationQueryService({
    required AppDatabase database,
    required LocalBookRepository localBookRepository,
    required SourceRuntimeFacade sourceRuntimeFacade,
  }) : _database = database,
       _localBookRepository = localBookRepository,
       _sourceRuntimeFacade = sourceRuntimeFacade;

  final AppDatabase _database;
  final LocalBookRepository _localBookRepository;
  final SourceRuntimeFacade _sourceRuntimeFacade;

  Future<Map<String, BookMetadataOverride>> loadBookMetadataOverrideMap(
    List<BookshelfBook> books,
  ) async {
    if (books.isEmpty) {
      return const <String, BookMetadataOverride>{};
    }
    final overrides = await _database.getAllBookMetadataOverrides();
    final validKeys = <String>{
      for (final book in books)
        if (book.sourceId == _kLocalBookSourceId)
          BookMetadataOverride.localTargetKey(book.bookId)
        else
          BookMetadataOverride.remoteTargetKey(
            sourceId: book.sourceId,
            detailUrl: book.detailUrl,
          ),
    };
    return <String, BookMetadataOverride>{
      for (final item in overrides)
        if (validKeys.contains(item.targetKey)) item.targetKey: item,
    };
  }

  Future<Map<String, LocalBook>> loadLocalBookMap(
    List<BookshelfBook> books,
  ) async {
    final localBookIds =
        books
            .where((book) => book.sourceId == _kLocalBookSourceId)
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
}

const String _kLocalBookSourceId = 'local-import';
