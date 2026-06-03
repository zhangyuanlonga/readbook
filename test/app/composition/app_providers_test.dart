import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/composition/app_providers.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_dependencies_provider.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('appSourceHealthServiceProvider', () {
    test('creates a provider-managed service instead of reusing singleton', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(appSourceHealthServiceProvider);

      expect(service, isA<SourceHealthService>());
      expect(identical(service, SourceHealthService.instance), isFalse);
    });

    test('can be overridden for feature dependency factories', () {
      final sourceHealthService = SourceHealthService();
      final container = ProviderContainer(
        overrides: <Override>[
          appSourceHealthServiceProvider.overrideWithValue(sourceHealthService),
        ],
      );
      addTearDown(container.dispose);

      final dependencies =
          container.read(readerFeatureDependenciesFactoryProvider)();

      expect(dependencies.sourceHealthService, same(sourceHealthService));
    });
  });
}
