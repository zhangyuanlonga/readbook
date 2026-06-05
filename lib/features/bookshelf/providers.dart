import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/logging/app_logger.dart';
import '../../core/media/image_selection_service.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../announcement/application/announcement_read_state_service.dart';
import '../announcement/application/announcement_service.dart';
import '../book/application/book_detail_service.dart';
import '../book/application/book_reading_status_service.dart';
import '../book/application/custom_cover_storage_service.dart';
import '../reader/application/local/local_book_index_service.dart';
import '../reader/application/local/local_reader_entry_guard_service.dart';
import '../reader/application/local/local_book_storage_service.dart';
import '../reader/application/reader_preferences_service.dart';
import '../reader/application/reader_entry_route_resolver.dart';
import '../reader/application/reader_system_settings_service.dart';
import '../reader/application/reading_record_service.dart';
import '../source/application/remote_content_task_conflict_service.dart';
import 'application/bookshelf_external_import_coordinator.dart';
import 'application/bookshelf_flow_coordinator.dart';
import 'application/bookshelf_page_route_service.dart';
import 'application/bookshelf_page_state.dart';
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
    required this.pageRouteService,
    required this.localBookIndexService,
    required this.bookDetailService,
    required this.readerOpenService,
    required this.logger,
    required this.localBookImportService,
    required this.imageSelectionService,
    required this.customCoverStorageService,
    required this.announcementService,
    required this.announcementReadStateService,
    required this.flowCoordinator,
    required this.readingStatusService,
  });

  final BookshelfService bookshelfService;
  final BookshelfSystemSettingsService systemSettingsService;
  final ReaderPreferencesService readerPreferencesService;
  final BookshelfPageRouteService pageRouteService;
  final LocalBookIndexService localBookIndexService;
  final BookDetailService bookDetailService;
  final BookshelfReaderOpenService readerOpenService;
  final AppLogger logger;
  final LocalBookImportService localBookImportService;
  final ImageSelectionService imageSelectionService;
  final CustomCoverStorageService customCoverStorageService;
  final AnnouncementService announcementService;
  final AnnouncementReadStateService announcementReadStateService;
  final BookshelfFlowCoordinator flowCoordinator;
  final BookReadingStatusService readingStatusService;
}

class DesktopBookshelfSortOption {
  const DesktopBookshelfSortOption({
    required this.mode,
    required this.label,
    required this.description,
    required this.selected,
  });

  final BookshelfSortMode mode;
  final String label;
  final String description;
  final bool selected;
}

class DesktopBookshelfToolbarActions {
  const DesktopBookshelfToolbarActions({
    required this.hasBooks,
    required this.hasFilteredBooks,
    required this.useGridView,
    required this.sortOptions,
    required this.gridSettingOptions,
    required this.listSettingOptions,
    required this.onSortModeSelected,
    required this.onViewModeSelected,
    required this.onSelectBooks,
    required this.onImportLocal,
  });

  final bool hasBooks;
  final bool hasFilteredBooks;
  final bool useGridView;
  final List<DesktopBookshelfSortOption> sortOptions;
  final List<DesktopBookshelfDisplaySettingOption> gridSettingOptions;
  final List<DesktopBookshelfDisplaySettingOption> listSettingOptions;
  final ValueChanged<BookshelfSortMode> onSortModeSelected;
  final ValueChanged<bool> onViewModeSelected;
  final VoidCallback onSelectBooks;
  final VoidCallback onImportLocal;
}

class DesktopBookshelfLibraryStatusAction {
  const DesktopBookshelfLibraryStatusAction({
    required this.label,
    required this.count,
    required this.selected,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
  });

  /// 桌面端书架状态名称，Shell 只展示文案，具体筛选仍由 BookshelfPage 处理。
  final String label;
  final int count;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelected;
  final bool enabled;
}

class DesktopBookshelfLibraryActions {
  const DesktopBookshelfLibraryActions({
    required this.activeLabel,
    required this.statusActions,
  });

  /// 当前书架视图名称，用于桌面顶栏的紧凑下拉入口。
  final String activeLabel;
  final List<DesktopBookshelfLibraryStatusAction> statusActions;
}

class DesktopBookshelfDisplaySettingOption {
  const DesktopBookshelfDisplaySettingOption({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.modeGroup,
  });

  /// 桌面端菜单展示的设置名称，仅用于当前显示模式的轻量快捷配置。
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final String? modeGroup;
}

final bookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

/// 桌面端顶部栏的书架本地搜索关键词。
///
/// 该状态只负责过滤当前书架内容，不进入在线搜书流程，避免壳层搜索框和书架页
/// 各自维护关键词导致桌面端筛选结果不同步。
final desktopBookshelfSearchKeywordProvider = StateProvider<String>((ref) {
  return '';
});

/// 桌面端书架顶栏动作注册器。
///
/// ShellScaffold 只负责展示顶栏图标和菜单，具体业务仍由 BookshelfPage 注册回调处理，
/// 避免壳层直接依赖书架页面的内部状态。
final desktopBookshelfToolbarActionsProvider =
    StateProvider<DesktopBookshelfToolbarActions?>((ref) {
      return null;
    });

/// 桌面端书架状态入口注册器。
///
/// ShellScaffold 只消费当前状态列表和回调，不直接读取书架数据，避免桌面壳层和
/// BookshelfPage 各自维护一套筛选逻辑。
final desktopBookshelfLibraryActionsProvider =
    StateProvider<DesktopBookshelfLibraryActions?>((ref) {
      return null;
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

final bookshelfBookDetailServiceProvider = Provider<BookDetailService>((ref) {
  return BookDetailService(
    sourceHealthService: ref.watch(
      app_providers.appSourceHealthServiceProvider,
    ),
  );
});

final bookshelfBookReadingStatusServiceProvider =
    Provider<BookReadingStatusService>((ref) {
      return BookReadingStatusService(
        readerPreferencesService: ref.watch(
          bookshelfReaderPreferencesServiceProvider,
        ),
        bookDetailService: ref.watch(bookshelfBookDetailServiceProvider),
        localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
      );
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
      localReaderEntryGuardService: LocalReaderEntryGuardService(
        localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
        readerEntryRouteResolver: ref.watch(
          bookshelfReaderEntryRouteResolverProvider,
        ),
      ),
      logger: ref.watch(bookshelfLoggerProvider),
    );
  },
);

final bookshelfPageRouteServiceProvider = Provider<BookshelfPageRouteService>((
  ref,
) {
  return BookshelfPageRouteService(
    readerPreferencesService: ref.watch(
      bookshelfReaderPreferencesServiceProvider,
    ),
    readerEntryRouteResolver: ref.watch(
      bookshelfReaderEntryRouteResolverProvider,
    ),
    localReaderEntryGuardService: LocalReaderEntryGuardService(
      localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
      readerEntryRouteResolver: ref.watch(
        bookshelfReaderEntryRouteResolverProvider,
      ),
    ),
  );
});

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
      return CustomCoverStorageService();
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
    pageRouteService: ref.watch(bookshelfPageRouteServiceProvider),
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
    flowCoordinator: ref.watch(bookshelfFlowCoordinatorProvider),
    readingStatusService: ref.watch(bookshelfBookReadingStatusServiceProvider),
  );
});

final bookshelfFlowCoordinatorProvider = Provider<BookshelfFlowCoordinator>((
  ref,
) {
  return const BookshelfFlowCoordinator();
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

final bookshelfTaskConflictServiceProvider =
    Provider<RemoteContentTaskConflictService>((ref) {
      return ref.watch(
        app_providers.appRemoteContentTaskConflictServiceProvider,
      );
    });

final bookshelfPresentationQueryServiceProvider =
    Provider<BookshelfPresentationQueryService>((ref) {
      return BookshelfPresentationQueryService(
        database: ref.watch(app_providers.appDatabaseProvider),
        bookPresentationQueryService: ref.watch(
          app_providers.bookPresentationQueryServiceProvider,
        ),
        localBookRepository: ref.watch(bookshelfLocalBookRepositoryProvider),
      );
    });

typedef BookshelfExternalImportCoordinatorFactory =
    BookshelfExternalImportCoordinator Function();

final bookshelfExternalImportCoordinatorFactoryProvider =
    Provider<BookshelfExternalImportCoordinatorFactory>((ref) {
      return () => BookshelfExternalImportCoordinator(
        externalImportBridge: ref.watch(
          app_providers.appExternalImportBridgeProvider,
        ),
      );
    });
