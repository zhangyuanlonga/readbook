import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/logging/app_logger.dart';
import '../../core/media/image_selection_service.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../announcement/application/announcement_read_state_service.dart';
import '../announcement/application/announcement_service.dart';
import '../book/application/book_detail_service.dart';
import '../book/application/custom_cover_storage_service.dart';
import '../reader/application/local/local_book_index_service.dart';
import '../reader/application/local/local_book_storage_service.dart';
import '../reader/application/reader_preferences_service.dart';
import '../reader/application/reader_entry_route_resolver.dart';
import '../reader/application/reader_system_settings_service.dart';
import '../reader/application/reading_record_service.dart';
import '../source/application/source_runtime_facade.dart';
import '../source/application/source_login_state_service.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/bookshelf_external_import_coordinator.dart';
import 'application/bookshelf_presentation_query_service.dart';
import 'application/bookshelf_reader_open_service.dart';
import 'application/bookshelf_service.dart';
import 'application/bookshelf_system_settings_service.dart';
import 'application/local_book_import_service.dart';

class BookshelfPageDependencies {
  const BookshelfPageDependencies({
    required this.bookshelfService,
    required this.systemSettingsService,
    required this.readerPreferencesService,
    required this.readerEntryRouteResolver,
    required this.localBookIndexService,
    required this.bookDetailService,
    required this.readerOpenService,
    required this.logger,
    required this.localBookImportService,
    required this.imageSelectionService,
    required this.customCoverStorageService,
    required this.announcementService,
    required this.announcementReadStateService,
  });

  final BookshelfService bookshelfService;
  final BookshelfSystemSettingsService systemSettingsService;
  final ReaderPreferencesService readerPreferencesService;
  final ReaderEntryRouteResolver readerEntryRouteResolver;
  final LocalBookIndexService localBookIndexService;
  final BookDetailService bookDetailService;
  final BookshelfReaderOpenService readerOpenService;
  final AppLogger logger;
  final LocalBookImportService localBookImportService;
  final ImageSelectionService imageSelectionService;
  final CustomCoverStorageService customCoverStorageService;
  final AnnouncementService announcementService;
  final AnnouncementReadStateService announcementReadStateService;
}

final bookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

final bookshelfSystemSettingsServiceProvider =
    Provider<BookshelfSystemSettingsService>((ref) {
      return BookshelfSystemSettingsService();
    });

final bookshelfReaderPreferencesServiceProvider =
    Provider<ReaderPreferencesService>((ref) {
      return ReaderPreferencesService();
    });

final bookshelfReaderEntryRouteResolverProvider =
    Provider<ReaderEntryRouteResolver>((ref) {
      return const ReaderEntryRouteResolver();
    });

final bookshelfLocalBookIndexServiceProvider = Provider<LocalBookIndexService>((
  ref,
) {
  return LocalBookIndexService(
    localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
    readerSystemSettingsService: ref.watch(
      bookshelfReaderSystemSettingsServiceProvider,
    ),
    storageService: ref.watch(bookshelfLocalBookStorageServiceProvider),
    bookshelfService: ref.watch(bookshelfServiceProvider),
    readingRecordService: ref.watch(bookshelfReadingRecordServiceProvider),
    logger: ref.watch(bookshelfLoggerProvider),
  );
});

final bookshelfReaderSystemSettingsServiceProvider =
    Provider<ReaderSystemSettingsService>((ref) {
      return ReaderSystemSettingsService();
    });

final bookshelfLocalBookStorageServiceProvider =
    Provider<LocalBookStorageService>((ref) {
      return LocalBookStorageService(
        logger: ref.watch(bookshelfLoggerProvider),
      );
    });

final bookshelfLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger.instance;
});

final bookshelfSourceLoginStateServiceProvider =
    Provider<SourceLoginStateService>((ref) {
      return SourceLoginStateService();
    });

final bookshelfBookDetailServiceProvider = Provider<BookDetailService>((ref) {
  return BookDetailService();
});

final bookshelfReadingRecordServiceProvider = Provider<ReadingRecordService>((
  ref,
) {
  return ReadingRecordService(
    database: ref.watch(app_providers.appDatabaseProvider),
  );
});

final bookshelfReaderOpenServiceProvider = Provider<BookshelfReaderOpenService>(
  (ref) {
    return BookshelfReaderOpenService(
      readerPreferencesService: ref.watch(
        bookshelfReaderPreferencesServiceProvider,
      ),
      readerEntryRouteResolver: ref.watch(
        bookshelfReaderEntryRouteResolverProvider,
      ),
      localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
      bookDetailService: ref.watch(bookshelfBookDetailServiceProvider),
      logger: ref.watch(bookshelfLoggerProvider),
    );
  },
);

final localBookImportServiceProvider = Provider<LocalBookImportService>((ref) {
  return LocalBookImportService(
    localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
    bookshelfService: ref.watch(bookshelfServiceProvider),
    readerSystemSettingsService: ref.watch(
      bookshelfReaderSystemSettingsServiceProvider,
    ),
    localBookStorageService: ref.watch(
      bookshelfLocalBookStorageServiceProvider,
    ),
    logger: ref.watch(bookshelfLoggerProvider),
    sourceLoginStateService: ref.watch(
      bookshelfSourceLoginStateServiceProvider,
    ),
    localBookIndexService: ref.watch(bookshelfLocalBookIndexServiceProvider),
  );
});

final bookshelfImageSelectionServiceProvider = Provider<ImageSelectionService>((
  ref,
) {
  return ImageSelectionService();
});

final bookshelfCustomCoverStorageServiceProvider =
    Provider<CustomCoverStorageService>((ref) {
      return const CustomCoverStorageService();
    });

final bookshelfAnnouncementServiceProvider = Provider<AnnouncementService>((
  ref,
) {
  return AnnouncementService();
});

final bookshelfAnnouncementReadStateServiceProvider =
    Provider<AnnouncementReadStateService>((ref) {
      return AnnouncementReadStateService();
    });

final bookshelfPageDependenciesProvider = Provider<BookshelfPageDependencies>((
  ref,
) {
  return BookshelfPageDependencies(
    bookshelfService: ref.watch(bookshelfServiceProvider),
    systemSettingsService: ref.watch(bookshelfSystemSettingsServiceProvider),
    readerPreferencesService: ref.watch(
      bookshelfReaderPreferencesServiceProvider,
    ),
    readerEntryRouteResolver: ref.watch(
      bookshelfReaderEntryRouteResolverProvider,
    ),
    localBookIndexService: ref.watch(bookshelfLocalBookIndexServiceProvider),
    bookDetailService: ref.watch(bookshelfBookDetailServiceProvider),
    readerOpenService: ref.watch(bookshelfReaderOpenServiceProvider),
    logger: ref.watch(bookshelfLoggerProvider),
    localBookImportService: ref.watch(localBookImportServiceProvider),
    imageSelectionService: ref.watch(bookshelfImageSelectionServiceProvider),
    customCoverStorageService: ref.watch(
      bookshelfCustomCoverStorageServiceProvider,
    ),
    announcementService: ref.watch(bookshelfAnnouncementServiceProvider),
    announcementReadStateService: ref.watch(
      bookshelfAnnouncementReadStateServiceProvider,
    ),
  );
});

final bookshelfLocalBookRepositoryProvider = Provider<LocalBookRepository>((
  ref,
) {
  return ref.watch(app_providers.localBookRepositoryProvider);
});

final bookshelfMetadataOverrideRepositoryProvider =
    Provider<BookMetadataOverrideRepository>((ref) {
      return ref.watch(app_providers.bookMetadataOverrideRepositoryProvider);
    });

final bookshelfSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((
  ref,
) {
  return ref.watch(app_providers.appSourceRuntimeFacadeProvider);
});

final bookshelfTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return SourceRuntimeTaskConflictService.instance;
    });

final bookshelfPresentationQueryServiceProvider =
    Provider<BookshelfPresentationQueryService>((ref) {
      return BookshelfPresentationQueryService(
        database: ref.watch(app_providers.appDatabaseProvider),
        bookPresentationQueryService: ref.watch(
          app_providers.bookPresentationQueryServiceProvider,
        ),
        localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
        sourceRuntimeFacade: ref.watch(bookshelfSourceRuntimeFacadeProvider),
      );
    });

typedef BookshelfExternalImportCoordinatorFactory =
    BookshelfExternalImportCoordinator Function();

final bookshelfExternalImportCoordinatorFactoryProvider =
    Provider<BookshelfExternalImportCoordinatorFactory>((ref) {
      return () => BookshelfExternalImportCoordinator();
    });
