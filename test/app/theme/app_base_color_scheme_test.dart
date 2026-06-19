import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/preferences/app_preferences_service.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_seed_provider.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_source_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    AppBaseColorSchemeNotifier.prime(prefs);
    AppSeedColorNotifier.prime(prefs);
  });

  test('maps legacy seed colors to base color schemes', () {
    expect(
      appBaseColorSchemeIdFromSeed(appThemeSeaBlueOption.color),
      AppBaseColorSchemeId.monoBlue,
    );
    expect(
      appBaseColorSchemeIdFromSeed(appThemePineGreenOption.color),
      AppBaseColorSchemeId.inkGreen,
    );
    expect(
      appBaseColorSchemeIdFromSeed(appThemeSeluneOption.color),
      AppBaseColorSchemeId.seluneWarm,
    );
    expect(
      appBaseColorSchemeIdFromSeed(appThemeSnowWhiteOption.color),
      AppBaseColorSchemeId.luminaNeutral,
    );
  });

  test('base color scheme provider persists selected id', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appBaseColorSchemeProvider.notifier)
        .setBaseColorScheme(AppBaseColorSchemeId.inkGreen);

    expect(
      container.read(appBaseColorSchemeProvider),
      AppBaseColorSchemeId.inkGreen,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(appBaseColorSchemePreferenceKey),
      AppBaseColorSchemeId.inkGreen.id,
    );
  });

  test(
    'legacy seed setter also updates base color scheme compatibility',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appSeedColorProvider.notifier)
          .setSeedColor(appThemeSeaBlueOption.color);

      expect(
        container.read(appBaseColorSchemeProvider),
        AppBaseColorSchemeId.monoBlue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(appBaseColorSchemePreferenceKey),
        AppBaseColorSchemeId.monoBlue.id,
      );
    },
  );

  test('lumina base color scheme uses charcoal primary instead of blue', () {
    final lightScheme = buildAppBaseLightColorScheme(
      AppBaseColorSchemeId.luminaNeutral,
    );
    final darkScheme = buildAppBaseDarkColorScheme(
      AppBaseColorSchemeId.luminaNeutral,
    );

    expect(lightScheme.primary, const Color(0xFF1C1B1B));
    expect(lightScheme.primaryContainer, const Color(0xFFF1F3F5));
    expect(lightScheme.surfaceContainerLow, const Color(0xFFF8FAFC));
    expect(darkScheme.surface, const Color(0xFF161A20));
    expect(darkScheme.primaryContainer, const Color(0xFF2B323C));
  });
}
