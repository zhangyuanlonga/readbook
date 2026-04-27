import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/app_database.dart';
import '../../data/repositories/book_metadata_override_repository_impl.dart';
import '../../data/repositories/local_book_repository_impl.dart';
import '../../domain/repositories/book_metadata_override_repository.dart';
import '../../domain/repositories/local_book_repository.dart';
import '../source/application/source_runtime_facade.dart';
import '../source/application/source_runtime_task_conflict_service.dart';
import 'application/bookshelf_external_import_coordinator.dart';
import 'application/bookshelf_presentation_query_service.dart';

final bookshelfDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

final bookshelfLocalBookRepositoryProvider = Provider<LocalBookRepository>((
  ref,
) {
  return LocalBookRepositoryImpl(ref.watch(bookshelfDatabaseProvider));
});

final bookshelfMetadataOverrideRepositoryProvider =
    Provider<BookMetadataOverrideRepository>((ref) {
      return BookMetadataOverrideRepositoryImpl(
        ref.watch(bookshelfDatabaseProvider),
      );
    });

final bookshelfSourceRuntimeFacadeProvider = Provider<SourceRuntimeFacade>((
  ref,
) {
  return SourceRuntimeFacade.instance;
});

final bookshelfTaskConflictServiceProvider =
    Provider<SourceRuntimeTaskConflictService>((ref) {
      return SourceRuntimeTaskConflictService.instance;
    });

final bookshelfPresentationQueryServiceProvider =
    Provider<BookshelfPresentationQueryService>((ref) {
      return BookshelfPresentationQueryService(
        database: ref.watch(bookshelfDatabaseProvider),
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
