import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/preferences/app_preferences_service.dart';
import 'package:shuxiang_reading_next/app/preferences/app_shell_navigation_snapshot.dart';

void main() {
  group('AppShellNavigationPreferencesService', () {
    test(
      'loads typed defaults while keeping discover hidden by default',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = AppShellNavigationPreferencesService(
          preferences: prefs,
        );

        final snapshot = await service.loadShellNavigation();

        expect(snapshot.showHome, isTrue);
        expect(snapshot.showBookshelf, isTrue);
        expect(snapshot.showDiscover, isFalse);
        expect(snapshot.showStats, isTrue);
      },
    );

    test(
      'saves to existing SharedPreferences keys for compatibility',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final service = AppShellNavigationPreferencesService(
          preferences: prefs,
        );

        await service.saveShellNavigation(
          const AppShellNavigationSnapshot(
            showHome: true,
            showBookshelf: false,
            showDiscover: true,
            showStats: false,
          ),
        );

        expect(prefs.getBool(appShellNavigationHomePreferenceKey), isTrue);
        expect(
          prefs.getBool(appShellNavigationBookshelfPreferenceKey),
          isFalse,
        );
        expect(prefs.getBool(appShellNavigationDiscoverPreferenceKey), isTrue);
        expect(prefs.getBool(appShellNavigationStatsPreferenceKey), isFalse);
        expect(prefs.getBool(appShellNavigationSourcePreferenceKey), isNull);
      },
    );
  });
}
