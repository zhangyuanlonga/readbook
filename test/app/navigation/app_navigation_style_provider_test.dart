import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/app_navigation_style_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    AppStandardNavigationBarAppearanceNotifier.prime(prefs);
  });

  test(
    'standard navigation appearance defaults to non-floating and non-frosted',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appStandardNavigationBarAppearanceProvider),
        const AppStandardNavigationBarAppearance(),
      );
    },
  );

  test('standard navigation appearance prime reads persisted flags', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.navigation.standard.floatingBar': true,
      'app.navigation.standard.frostedEffect': true,
    });
    final prefs = await SharedPreferences.getInstance();

    AppStandardNavigationBarAppearanceNotifier.prime(prefs);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(appStandardNavigationBarAppearanceProvider),
      const AppStandardNavigationBarAppearance(
        floatingBar: true,
        frostedEffect: true,
      ),
    );
  });

  test('standard navigation appearance persists changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appStandardNavigationBarAppearanceProvider.notifier)
        .setFloatingBar(true);
    await container
        .read(appStandardNavigationBarAppearanceProvider.notifier)
        .setFrostedEffect(true);

    expect(
      container.read(appStandardNavigationBarAppearanceProvider),
      const AppStandardNavigationBarAppearance(
        floatingBar: true,
        frostedEffect: true,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('app.navigation.standard.floatingBar'), isTrue);
    expect(prefs.getBool('app.navigation.standard.frostedEffect'), isTrue);
  });

  test(
    'cupertino dock appearance defaults and persists frosted effect',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(appCupertinoDockAppearanceProvider),
        const AppCupertinoDockAppearance(),
      );

      await container
          .read(appCupertinoDockAppearanceProvider.notifier)
          .setFrostedEffect(true);

      expect(
        container.read(appCupertinoDockAppearanceProvider),
        const AppCupertinoDockAppearance(frostedEffect: true),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('app.navigation.cupertinoDock.frostedEffect'),
        isTrue,
      );
    },
  );
}
