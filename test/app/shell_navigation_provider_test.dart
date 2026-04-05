import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppShellNavigationNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to showing all tabs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appShellNavigationProvider);
      expect(state.showBookshelf, isTrue);
      expect(state.showDiscover, isTrue);
      expect(state.visibleTabCount, 3);
    });

    test('persists configurable tab visibility', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(AppShellTab.discover, false);

      final updated = container.read(appShellNavigationProvider);
      expect(updated.showDiscover, isFalse);
      expect(updated.visibleTabCount, 2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app.shell.navigation.discover'), isFalse);
    });

    test('keeps mine tab always visible', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(AppShellTab.mine, false);

      final state = container.read(appShellNavigationProvider);
      expect(state.visibleTabCount, 3);
    });
  });
}
