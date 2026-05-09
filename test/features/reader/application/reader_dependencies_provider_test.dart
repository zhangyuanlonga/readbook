import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_dependencies_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readerFeatureDependenciesFactoryProvider', () {
    test('reuses app-level database and repository providers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dependencies =
          container.read(readerFeatureDependenciesFactoryProvider)();

      expect(
        identical(
          dependencies.localBookRepository,
          container.read(localBookRepositoryProvider),
        ),
        isTrue,
      );
      expect(
        identical(
          dependencies.bookmarkRepository,
          container.read(bookmarkRepositoryProvider),
        ),
        isTrue,
      );
      expect(
        identical(
          dependencies.bookMetadataOverrideRepository,
          container.read(bookMetadataOverrideRepositoryProvider),
        ),
        isTrue,
      );
    });
  });
}
