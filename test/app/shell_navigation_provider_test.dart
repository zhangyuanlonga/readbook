import 'package:shuxiang_reading_next/app/shell_navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppShellNavigationState', () {
    test('uses generated copyWith and value equality', () {
      final state = const AppShellNavigationState().copyWith(showStats: true);

      expect(state, const AppShellNavigationState(showStats: true));
      expect(state.visibleTabCount, 3);
    });
  });

  group('AppShellNavigationNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to showing bookshelf and mine tabs', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appShellNavigationProvider);
      expect(state.showBookshelf, isTrue);
      expect(state.showDiscover, isFalse);
      expect(state.showStats, isFalse);
      expect(state.visibleTabCount, 2);
    });

    test('persists configurable tab visibility', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(AppShellTab.discover, true);

      final updated = container.read(appShellNavigationProvider);
      expect(updated.showDiscover, isTrue);
      expect(updated.visibleTabCount, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app.shell.navigation.discover'), isTrue);
    });

    test('persists stats tab visibility', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(AppShellTab.stats, true);

      final updated = container.read(appShellNavigationProvider);
      expect(updated.showStats, isTrue);
      expect(updated.visibleTabCount, 3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app.shell.navigation.stats'), isTrue);
    });

    test('keeps mine tab always visible', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appShellNavigationProvider.notifier)
          .setTabVisible(AppShellTab.mine, false);

      final state = container.read(appShellNavigationProvider);
      expect(state.visibleTabCount, 2);
    });
  });
}
