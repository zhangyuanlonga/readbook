import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_external_import_coordinator.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('bookshelf providers expose query service and coordinator factory', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final queryService = container.read(
      bookshelfPresentationQueryServiceProvider,
    );
    final dependencies = container.read(bookshelfPageDependenciesProvider);
    final localImportService = container.read(localBookImportServiceProvider);
    final factory = container.read(
      bookshelfExternalImportCoordinatorFactoryProvider,
    );
    final first = factory();
    final second = factory();

    expect(queryService, isA<BookshelfPresentationQueryService>());
    expect(dependencies, isA<BookshelfPageDependencies>());
    expect(localImportService, isA<LocalBookImportService>());
    expect(first, isA<BookshelfExternalImportCoordinator>());
    expect(first, isNot(same(second)));
  });
}
