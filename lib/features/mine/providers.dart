import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../bookshelf/application/bookshelf_service.dart';
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
