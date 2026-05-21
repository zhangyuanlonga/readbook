import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/app/theme/app_component_theme_tokens.dart';
import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';

void main() {
  test('resolveAppComponentThemeTokens provides stable defaults', () {
    final tokens = resolveAppComponentThemeTokens(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF336699),
        brightness: Brightness.light,
      ),
    );

    expect(tokens.card.radius, 20);
    expect(tokens.button.shapeStyle, AppButtonShapeStyle.stadium);
    expect(tokens.input.radius, 14);
    expect(tokens.overlay.topRadius, 20);
    expect(tokens.navigation.standardHeightWithLabel, 72);
    expect(tokens.selection.switchTrackOutlineWidth, 0.8);
  });

  test(
    'resolveAppComponentThemeTokensFromModeConfig maps component style to tokens',
    () {
      final tokens = resolveAppComponentThemeTokensFromModeConfig(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF336699),
          brightness: Brightness.dark,
        ),
        modeConfig: AppAdvancedThemeModeConfig(
          componentStyle: const AppAdvancedThemeComponentStyle(
            globalRadiusScale: 1.2,
            shadowStrength: 0.8,
            cardStyle: AppAdvancedThemeCardStyle.elevated,
            buttonStyle: AppAdvancedThemeButtonStyle.rounded,
            inputStyle: AppAdvancedThemeInputStyle.outlined,
            overlayStyle: AppAdvancedThemeOverlayStyle.compact,
            navigationStyle: AppAdvancedThemeNavigationStyle.floating,
            switchStyle: AppAdvancedThemeSwitchStyle.contrast,
          ),
        ),
      );

      expect(tokens.card.elevation, 1);
      expect(tokens.card.borderWidth, 0.8);
      expect(tokens.button.shapeStyle, AppButtonShapeStyle.rounded);
      expect(tokens.button.radius, greaterThan(10));
      expect(tokens.input.borderWidth, 1.15);
      expect(tokens.overlay.shadowBlur, 12);
      expect(tokens.navigation.standardFloatingShadowBlur, 24);
      expect(tokens.selection.switchTrackOutlineWidth, 1.1);
      expect(tokens.selection.segmentBorderWidth, 1.1);
    },
  );
}
