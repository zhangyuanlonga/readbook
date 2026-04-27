import '../../../core/cache/cover_image_disk_cache.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../reader/application/local/local_reader_identity.dart';

class CachedBookPresentation {
  const CachedBookPresentation({
    this.bookId,
    this.sourceId,
    this.detailUrl,
    this.title,
    this.author,
    this.coverUrl,
    required this.inBookshelf,
  });

  final String? bookId;
  final String? sourceId;
  final String? detailUrl;
  final String? title;
  final String? author;
  final String? coverUrl;
  final bool inBookshelf;
}

class CachedBookSummary {
  const CachedBookSummary({
    required this.bookId,
    required this.cachedCount,
    required this.updatedAt,
  });

  final String bookId;
  final int cachedCount;
  final DateTime updatedAt;
}

class CacheManagementService {
  CacheManagementService({
    BookshelfService? bookshelfService,
    AppDatabase? database,
    BookMetadataPresentationResolver resolver =
        const BookMetadataPresentationResolver(),
    CoverImageDiskCache? coverImageDiskCache,
  }) : _bookshelfService = bookshelfService ?? BookshelfService(),
       _database = database ?? AppDatabase.instance,
       _resolver = resolver,
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance;

  final BookshelfService _bookshelfService;
  final AppDatabase _database;
  final BookMetadataPresentationResolver _resolver;
  final CoverImageDiskCache _coverImageDiskCache;

  Future<Map<String, CachedBookPresentation>>
  buildBookPresentationIndex() async {
    final items = await _bookshelfService.getAll();
    final records = await _database.listLatestReadingRecords();
    final localBooks = await _database.getAllLocalBooks();
    final metadataOverrides = await _database.getAllBookMetadataOverrides();
    final localBooksById = <String, LocalBook>{
      for (final book in localBooks) book.id.trim(): book,
    };
    final metadataOverridesByTargetKey = <String, BookMetadataOverride>{
      for (final item in metadataOverrides) item.targetKey: item,
    };
    final result = <String, CachedBookPresentation>{};

    for (final record in records) {
      final bookId = record.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      final presentation = _resolver.resolve(
        fallbackTitle: record.bookTitle.trim(),
        fallbackAuthor: record.bookAuthor,
        realCoverUrl: record.coverUrl,
        localBook:
            record.sourceId == LocalReaderIdentity.localSourceId
                ? localBooksById[bookId]
                : null,
        metadataOverride:
            metadataOverridesByTargetKey[(record.sourceId ==
                    LocalReaderIdentity.localSourceId)
                ? BookMetadataOverride.localTargetKey(bookId)
                : BookMetadataOverride.remoteTargetKey(
                  sourceId: record.sourceId,
                  detailUrl: record.detailUrl,
                )],
      );
      result[bookId] = CachedBookPresentation(
        bookId: record.bookId,
        sourceId: record.sourceId,
        detailUrl: record.detailUrl,
        title:
            presentation.displayTitle.trim().isEmpty
                ? null
                : presentation.displayTitle.trim(),
        author: presentation.displayAuthor?.trim(),
        coverUrl: presentation.displayCover?.trim(),
        inBookshelf: false,
      );
    }

    for (final item in items) {
      final bookId = item.bookId.trim();
      if (bookId.isEmpty) {
        continue;
      }
      final presentation = _resolver.resolve(
        fallbackTitle: item.title,
        fallbackAuthor: item.author,
        realCoverUrl: item.coverUrl,
        localBook:
            item.sourceId == LocalReaderIdentity.localSourceId
                ? localBooksById[bookId]
                : null,
        metadataOverride:
            metadataOverridesByTargetKey[(item.sourceId ==
                    LocalReaderIdentity.localSourceId)
                ? BookMetadataOverride.localTargetKey(bookId)
                : BookMetadataOverride.remoteTargetKey(
                  sourceId: item.sourceId,
                  detailUrl: item.detailUrl,
                )],
      );
      result[bookId] = CachedBookPresentation(
        bookId: item.bookId,
        sourceId: item.sourceId,
        detailUrl: item.detailUrl,
        title:
            presentation.displayTitle.trim().isEmpty
                ? result[bookId]?.title
                : presentation.displayTitle.trim(),
        author: presentation.displayAuthor?.trim() ?? result[bookId]?.author,
        coverUrl: presentation.displayCover?.trim() ?? result[bookId]?.coverUrl,
        inBookshelf: true,
      );
    }

    return result;
  }

  Stream<List<CachedBookSummary>> watchCachedBooks() {
    return _database.watchCachedBooks().map(
      (items) => items
          .map(
            (item) => CachedBookSummary(
              bookId: item.bookId,
              cachedCount: item.cachedCount,
              updatedAt: item.updatedAt,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<int> clearAllCaches() async {
    await _database.clearChapterCaches();
    return _coverImageDiskCache.clearAll();
  }

  Future<bool> clearBookCache({
    required String bookId,
    String? coverUrl,
  }) async {
    await _database.deleteChapterCachesByBookId(bookId);
    return _coverImageDiskCache.clearByUrl(coverUrl ?? '');
  }
}
