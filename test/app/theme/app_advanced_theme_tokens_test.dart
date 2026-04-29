import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_advanced_theme_tokens.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test(
    'infers readable text colors from overridden dark surface in light mode',
    () {
      final colorScheme = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      );
      final palette = resolveAdvancedThemePaletteFromModeConfig(
        colorScheme,
        AppAdvancedThemeModeConfig(
          colors: AppAdvancedThemeColors(
            backgroundColorValue: 0xFF141414,
            surfaceColorValue: 0xFF181818,
            searchFieldBackgroundColorValue: 0xFF222222,
            cardColorValue: 0xFF1C1C1C,
          ),
        ),
      );

      expect(palette.textPrimaryColor.computeLuminance(), greaterThan(0.7));
      expect(palette.buttonTextColor.computeLuminance(), greaterThan(0.7));
    },
  );
}
