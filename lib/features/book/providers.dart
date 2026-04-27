import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/media/image_selection_service.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../bookshelf/application/bookshelf_service.dart';
import '../reader/application/local/local_book_index_service.dart';
import '../reader/application/local/local_book_storage_service.dart';
import '../reader/application/reader_system_settings_service.dart';
import '../reader/application/reader_preferences_service.dart';
import '../reader/application/reading_record_service.dart';
import '../search/application/search_hit_cache_service.dart';
import '../search/application/search_service.dart';
import '../source/application/source_runtime_facade.dart';
import '../source/application/source_runtime_scheduler_service.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/book_detail_service.dart';
import 'application/book_local_metadata_service.dart';
import 'application/custom_cover_storage_service.dart';

class BookDetailDependencies {
  const BookDetailDependencies({
    required this.bookDetailService,
    required this.bookshelfService,
    required this.switchSourceSearchService,
    required this.searchHitCacheService,
    required this.readerSystemSettingsService,
    required this.localBookStorageService,
    required this.readerPreferencesService,
    required this.readingRecordService,
    required this.localBookIndexService,
    required this.imageSelectionService,
    required this.customCoverStorageService,
  });

  final BookDetailService bookDetailService;
  final BookshelfService bookshelfService;
  final SearchService switchSourceSearchService;
  final SearchHitCacheService searchHitCacheService;
  final ReaderSystemSettingsService readerSystemSettingsService;
  final LocalBookStorageService localBookStorageService;
  final ReaderPreferencesService readerPreferencesService;
  final ReadingRecordService readingRecordService;
  final LocalBookIndexService localBookIndexService;
  final ImageSelectionService imageSelectionService;
  final CustomCoverStorageService customCoverStorageService;
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
    return LocalBookIndexService();
  },
);

final bookDetailImageSelectionServiceProvider = Provider<ImageSelectionService>(
  (ref) {
    return ImageSelectionService();
  },
);

final bookDetailCustomCoverStorageServiceProvider =
    Provider<CustomCoverStorageService>((ref) {
      return const CustomCoverStorageService();
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

final bookDetailDependenciesProvider = Provider<BookDetailDependencies>((ref) {
  return BookDetailDependencies(
    bookDetailService: ref.watch(bookDetailServiceProvider),
    bookshelfService: ref.watch(bookDetailBookshelfServiceProvider),
    switchSourceSearchService: ref.watch(
      bookDetailSwitchSourceSearchServiceProvider,
    ),
    searchHitCacheService: ref.watch(bookDetailSearchHitCacheServiceProvider),
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
    imageSelectionService: ref.watch(bookDetailImageSelectionServiceProvider),
    customCoverStorageService: ref.watch(
      bookDetailCustomCoverStorageServiceProvider,
    ),
  );
});
