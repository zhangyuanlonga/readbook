import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/navigation/app_navigation_style_provider.dart';

void main() {
  group('AppNavigationStylePreferenceNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to followSystem', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appNavigationStylePreferenceProvider);
      expect(state, AppNavigationStylePreference.followSystem);
    });

    test('persists selected navigation style preference', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appNavigationStylePreferenceProvider.notifier)
          .setPreference(AppNavigationStylePreference.cupertinoDock);

      final updated = container.read(appNavigationStylePreferenceProvider);
      expect(updated, AppNavigationStylePreference.cupertinoDock);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app.navigationStyle'), 'cupertinoDock');
    });

    test('persists navigation label visibility', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appNavigationLabelVisibilityProvider.notifier)
          .setVisible(false);

      final updated = container.read(appNavigationLabelVisibilityProvider);
      expect(updated, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('app.navigation.showLabels'), isFalse);
    });
  });

  group('resolveAppNavigationStyle', () {
    test('follows Android system style with standard navigation', () {
      final style = resolveAppNavigationStyle(
        AppNavigationStylePreference.followSystem,
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(style, AppNavigationStyle.standard);
    });

    test('follows iOS system style with cupertino dock navigation', () {
      final style = resolveAppNavigationStyle(
        AppNavigationStylePreference.followSystem,
        isWeb: false,
        platform: TargetPlatform.iOS,
      );

      expect(style, AppNavigationStyle.cupertinoDock);
    });

    test('falls back to standard navigation on unsupported platforms', () {
      final desktopStyle = resolveAppNavigationStyle(
        AppNavigationStylePreference.cupertinoDock,
        isWeb: false,
        platform: TargetPlatform.macOS,
      );
      final webStyle = resolveAppNavigationStyle(
        AppNavigationStylePreference.cupertinoDock,
        isWeb: true,
        platform: TargetPlatform.iOS,
      );

      expect(desktopStyle, AppNavigationStyle.standard);
      expect(webStyle, AppNavigationStyle.standard);
    });
  });
}
