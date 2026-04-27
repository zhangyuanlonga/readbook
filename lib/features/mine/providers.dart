import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/composition/app_providers.dart' as app_providers;
import '../../core/app_update/app_update_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/media/image_selection_service.dart';
import '../../core/membership/membership_service.dart';
import '../../core/mobile_features/mobile_feature_service.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../bookshelf/application/bookshelf_service.dart';
import 'application/advanced_theme_page_flow_coordinator.dart';
import 'application/bookmarks_query_service.dart';
import 'application/cache_management_service.dart';
import 'application/mine_page_flow_coordinator.dart';
import 'application/reader_background_service.dart';

final mineBookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

final mineBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return ref.watch(app_providers.bookmarkRepositoryProvider);
});

final cacheManagementServiceProvider = Provider<CacheManagementService>((ref) {
  return CacheManagementService(
    bookshelfService: ref.watch(mineBookshelfServiceProvider),
    database: ref.watch(app_providers.appDatabaseProvider),
  );
});

final bookmarksQueryServiceProvider = Provider<BookmarksQueryService>((ref) {
  return BookmarksQueryService(
    bookmarkRepository: ref.watch(mineBookmarkRepositoryProvider),
    bookshelfService: ref.watch(mineBookshelfServiceProvider),
  );
});

final mineAuthSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore();
});

final mineUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final mineMobileFeatureServiceProvider = Provider<MobileFeatureService>((ref) {
  return MobileFeatureService();
});

final mineMembershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService();
});

final mineImageSelectionServiceProvider = Provider<ImageSelectionService>((
  ref,
) {
  return ImageSelectionService();
});

final readerBackgroundServiceProvider = Provider<ReaderBackgroundService>((
  ref,
) {
  return ReaderBackgroundService();
});

typedef MinePageFlowCoordinatorFactory = MinePageFlowCoordinator Function();

final minePageFlowCoordinatorProvider =
    Provider<MinePageFlowCoordinatorFactory>((ref) {
      return () => MinePageFlowCoordinator();
    });

typedef AdvancedThemePageFlowCoordinatorFactory =
    AdvancedThemePageFlowCoordinator Function();

final advancedThemePageFlowCoordinatorFactoryProvider =
    Provider<AdvancedThemePageFlowCoordinatorFactory>((ref) {
      return () => AdvancedThemePageFlowCoordinator();
    });
