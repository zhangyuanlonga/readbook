import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/composition/app_providers.dart' as app_providers;
import '../../../core/logging/app_logger.dart';
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
import '../../book/application/local_book_detail_service.dart';
import 'content_provider.dart';
import 'local_content_provider.dart';
import 'local/local_book_index_service.dart';
import 'local/local_book_preview_service.dart';
import 'local/local_chapter_content_service.dart';
import 'local/local_book_storage_service.dart';
import 'reader_error_center_service.dart';
import 'reader_font_registry_service.dart';
import 'reader_pagination_cache_service.dart';
import 'reader_platform_bridge_service.dart';
import 'reader_preferences_service.dart';
import 'reader_visual_overrides_service.dart';
import 'reader_system_settings_service.dart';
import 'reading_record_service.dart';
import 'reader_cached_chapter_store.dart';
import '../../bookshelf/application/bookshelf_service.dart';
import 'source_content_provider.dart';

class ReaderFeatureDependencies {
  const ReaderFeatureDependencies({
    required this.contentProviderRegistry,
    required this.preferencesService,
    required this.visualOverridesService,
    required this.platformBridgeService,
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
    required this.logger,
    required this.battery,
    required this.deviceInfo,
  });

  final ContentProviderRegistry contentProviderRegistry;
  final ReaderPreferencesService preferencesService;
  final ReaderVisualOverridesService visualOverridesService;
  final ReaderPlatformBridgeService platformBridgeService;
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
  final AppLogger logger;
  final Battery battery;
  final DeviceInfoPlugin deviceInfo;
}

typedef ReaderFeatureDependenciesFactory = ReaderFeatureDependencies Function();

final ReaderPaginationCacheService _sharedReaderPaginationCacheService =
    ReaderPaginationCacheService();

final readerFeatureDependenciesFactoryProvider =
    Provider<ReaderFeatureDependenciesFactory>((ref) {
      return () {
        final database = AppDatabase.instance;
        final localBookRepository = LocalBookRepositoryImpl(database);
        final readerPreferencesService = ReaderPreferencesService();
        final readerVisualOverridesService = ReaderVisualOverridesService();
        final readerPlatformBridgeService = ReaderPlatformBridgeService();
        final readerSystemSettingsService = ReaderSystemSettingsService();
        final readerBackgroundService = ReaderBackgroundService();
        final localBookStorageService = LocalBookStorageService();
        final readingRecordService = ReadingRecordService(database: database);
        final bookshelfService = BookshelfService();
        final localBookIndexService = LocalBookIndexService(
          localBookRepository: localBookRepository,
          readerSystemSettingsService: readerSystemSettingsService,
          storageService: localBookStorageService,
          bookshelfService: bookshelfService,
          readingRecordService: readingRecordService,
        );
        final localBookDetailService = LocalBookDetailService(
          localBookRepository: localBookRepository,
          indexService: localBookIndexService,
        );
        final localChapterContentService = LocalChapterContentService(
          localBookRepository: localBookRepository,
          indexService: localBookIndexService,
          storageService: localBookStorageService,
        );
        final localBookPreviewService = LocalBookPreviewService(
          localBookRepository: localBookRepository,
          storageService: localBookStorageService,
        );
        return ReaderFeatureDependencies(
          contentProviderRegistry: ContentProviderRegistry(
            providers: <ContentProvider>[
              LocalContentProvider(
                detailService: localBookDetailService,
                chapterContentService: localChapterContentService,
                previewService: localBookPreviewService,
              ),
              SourceContentProvider(),
            ],
          ),
          preferencesService: readerPreferencesService,
          visualOverridesService: readerVisualOverridesService,
          platformBridgeService: readerPlatformBridgeService,
          fontRegistryService: ReaderFontRegistryService(),
          paginationCacheService: _sharedReaderPaginationCacheService,
          systemSettingsService: readerSystemSettingsService,
          readerBackgroundService: readerBackgroundService,
          localBookStorageService: localBookStorageService,
          readingRecordService: readingRecordService,
          imageSelectionService: ImageSelectionService(),
          bookshelfService: bookshelfService,
          switchSourceSearchService: SearchService(
            sourceRuntimeFacade: ref.watch(
              app_providers.appSourceRuntimeFacadeProvider,
            ),
          ),
          searchHitCacheService: SearchHitCacheService(),
          sourceHealthService: ref.watch(
            app_providers.appSourceHealthServiceProvider,
          ),
          sourceRuntimeFacade: ref.watch(
            app_providers.appSourceRuntimeFacadeProvider,
          ),
          taskConflictService: ref.watch(
            app_providers.appSourceRuntimeTaskConflictServiceProvider,
          ),
          taskScheduler: ref.watch(
            app_providers.appSourceRuntimeSchedulerServiceProvider,
          ),
          bookmarkRepository: BookmarkRepositoryImpl(database),
          bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
            database,
          ),
          localBookRepository: localBookRepository,
          cachedChapterStore: ReaderCachedChapterStore(database: database),
          readerErrorCenterService: ReaderErrorCenterService.instance,
          logger: AppLogger.instance,
          battery: Battery(),
          deviceInfo: DeviceInfoPlugin(),
        );
      };
    });
