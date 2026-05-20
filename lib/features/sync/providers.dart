import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/device/device_identity_service.dart';
import '../../core/logging/app_logger.dart';
import 'application/sync_auto_sync_service.dart';
import 'application/sync_connection_service.dart';
import 'application/sync_profile_service.dart';
import 'application/sync_remote_bootstrap_service.dart';
import 'application/sync_scope_catalog_service.dart';
import 'application/sync_stage4_service.dart';
import 'data/local/sync_local_store.dart';
import 'data/local/sync_secret_store.dart';
import 'domain/sync_conflict.dart';
import 'domain/sync_job.dart';
import 'domain/sync_profile.dart';
import '../bookshelf/application/bookshelf_service.dart';
import '../mine/application/advanced_theme_service.dart';
import '../reader/application/reader_preferences_service.dart';
import '../reader/application/reading_book_status_service.dart';
import '../reader/application/reading_record_service.dart';

final syncScopeCatalogServiceProvider = Provider<SyncScopeCatalogService>((
  ref,
) {
  return const SyncScopeCatalogService();
});

final syncLocalStoreProvider = Provider<SyncLocalStore>((ref) {
  return SyncLocalStore(ref.watch(app_providers.appDatabaseProvider));
});

final syncSecretStoreProvider = Provider<SyncSecretStore>((ref) {
  return FlutterSecureSyncSecretStore();
});

final syncDeviceIdentityServiceProvider = Provider<DeviceIdentityService>((
  ref,
) {
  return DeviceIdentityService();
});

final syncProfileServiceProvider = Provider<SyncProfileService>((ref) {
  return SyncProfileService(
    localStore: ref.watch(syncLocalStoreProvider),
    secretStore: ref.watch(syncSecretStoreProvider),
  );
});

final syncRemoteBootstrapServiceProvider = Provider<SyncRemoteBootstrapService>(
  (ref) {
    return SyncRemoteBootstrapService(
      deviceIdentityService: ref.watch(syncDeviceIdentityServiceProvider),
    );
  },
);

final syncConnectionServiceProvider = Provider<SyncConnectionService>((ref) {
  return SyncConnectionService(
    profileService: ref.watch(syncProfileServiceProvider),
    localStore: ref.watch(syncLocalStoreProvider),
    remoteBootstrapService: ref.watch(syncRemoteBootstrapServiceProvider),
    logger: AppLogger.instance,
  );
});

final syncStage4ServiceProvider = Provider<SyncStage4Service>((ref) {
  return SyncStage4Service(
    profileService: ref.watch(syncProfileServiceProvider),
    localStore: ref.watch(syncLocalStoreProvider),
    remoteBootstrapService: ref.watch(syncRemoteBootstrapServiceProvider),
    readerPreferencesService: ReaderPreferencesService(),
    bookmarkRepository: ref.watch(app_providers.bookmarkRepositoryProvider),
    bookMetadataOverrideRepository: ref.watch(
      app_providers.bookMetadataOverrideRepositoryProvider,
    ),
    readingBookStatusService: ReadingBookStatusService(
      database: ref.watch(app_providers.appDatabaseProvider),
    ),
    readingRecordService: ReadingRecordService(
      database: ref.watch(app_providers.appDatabaseProvider),
    ),
    localBookRepository: ref.watch(app_providers.localBookRepositoryProvider),
    bookshelfService: BookshelfService(),
    advancedThemeService: AdvancedThemeService(),
    logger: AppLogger.instance,
  );
});

final syncProfilesProvider = StreamProvider<List<SyncProfile>>((ref) {
  return ref.watch(syncProfileServiceProvider).watchProfiles();
});

final syncJobsProvider = StreamProvider<List<SyncJob>>((ref) {
  return ref.watch(syncConnectionServiceProvider).watchJobs();
});

final syncConflictsProvider = StreamProvider<List<SyncConflict>>((ref) {
  return ref.watch(syncLocalStoreProvider).watchConflicts();
});

final syncAutoSyncServiceProvider = Provider<SyncAutoSyncService>((ref) {
  return SyncAutoSyncService(
    profileService: ref.watch(syncProfileServiceProvider),
    syncService: ref.watch(syncStage4ServiceProvider),
  );
});
