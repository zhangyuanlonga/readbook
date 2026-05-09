import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/app/theme/app_interface_typography_provider.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_provider.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_seed_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    AppThemeModeNotifier.prime(prefs);
    AppSeedColorNotifier.prime(prefs);
    AppInterfaceFontSettingsNotifier.prime(prefs);
    AppInterfaceTextScaleNotifier.prime(prefs);
    AppInterfaceFontWeightNotifier.prime(prefs);
  });

  test('theme mode persists through app theme provider', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(appThemeModeProvider.notifier)
        .setThemeMode(ThemeMode.dark);

    expect(container.read(appThemeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app.themeMode'), 'dark');
  });

  test('theme mode defaults to following system when unset', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appThemeModeProvider), ThemeMode.system);
  });

  test('seed color persists through app seed color provider', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    const color = Color(0xFF102030);
    await container.read(appSeedColorProvider.notifier).setSeedColor(color);

    expect(container.read(appSeedColorProvider), color);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('app.seedColor'), color.toARGB32());
  });

  test(
    'interface typography providers persist system font, scale, weight',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(appInterfaceFontSettingsProvider.notifier)
          .setSystemFont(AppInterfaceSystemFontPreset.serif);
      await container
          .read(appInterfaceTextScaleProvider.notifier)
          .setScale(1.2);
      await container
          .read(appInterfaceFontWeightProvider.notifier)
          .setWeight(700);

      expect(
        container.read(appInterfaceFontSettingsProvider).systemFontPreset,
        AppInterfaceSystemFontPreset.serif,
      );
      expect(container.read(appInterfaceTextScaleProvider), 1.2);
      expect(container.read(appInterfaceFontWeightProvider), 700);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app.interfaceFont.source'), 'system');
      expect(prefs.getString('app.interfaceFont.systemPreset'), 'serif');
      expect(prefs.getDouble('app.interfaceTextScale'), 1.2);
      expect(prefs.getInt('app.interfaceFontWeight'), 700);
    },
  );
}
