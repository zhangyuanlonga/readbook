import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/local_book_repository_impl.dart';
import '../../data/repositories/script_source_repository_impl.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../../domain/repositories/script_source_repository.dart';
import '../../features/book/application/book_presentation_query_service.dart';
import '../../features/source/application/source_runtime_facade.dart';
import '../lifecycle/app_lifecycle_coordinator.dart';
import '../startup/app_announcement_coordinator.dart';
import '../startup/app_startup_coordinator.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
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

final scriptSourceRepositoryProvider = Provider<ScriptSourceRepository>((ref) {
  return ScriptSourceRepositoryImpl(ref.watch(appDatabaseProvider));
});

final appSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return SourceRuntimeFacade(
    scriptSourceRepository: ref.watch(scriptSourceRepositoryProvider),
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
      return () => AppLifecycleCoordinator();
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
