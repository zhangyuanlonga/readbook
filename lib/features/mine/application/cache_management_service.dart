import '../../../core/cache/cover_image_disk_cache.dart';
import '../../../domain/entities/book_identity.dart';
import '../../../domain/entities/book_metadata_override.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import '../../book/application/book_metadata_presentation_resolver.dart';
import '../../reader/application/chapter_cache_service.dart';
import '../../reader/application/reading_record_service.dart';

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
    ReadingRecordService? readingRecordService,
    LocalBookRepository? localBookRepository,
    BookMetadataOverrideRepository? bookMetadataOverrideRepository,
    ChapterCacheService? chapterCacheService,
    BookDisplayStateResolver resolver = const BookDisplayStateResolver(),
    CoverImageDiskCache? coverImageDiskCache,
  }) : _bookshelfService = bookshelfService ?? BookshelfService(),
       _readingRecordService = readingRecordService ?? ReadingRecordService(),
       _localBookRepository = localBookRepository,
       _bookMetadataOverrideRepository = bookMetadataOverrideRepository,
       _chapterCacheService = chapterCacheService ?? ChapterCacheService(),
       _resolver = resolver,
       _coverImageDiskCache =
           coverImageDiskCache ?? CoverImageDiskCache.instance;

  final BookshelfService _bookshelfService;
  final ReadingRecordService _readingRecordService;
  final LocalBookRepository? _localBookRepository;
  final BookMetadataOverrideRepository? _bookMetadataOverrideRepository;
  final ChapterCacheService _chapterCacheService;
  final BookDisplayStateResolver _resolver;
  final CoverImageDiskCache _coverImageDiskCache;

  Future<Map<String, CachedBookPresentation>>
  buildBookPresentationIndex() async {
    final items = await _bookshelfService.getAll();
    final records = await _readingRecordService.listLatestRecords();
    final localBooks =
        await (_localBookRepository?.getAllBooks() ??
            Future<List<LocalBook>>.value(const <LocalBook>[]));
    final metadataOverrides =
        await (_bookMetadataOverrideRepository?.getAll() ??
            Future<List<BookMetadataOverride>>.value(
              const <BookMetadataOverride>[],
            ));
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
      final presentation = _resolver.resolveReadingRecord(
        record: record,
        localBook: isLocalBookSourceId(record.sourceId)
            ? localBooksById[bookId]
            : null,
        metadataOverride:
            metadataOverridesByTargetKey[(isLocalBookSourceId(record.sourceId))
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
      final presentation = _resolver.resolveBookshelfBook(
        book: item,
        localBook: isLocalBookSourceId(item.sourceId)
            ? localBooksById[bookId]
            : null,
        metadataOverride:
            metadataOverridesByTargetKey[(isLocalBookSourceId(item.sourceId))
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
    return _chapterCacheService.watchCachedBooks().map(
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
    await _chapterCacheService.clearAllCaches();
    return _coverImageDiskCache.clearAll();
  }

  Future<bool> clearBookCache({
    required String bookId,
    String? coverUrl,
  }) async {
    await _chapterCacheService.clearBookCache(bookId);
    return _coverImageDiskCache.clearByUrl(coverUrl ?? '');
  }
}
