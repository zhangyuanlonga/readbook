import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/image_selection_service.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../../data/repositories/bookmark_repository_impl.dart';
import '../../../data/repositories/local_book_repository_impl.dart';
import '../../../domain/repositories/book_metadata_override_repository.dart';
import '../../../domain/repositories/bookmark_repository.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../mine/application/reader_background_service.dart';
import '../../search/application/search_hit_cache_service.dart';
import '../../search/application/search_service.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_facade.dart';
import '../../source/application/source_runtime_scheduler_service.dart';
import '../../source/application/source_runtime_task_conflict_service.dart';
import 'content_provider.dart';
import 'local_content_provider.dart';
import 'local/local_book_storage_service.dart';
import 'reader_error_center_service.dart';
import 'reader_font_registry_service.dart';
import 'reader_pagination_cache_service.dart';
import 'reader_preferences_service.dart';
import 'reader_system_settings_service.dart';
import 'reading_record_service.dart';
import 'reader_cached_chapter_store.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import 'source_content_provider.dart';

class ReaderFeatureDependencies {
  const ReaderFeatureDependencies({
    required this.contentProviderRegistry,
    required this.preferencesService,
    required this.fontRegistryService,
    required this.paginationCacheService,
    required this.systemSettingsService,
    required this.readerBackgroundService,
    required this.localBookStorageService,
    required this.readingRecordService,
    required this.imageSelectionService,
    required this.bookshelfService,
    required this.switchSourceSearchService,
    required this.searchHitCacheService,
    required this.sourceHealthService,
    required this.sourceRuntimeFacade,
    required this.taskConflictService,
    required this.taskScheduler,
    required this.bookmarkRepository,
    required this.bookMetadataOverrideRepository,
    required this.localBookRepository,
    required this.cachedChapterStore,
    required this.readerErrorCenterService,
  });

  final ContentProviderRegistry contentProviderRegistry;
  final ReaderPreferencesService preferencesService;
  final ReaderFontRegistryService fontRegistryService;
  final ReaderPaginationCacheService paginationCacheService;
  final ReaderSystemSettingsService systemSettingsService;
  final ReaderBackgroundService readerBackgroundService;
  final LocalBookStorageService localBookStorageService;
  final ReadingRecordService readingRecordService;
  final ImageSelectionService imageSelectionService;
  final BookshelfService bookshelfService;
  final SearchService switchSourceSearchService;
  final SearchHitCacheService searchHitCacheService;
  final SourceHealthService sourceHealthService;
  final SourceRuntimeFacade sourceRuntimeFacade;
  final SourceRuntimeTaskConflictService taskConflictService;
  final SourceRuntimeSchedulerService taskScheduler;
  final BookmarkRepository bookmarkRepository;
  final BookMetadataOverrideRepository bookMetadataOverrideRepository;
  final LocalBookRepository localBookRepository;
  final ReaderCachedChapterStore cachedChapterStore;
  final ReaderErrorCenterService readerErrorCenterService;
}

typedef ReaderFeatureDependenciesFactory = ReaderFeatureDependencies Function();

final readerFeatureDependenciesFactoryProvider =
    Provider<ReaderFeatureDependenciesFactory>((ref) {
      return () {
        final database = AppDatabase.instance;
        return ReaderFeatureDependencies(
          contentProviderRegistry: ContentProviderRegistry(
            providers: <ContentProvider>[
              LocalContentProvider(),
              SourceContentProvider(),
            ],
          ),
          preferencesService: ReaderPreferencesService(),
          fontRegistryService: ReaderFontRegistryService(),
          paginationCacheService: ReaderPaginationCacheService(),
          systemSettingsService: ReaderSystemSettingsService(),
          readerBackgroundService: ReaderBackgroundService(),
          localBookStorageService: LocalBookStorageService(),
          readingRecordService: ReadingRecordService(database: database),
          imageSelectionService: ImageSelectionService(),
          bookshelfService: BookshelfService(),
          switchSourceSearchService: SearchService(),
          searchHitCacheService: SearchHitCacheService(),
          sourceHealthService: SourceHealthService.instance,
          sourceRuntimeFacade: SourceRuntimeFacade.instance,
          taskConflictService: SourceRuntimeTaskConflictService.instance,
          taskScheduler: SourceRuntimeSchedulerService.instance,
          bookmarkRepository: BookmarkRepositoryImpl(database),
          bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
            database,
          ),
          localBookRepository: LocalBookRepositoryImpl(database),
          cachedChapterStore: ReaderCachedChapterStore(database: database),
          readerErrorCenterService: ReaderErrorCenterService.instance,
        );
      };
    });
