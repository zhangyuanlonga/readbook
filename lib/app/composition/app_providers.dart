import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_event_bus.dart';
import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/local_book_repository_impl.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../../features/source/application/external_source_import_bridge.dart';
import '../../features/source/application/source_health_service.dart';
import '../../features/book/application/book_presentation_query_service.dart';
import '../../features/source/application/remote_content_task_scheduler_service.dart';
import '../../features/source/application/remote_content_task_conflict_service.dart';
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
  return SourceHealthService.instance;
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
      return () => AppLifecycleCoordinator(
        incomingExternalImportStream:
            ref.watch(appExternalImportBridgeProvider).payloadStream,
        authEventStream: ref.watch(appAuthEventStreamProvider),
        initializeExternalImportBridge:
            ref.watch(appExternalImportBridgeProvider).initialize,
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
      required VoidCallback showStartupAnnouncementIfNeeded,
      required Future<BuildContext?> Function() resolveDialogContext,
      required StartupUpdateDialogPresenter showUpdateDialog,
    });

final appStartupCoordinatorFactoryProvider =
    Provider<AppStartupCoordinatorFactory>((ref) {
      return ({
        required Future<void> Function() sendHeartbeat,
        required Future<void> Function() sendVisitEvent,
        required VoidCallback showStartupAnnouncementIfNeeded,
        required Future<BuildContext?> Function() resolveDialogContext,
        required StartupUpdateDialogPresenter showUpdateDialog,
      }) {
        return AppStartupCoordinator(
          sendHeartbeat: sendHeartbeat,
          sendVisitEvent: sendVisitEvent,
          showStartupAnnouncementIfNeeded: showStartupAnnouncementIfNeeded,
          resolveDialogContext: resolveDialogContext,
          showUpdateDialog: showUpdateDialog,
        );
      };
    });
