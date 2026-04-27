import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/membership/membership_service.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../bookshelf/application/bookshelf_service.dart';
import 'application/advanced_theme_page_flow_coordinator.dart';
import 'application/bookmarks_query_service.dart';
import 'application/cache_management_service.dart';

final mineDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final mineBookshelfServiceProvider = Provider<BookshelfService>((ref) {
  return BookshelfService();
});

final mineBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl(ref.watch(mineDatabaseProvider));
});

final cacheManagementServiceProvider = Provider<CacheManagementService>((ref) {
  return CacheManagementService(
    bookshelfService: ref.watch(mineBookshelfServiceProvider),
    database: ref.watch(mineDatabaseProvider),
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

final mineMembershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService();
});

typedef AdvancedThemePageFlowCoordinatorFactory =
    AdvancedThemePageFlowCoordinator Function();

final advancedThemePageFlowCoordinatorFactoryProvider =
    Provider<AdvancedThemePageFlowCoordinatorFactory>((ref) {
      return () => AdvancedThemePageFlowCoordinator();
    });
