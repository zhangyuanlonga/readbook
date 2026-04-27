import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../data/repositories/local_book_repository_impl.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../source/application/source_runtime_facade.dart';
import '../source/application/source_runtime_scheduler_service.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/book_local_metadata_service.dart';

final bookDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final bookBookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl(ref.watch(bookDatabaseProvider));
});

final bookMetadataOverrideRepositoryProvider =
    Provider<BookMetadataOverrideRepository>((ref) {
      return BookMetadataOverrideRepositoryImpl(
        ref.watch(bookDatabaseProvider),
      );
    });

final bookLocalBookRepositoryProvider = Provider<LocalBookRepository>((ref) {
  return LocalBookRepositoryImpl(ref.watch(bookDatabaseProvider));
});

final bookSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((ref) {
  return SourceRuntimeFacade.instance;
});

final bookTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return SourceRuntimeTaskConflictService.instance;
    });

final bookTaskSchedulerProvider = Provider<SourceRuntimeSchedulerService>((
  ref,
) {
  return SourceRuntimeSchedulerService.instance;
});

final bookLocalMetadataServiceProvider = Provider<BookLocalMetadataService>((
  ref,
) {
  return BookLocalMetadataService(
    localBookRepository: ref.watch(bookLocalBookRepositoryProvider),
  );
});
