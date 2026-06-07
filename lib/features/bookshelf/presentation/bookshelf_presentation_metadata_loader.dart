import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../application/bookshelf_presentation_query_service.dart';

class BookshelfPresentationMetadataLoadResult {
  const BookshelfPresentationMetadataLoadResult({
    required this.localBooksById,
    required this.metadataOverridesByTargetKey,
  });

  final Map<String, LocalBook> localBooksById;
  final Map<String, BookMetadataOverride> metadataOverridesByTargetKey;
}

class BookshelfPresentationMetadataLoader {
  const BookshelfPresentationMetadataLoader({
    required BookshelfPresentationQueryService queryService,
    required String localBookSourceId,
  }) : _queryService = queryService,
       _localBookSourceId = localBookSourceId;

  final BookshelfPresentationQueryService _queryService;
  final String _localBookSourceId;

  Future<BookshelfPresentationMetadataLoadResult?> loadPresentationMetadata(
    List<BookshelfBook> books,
  ) async {
    final localBooksFuture = loadLocalBookMap(books);
    final metadataOverridesFuture = loadBookMetadataOverrideMap(books);

    try {
      await Future.wait<dynamic>([localBooksFuture, metadataOverridesFuture]);
    } catch (_) {
      return null;
    }

    return BookshelfPresentationMetadataLoadResult(
      localBooksById: await localBooksFuture,
      metadataOverridesByTargetKey: await metadataOverridesFuture,
    );
  }

  Future<Map<String, BookMetadataOverride>> loadBookMetadataOverrideMap(
    List<BookshelfBook> books,
  ) async {
    if (books.isEmpty) {
      return const <String, BookMetadataOverride>{};
    }
    try {
      return await _queryService.loadBookMetadataOverrideMap(books);
    } catch (_) {
      return const <String, BookMetadataOverride>{};
    }
  }

  Future<Map<String, LocalBook>> loadLocalBookMap(
    List<BookshelfBook> books,
  ) async {
    if (!books.any((book) => book.sourceId == _localBookSourceId)) {
      return const <String, LocalBook>{};
    }

    try {
      return await _queryService.loadLocalBookMap(books);
    } catch (_) {
      return const <String, LocalBook>{};
    }
  }

  Future<Map<String, String>> loadLatestCachedChapterTitles(
    List<MapEntry<String, String>> bookSourcePairs,
  ) {
    return _queryService.loadLatestCachedChapterTitles(bookSourcePairs);
  }

  Future<Map<String, int>> loadCachedChapterCounts(
    List<MapEntry<String, String>> bookSourcePairs,
  ) {
    return _queryService.loadCachedChapterCounts(bookSourcePairs);
  }

  Future<ReadingProgress?> loadProgress(
    Future<ReadingProgress?> Function() load,
  ) {
    return load();
  }
}
