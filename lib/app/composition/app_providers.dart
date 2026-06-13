import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_event_bus.dart';
import '../../core/auth/session_change_listener.dart';
import '../../core/auth/auth_token_refresher_impl.dart';
import '../../core/cache/app_cache_coordinator.dart';
import '../../core/cache/cover_image_disk_cache.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/source_log_store.dart';
import '../../core/membership/membership_access_resolver.dart';
import '../../core/membership/membership_access_service.dart';
import '../../core/network/api_client.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/local_book_repository_impl.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../../features/auth/providers.dart' as auth_providers;
import '../../features/source/application/external_source_import_bridge.dart';
import '../../features/source/application/source_health_service.dart';
import '../../features/book/application/book_presentation_query_service.dart';
import '../../features/mine/application/advanced_theme_provider.dart';
import '../../features/mine/application/private_book_source_session_listener.dart';
import '../../features/mine/presentation/advanced_theme_preview_image_cache.dart';
import '../../features/mine/providers.dart' as mine_providers;
import '../../features/reader/application/local/local_book_index_cache_store.dart';
import '../../features/reader/application/reader_preference_cache_store.dart';
import '../../features/reader/application/reader_session_listener.dart';
import '../../features/search/application/search_hit_cache_service.dart';
import '../../features/search/application/search_history_session_listener.dart';
import '../../features/source/application/remote_content_task_scheduler_service.dart';
import '../../features/source/application/remote_content_task_conflict_service.dart';
import '../../features/source/application/source_health_persistence_service.dart';
import '../lifecycle/auth_account_lifecycle_coordinator.dart';
import '../lifecycle/app_lifecycle_coordinator.dart';
import '../platform/app_platform_capabilities.dart';
import '../startup/app_announcement_coordinator.dart';
import '../startup/app_startup_coordinator.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final appCapabilitiesProvider = Provider<AppPlatformCapabilities>((ref) {
  return ref.watch(appPlatformCapabilitiesProvider);
});

final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger.instance;
});

final appSourceLogStoreProvider = Provider<SourceLogStore>((ref) {
  return SourceLogStore.instance;
});

final appCoverImageDiskCacheProvider = Provider<CoverImageDiskCache>((ref) {
  return CoverImageDiskCache.instance;
});

final appSearchHitCacheServiceProvider = Provider<SearchHitCacheService>((ref) {
  return SearchHitCacheService(database: ref.watch(appDatabaseProvider));
});

final appSourceHealthPersistenceServiceProvider =
    Provider<SourceHealthPersistenceService>((ref) {
      return SourceHealthPersistenceService(
        database: ref.watch(appDatabaseProvider),
      );
    });

final appCacheCoordinatorProvider = Provider<AppCacheCoordinator>((ref) {
  return AppCacheCoordinator(
    stores: [
      ApiClient.defaultCacheStore,
      ref.watch(appSearchHitCacheServiceProvider),
      ref.watch(appSourceHealthPersistenceServiceProvider),
      AdvancedThemePreviewCacheStore(),
      LocalBookIndexCacheStore(database: ref.watch(appDatabaseProvider)),
      ReaderPreferenceCacheStore(),
    ],
  );
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl(ref.watch(appDatabaseProvider));
});

final bookMetadataOverrideRepositoryProvider =
    Provider<BookMetadataOverrideRepository>((ref) {
      return BookMetadataOverrideRepositoryImpl(ref.watch(appDatabaseProvider));
    });

final localBookRepositoryProvider = Provider<LocalBookRepository>((ref) {
  return LocalBookRepositoryImpl(ref.watch(appDatabaseProvider));
});

final appSourceHealthServiceProvider = Provider<SourceHealthService>((ref) {
  final service = SourceHealthService(
    persistenceService: ref.watch(appSourceHealthPersistenceServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final appRemoteContentTaskSchedulerServiceProvider =
    Provider<RemoteContentTaskSchedulerService>((ref) {
      return RemoteContentTaskSchedulerService.instance;
    });

final appRemoteContentTaskConflictServiceProvider =
    Provider<RemoteContentTaskConflictService>((ref) {
      return RemoteContentTaskConflictService.instance;
    });

final appExternalImportBridgeProvider = Provider<ExternalImportBridge>((ref) {
  return ExternalImportBridge.instance;
});

final appAuthEventStreamProvider = Provider<Stream<AuthEvent>>((ref) {
  return AuthEventBus.instance.stream;
});

final appMembershipAccessServiceProvider = Provider<MembershipAccessService>((
  ref,
) {
  // 全平台会员能力统一从登录会话、用户资料和会员 entitlement 三层解析，
  // 避免搜索、阅读器、高级主题各自 new service 后出现权益判断不一致。
  return MembershipAccessService(
    sessionStore: ref.watch(auth_providers.authSessionStoreProvider),
    userProfileService: ref.watch(auth_providers.userProfileServiceProvider),
  );
});

final appMembershipAccessSnapshotProvider =
    FutureProvider<MembershipAccessSnapshot>((ref) async {
      // 账号事件是全平台会话变化的唯一刷新信号。统一快照在这里失效后，
      // 搜索、高级主题、阅读器等后续接入方不会因为各自缓存而读到旧会员状态。
      late final StreamSubscription<AuthEvent> subscription;
      subscription = ref.watch(appAuthEventStreamProvider).listen((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(() {
        unawaited(subscription.cancel());
      });
      final snapshot =
          await ref
              .watch(appMembershipAccessServiceProvider)
              .fetchCurrentAccess();
      await _clearActiveAdvancedThemeWhenAccessRevoked(ref, snapshot);
      return snapshot;
    });

Future<void> _clearActiveAdvancedThemeWhenAccessRevoked(
  Ref ref,
  MembershipAccessSnapshot snapshot,
) async {
  if (!snapshot.hasExplicitMembershipState || snapshot.hasThemeCustom) {
    return;
  }
  final activeThemeId =
      await ref.read(advancedThemeServiceProvider).loadActiveThemeId();
  if (activeThemeId == null || activeThemeId.trim().isEmpty) {
    return;
  }
  await ref.read(activeAdvancedThemeIdProvider.notifier).disable();
  ref.read(advancedThemeRevisionProvider.notifier).markChanged();
}

final appAuthAccountLifecycleCoordinatorProvider =
    Provider<AuthAccountLifecycleCoordinator>((ref) {
      final sessionService = ref.watch(
        mine_providers.minePageSessionServiceProvider,
      );
      final cacheCoordinator = ref.watch(appCacheCoordinatorProvider);
      return AuthAccountLifecycleCoordinator(
        clearAccountScopedCache: (userId) async {
          await sessionService.clearUserScopedCache(userId);
          await cacheCoordinator.clearUserScoped(owner: userId);
        },
        refreshCurrentAccountData: () async {
          await sessionService.loadSession(refreshRemote: true);
        },
        notifyAccountDataChanged: () {
          ref
              .read(
                mine_providers
                    .mineRemoteAccessSnapshotRevisionProvider
                    .notifier,
              )
              .update((value) => value + 1);
        },
      );
    });

final bookPresentationQueryServiceProvider =
    Provider<BookPresentationQueryService>((ref) {
      return BookPresentationQueryService(
        bookMetadataOverrideRepository: ref.watch(
          bookMetadataOverrideRepositoryProvider,
        ),
      );
    });

typedef AppLifecycleCoordinatorFactory = AppLifecycleCoordinator Function();

final appLifecycleCoordinatorFactoryProvider =
    Provider<AppLifecycleCoordinatorFactory>((ref) {
      final authTokenRefresher = AuthTokenRefresherImpl(
        authService: ref.watch(auth_providers.authServiceProvider),
        sessionStore: ref.watch(auth_providers.authSessionStoreProvider),
      );
      return () => AppLifecycleCoordinator(
        incomingExternalImportStream:
            ref.watch(appExternalImportBridgeProvider).payloadStream,
        authEventStream: ref.watch(appAuthEventStreamProvider),
        initializeExternalImportBridge:
            ref.watch(appExternalImportBridgeProvider).initialize,
        authTokenRefresher: authTokenRefresher,
        sessionChangeListeners: <SessionChangeListener>[
          SearchHistorySessionListener(),
          ReaderSessionListener(),
          const PrivateBookSourceSessionListener(),
        ],
      );
    });

typedef AppAnnouncementCoordinatorFactory =
    AppAnnouncementCoordinator Function();

final appAnnouncementCoordinatorFactoryProvider =
    Provider<AppAnnouncementCoordinatorFactory>((ref) {
      return () => AppAnnouncementCoordinator();
    });

typedef AppStartupCoordinatorFactory =
    AppStartupCoordinator Function({
      required Future<void> Function() sendHeartbeat,
      required Future<void> Function() sendVisitEvent,
      required Future<void> Function() validateStartupAuthSession,
      required VoidCallback showStartupAnnouncementIfNeeded,
      required Future<BuildContext?> Function() resolveDialogContext,
      required StartupUpdateDialogPresenter showUpdateDialog,
    });

final appStartupCoordinatorFactoryProvider =
    Provider<AppStartupCoordinatorFactory>((ref) {
      return ({
        required Future<void> Function() sendHeartbeat,
        required Future<void> Function() sendVisitEvent,
        required Future<void> Function() validateStartupAuthSession,
        required VoidCallback showStartupAnnouncementIfNeeded,
        required Future<BuildContext?> Function() resolveDialogContext,
        required StartupUpdateDialogPresenter showUpdateDialog,
      }) {
        return AppStartupCoordinator(
          sendHeartbeat: sendHeartbeat,
          sendVisitEvent: sendVisitEvent,
          validateStartupAuthSession: validateStartupAuthSession,
          showStartupAnnouncementIfNeeded: showStartupAnnouncementIfNeeded,
          resolveDialogContext: resolveDialogContext,
          showUpdateDialog: showUpdateDialog,
        );
      };
    });
