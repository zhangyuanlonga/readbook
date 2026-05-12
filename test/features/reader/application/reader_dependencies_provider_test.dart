import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/app/platform/app_platform_capabilities.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_dependencies_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

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

    test(
      'omits online source content provider when source runtime is disabled',
      () {
        final disabledContainer = ProviderContainer();
        addTearDown(disabledContainer.dispose);

        final disabledDependencies =
            disabledContainer.read(readerFeatureDependenciesFactoryProvider)();
        expect(
          disabledDependencies.contentProviderRegistry.findForSourceId(
            'online_source',
          ),
          isNull,
        );
        expect(
          disabledDependencies.contentProviderRegistry.findForSourceId(
            '__local_book__',
          ),
          isNotNull,
        );
      },
    );

    test('keeps online source content provider behind capability opt-in', () {
      final enabledContainer = ProviderContainer(
        overrides: [
          appCapabilitiesProvider.overrideWith(
            (ref) =>
                AppPlatformCapabilities.current(sourceRuntimeEnabled: true),
          ),
        ],
      );
      addTearDown(enabledContainer.dispose);

      final enabledDependencies =
          enabledContainer.read(readerFeatureDependenciesFactoryProvider)();

      expect(
        enabledDependencies.contentProviderRegistry.findForSourceId(
          'online_source',
        ),
        isNotNull,
      );
    });
  });
}
