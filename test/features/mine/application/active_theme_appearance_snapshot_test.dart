import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/active_theme_appearance_snapshot.dart';

void main() {
  group('ActiveThemeAppearanceSnapshot', () {
    test('supports toJson and fromJson with trimmed font family key', () {
      final snapshot = ActiveThemeAppearanceSnapshot(
        lightConfig: AppAdvancedThemeModeConfig(
          colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF336699),
        ),
        darkConfig: AppAdvancedThemeModeConfig(
          colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF112233),
        ),
        themeEffect: AppAdvancedThemeEffect.firefly,
        appInterfaceFontFamilyKey: ' font_ui_snapshot ',
      );

      final restored = ActiveThemeAppearanceSnapshot.fromJson(
        snapshot.toJson(),
      );

      expect(restored.appInterfaceFontFamilyKey, 'font_ui_snapshot');
      expect(restored.themeEffect, AppAdvancedThemeEffect.firefly);
      expect(restored.lightConfig?.colors.primaryColorValue, 0xFF336699);
      expect(restored.darkConfig?.colors.primaryColorValue, 0xFF112233);
    });

    test('fromTheme mirrors active theme appearance fields', () {
      final theme = AppAdvancedTheme(
        id: 'theme_a',
        name: '主题A',
        createdAt: DateTime.parse('2026-06-03T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-06-03T10:00:00.000Z'),
        lightConfig: AppAdvancedThemeModeConfig(
          colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF445566),
        ),
        darkConfig: AppAdvancedThemeModeConfig(
          colors: const AppAdvancedThemeColors(primaryColorValue: 0xFF223344),
        ),
        themeEffect: AppAdvancedThemeEffect.rain,
        appInterfaceFontFamilyKey: 'font_ui_a',
      );

      final snapshot = ActiveThemeAppearanceSnapshot.fromTheme(theme);

      expect(snapshot.appInterfaceFontFamilyKey, 'font_ui_a');
      expect(snapshot.themeEffect, AppAdvancedThemeEffect.rain);
      expect(snapshot.lightConfig?.colors.primaryColorValue, 0xFF445566);
      expect(snapshot.darkConfig?.colors.primaryColorValue, 0xFF223344);
    });
  });
}
