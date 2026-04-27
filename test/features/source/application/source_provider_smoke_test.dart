import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/source/application/source_login_browser_service.dart';
import 'package:shuxiang_reading_next/features/source/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test(
    'source providers expose coordinator factory and login runtime service',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final factory = container.read(sourcePageFlowCoordinatorFactoryProvider);
      final first = factory();
      final second = factory();
      final runtimeService = container.read(sourceLoginRuntimeServiceProvider);
      const browserService = SourceLoginBrowserService();

      expect(first, isNot(same(second)));
      expect(runtimeService, isNotNull);
      expect(browserService, isA<SourceLoginBrowserService>());
    },
  );
}
