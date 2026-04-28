import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/media/image_selection_service.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../bookshelf/application/bookshelf_service.dart';
import '../reader/application/local/local_book_index_service.dart';
import '../reader/application/local/local_book_preview_service.dart';
import '../reader/application/local/local_chapter_content_service.dart';
import '../reader/application/local/local_book_storage_service.dart';
import '../reader/application/reader_system_settings_service.dart';
import '../reader/application/reader_preferences_service.dart';
import '../reader/application/reading_record_service.dart';
import '../reader/application/reader_entry_route_resolver.dart';
import '../search/application/search_hit_cache_service.dart';
import '../search/application/search_service.dart';
import '../source/application/source_runtime_facade.dart';
import '../source/application/source_runtime_scheduler_service.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/book_detail_service.dart';
import 'application/book_detail_read_route_service.dart';
import 'application/book_detail_action_service.dart';
import 'application/book_detail_catalog_service.dart';
import 'application/book_local_metadata_service.dart';
import 'application/book_metadata_edit_service.dart';
import 'application/book_detail_metadata_flow_service.dart';
import 'application/book_presentation_sync_service.dart';
import 'application/book_metadata_presentation_resolver.dart';
import 'application/custom_cover_storage_service.dart';
import 'application/local_book_detail_service.dart';

class BookDetailDependencies {
  const BookDetailDependencies({
    required this.bookDetailService,
    required this.bookshelfService,
    required this.switchSourceSearchService,
    required this.searchHitCacheService,
    required this.readRouteService,
    required this.readerSystemSettingsService,
    required this.localBookStorageService,
    required this.readerPreferencesService,
    required this.readingRecordService,
    required this.localBookIndexService,
    required this.bookMetadataEditService,
    required this.bookPresentationSyncService,
    required this.actionService,
    required this.catalogService,
    required this.metadataFlowService,
  });

  final BookDetailService bookDetailService;
  final BookshelfService bookshelfService;
  final SearchService switchSourceSearchService;
  final SearchHitCacheService searchHitCacheService;
  final BookDetailReadRouteService readRouteService;
  final ReaderSystemSettingsService readerSystemSettingsService;
  final LocalBookStorageService localBookStorageService;
  final ReaderPreferencesService readerPreferencesService;
  final ReadingRecordService readingRecordService;
  final LocalBookIndexService localBookIndexService;
  final BookMetadataEditService bookMetadataEditService;
  final BookPresentationSyncService bookPresentationSyncService;
  final BookDetailActionService actionService;
  final BookDetailCatalogService catalogService;
  final BookDetailMetadataFlowService metadataFlowService;
}

final bookBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return ref.watch(app_providers.bookmarkRepositoryProvider);
});

final bookMetadataOverrideRepositoryProvider =
    Provider<BookMetadataOverrideRepository>((ref) {
      return ref.watch(app_providers.bookMetadataOverrideRepositoryProvider);
    });

final bookLocalBookRepositoryProvider = Provider<LocalBookRepository>((ref) {
  return ref.watch(app_providers.localBookRepositoryProvider);
});

final bookSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return ref.watch(app_providers.appSourceRuntimeFacadeProvider);
});

final bookDetailServiceProvider = Provider<BookDetailService>((ref) {
  return BookDetailService(
    sourceRuntimeFacade: ref.watch(bookSourceRuntimeFacadeProvider),
  );
});

final bookDetailBookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

final bookDetailSwitchSourceSearchServiceProvider = Provider<SearchService>((
  ref,
) {
  return SearchService(
    sourceRuntimeFacade: ref.watch(bookSourceRuntimeFacadeProvider),
  );
});

final bookDetailSearchHitCacheServiceProvider = Provider<SearchHitCacheService>(
  (ref) {
    return SearchHitCacheService();
  },
);

final bookDetailReaderEntryRouteResolverProvider =
    Provider<ReaderEntryRouteResolver>((ref) {
      return const ReaderEntryRouteResolver();
    });

final bookDetailReadRouteServiceProvider = Provider<BookDetailReadRouteService>((
  ref,
) {
  return BookDetailReadRouteService(
    readerEntryRouteResolver: ref.watch(
      bookDetailReaderEntryRouteResolverProvider,
    ),
  );
});

final bookDetailReaderSystemSettingsServiceProvider =
    Provider<ReaderSystemSettingsService>((ref) {
      return ReaderSystemSettingsService();
    });

final bookDetailLocalBookStorageServiceProvider =
    Provider<LocalBookStorageService>((ref) {
      return LocalBookStorageService();
    });

final bookDetailReaderPreferencesServiceProvider =
    Provider<ReaderPreferencesService>((ref) {
      return ReaderPreferencesService();
    });

final bookDetailReadingRecordServiceProvider = Provider<ReadingRecordService>((
  ref,
) {
  return ReadingRecordService();
});

final bookDetailLocalBookIndexServiceProvider = Provider<LocalBookIndexService>(
  (ref) {
    return LocalBookIndexService(
      localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
      readerSystemSettingsService: ref.watch(
        bookDetailReaderSystemSettingsServiceProvider,
      ),
      storageService: ref.watch(bookDetailLocalBookStorageServiceProvider),
      bookshelfService: ref.watch(bookDetailBookshelfServiceProvider),
      readingRecordService: ref.watch(bookDetailReadingRecordServiceProvider),
    );
  },
);

final bookDetailLocalChapterContentServiceProvider =
    Provider<LocalChapterContentService>((ref) {
      return LocalChapterContentService(
        localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
        indexService: ref.watch(bookDetailLocalBookIndexServiceProvider),
        storageService: ref.watch(bookDetailLocalBookStorageServiceProvider),
      );
    });

final bookDetailLocalBookPreviewServiceProvider =
    Provider<LocalBookPreviewService>((ref) {
      return LocalBookPreviewService(
        localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
        storageService: ref.watch(bookDetailLocalBookStorageServiceProvider),
      );
    });

final bookDetailImageSelectionServiceProvider = Provider<ImageSelectionService>(
  (ref) {
    return ImageSelectionService();
  },
);

final bookDetailCustomCoverStorageServiceProvider =
    Provider<CustomCoverStorageService>((ref) {
      return const CustomCoverStorageService();
    });

final bookMetadataEditServiceProvider = Provider<BookMetadataEditService>((
  ref,
) {
  return BookMetadataEditService(
    bookMetadataOverrideRepository: ref.watch(
      bookMetadataOverrideRepositoryProvider,
    ),
    localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
    imageSelectionService: ref.watch(bookDetailImageSelectionServiceProvider),
    customCoverStorageService: ref.watch(
      bookDetailCustomCoverStorageServiceProvider,
    ),
  );
});

final bookPresentationSyncServiceProvider =
    Provider<BookPresentationSyncService>((ref) {
      return BookPresentationSyncService(
        readerPreferencesService: ref.watch(
          bookDetailReaderPreferencesServiceProvider,
        ),
        readingRecordService: ref.watch(bookDetailReadingRecordServiceProvider),
        bookshelfService: ref.watch(bookDetailBookshelfServiceProvider),
      );
    });

final bookDetailActionServiceProvider = Provider<BookDetailActionService>((ref) {
  return BookDetailActionService(
    bookshelfService: ref.watch(bookDetailBookshelfServiceProvider),
  );
});

final bookDetailCatalogServiceProvider =
    Provider<BookDetailCatalogService>((ref) {
      return const BookDetailCatalogService();
    });

final bookDetailMetadataFlowServiceProvider =
    Provider<BookDetailMetadataFlowService>((ref) {
      return BookDetailMetadataFlowService(
        bookMetadataEditService: ref.watch(bookMetadataEditServiceProvider),
        bookPresentationSyncService: ref.watch(
          bookPresentationSyncServiceProvider,
        ),
        presentationResolver: const BookMetadataPresentationResolver(),
      );
    });

final bookTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return SourceRuntimeTaskConflictService.instance;
    });

final bookTaskSchedulerProvider = Provider<SourceRuntimeSchedulerService>((
  ref,
) {
  return SourceRuntimeSchedulerService.instance;
});

final bookLocalMetadataServiceProvider = Provider<BookLocalMetadataService>((
  ref,
) {
  return BookLocalMetadataService(
    localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
  );
});

final bookLocalBookDetailServiceProvider = Provider<LocalBookDetailService>((
  ref,
) {
  return LocalBookDetailService(
    localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
    indexService: ref.watch(bookDetailLocalBookIndexServiceProvider),
  );
});

final bookDetailDependenciesProvider = Provider<BookDetailDependencies>((ref) {
  return BookDetailDependencies(
    bookDetailService: ref.watch(bookDetailServiceProvider),
    bookshelfService: ref.watch(bookDetailBookshelfServiceProvider),
    switchSourceSearchService: ref.watch(
      bookDetailSwitchSourceSearchServiceProvider,
    ),
    searchHitCacheService: ref.watch(bookDetailSearchHitCacheServiceProvider),
    readRouteService: ref.watch(bookDetailReadRouteServiceProvider),
    readerSystemSettingsService: ref.watch(
      bookDetailReaderSystemSettingsServiceProvider,
    ),
    localBookStorageService: ref.watch(
      bookDetailLocalBookStorageServiceProvider,
    ),
    readerPreferencesService: ref.watch(
      bookDetailReaderPreferencesServiceProvider,
    ),
    readingRecordService: ref.watch(bookDetailReadingRecordServiceProvider),
    localBookIndexService: ref.watch(bookDetailLocalBookIndexServiceProvider),
    bookMetadataEditService: ref.watch(bookMetadataEditServiceProvider),
    bookPresentationSyncService: ref.watch(bookPresentationSyncServiceProvider),
    actionService: ref.watch(bookDetailActionServiceProvider),
    catalogService: ref.watch(bookDetailCatalogServiceProvider),
    metadataFlowService: ref.watch(bookDetailMetadataFlowServiceProvider),
  );
});
