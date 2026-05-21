import 'package:flutter_test/flutter_test.dart';

import 'package:shuxiang_reading_next/domain/entities/app_advanced_theme.dart';
import 'package:shuxiang_reading_next/features/mine/application/advanced_theme_service.dart';

void main() {
  test(
    'AdvancedThemeModeSummary keeps component style and preview color fields',
    () {
      const style = AppAdvancedThemeComponentStyle(
        globalRadiusScale: 1.18,
        shadowStrength: 0.76,
        cardStyle: AppAdvancedThemeCardStyle.elevated,
        buttonStyle: AppAdvancedThemeButtonStyle.rounded,
        inputStyle: AppAdvancedThemeInputStyle.outlined,
        overlayStyle: AppAdvancedThemeOverlayStyle.compact,
        navigationStyle: AppAdvancedThemeNavigationStyle.floating,
        switchStyle: AppAdvancedThemeSwitchStyle.contrast,
      );
      final summary = AdvancedThemeModeSummary.fromConfig(
        AppAdvancedThemeModeConfig(
          componentStyle: style,
          colors: const AppAdvancedThemeColors(
            primaryColorValue: 0xFF123456,
            backgroundColorValue: 0xFFF5F1E8,
            surfaceColorValue: 0xFFF0E9DC,
            cardColorValue: 0xFFFFFFFF,
            cardTextColorValue: 0xFF1C1C1C,
            textSecondaryColorValue: 0xFF606060,
          ),
        ),
      );

      expect(summary.componentStyle.globalRadiusScale, 1.18);
      expect(summary.componentStyle.shadowStrength, 0.76);
      expect(
        summary.componentStyle.cardStyle,
        AppAdvancedThemeCardStyle.elevated,
      );
      expect(
        summary.componentStyle.buttonStyle,
        AppAdvancedThemeButtonStyle.rounded,
      );
      expect(summary.primaryColorValue, 0xFF123456);
      expect(summary.backgroundColorValue, 0xFFF5F1E8);
      expect(summary.configuredColorCount, 6);
    },
  );
}
