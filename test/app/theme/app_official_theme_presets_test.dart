import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/app/theme/app_official_theme_presets.dart';
import 'package:shuxiang_reading_next/app/theme/app_theme_palette.dart';

void main() {
  test('resolves official theme ids and falls back to lumina', () {
    expect(
      appOfficialThemePresetIdFromThemeId('official:mono-blue'),
      AppOfficialThemePresetId.monoBlue,
    );
    expect(appOfficialThemePresetIdFromThemeId('custom:theme'), isNull);
    expect(
      appOfficialThemePresetIdFromString('missing'),
      AppOfficialThemePresetId.lumina,
    );
  });

  test('lumina official preset exposes light and dark configs', () {
    final preset = appOfficialThemePresetById(AppOfficialThemePresetId.lumina);
    final snapshot = preset.toAppearanceSnapshot();

    expect(
      preset.id.defaultBaseColorSchemeId,
      AppBaseColorSchemeId.luminaNeutral,
    );
    expect(snapshot.lightConfig?.colors.primaryColorValue, 0xFF1C1B1B);
    expect(snapshot.lightConfig?.colors.primaryContainerColorValue, 0xFFF1F3F5);
    expect(snapshot.darkConfig?.colors.surfaceColorValue, 0xFF151A20);
    expect(snapshot.lightConfig?.componentStyle.globalRadiusScale, 1);
  });

  test('all official presets provide preview swatches and configs', () {
    for (final preset in appOfficialThemePresets) {
      expect(preset.id.themeId, startsWith('official:'));
      expect(preset.previewSwatches, hasLength(4));
      expect(preset.lightConfig.colors.configuredColorCount, greaterThan(8));
      expect(preset.darkConfig.colors.configuredColorCount, greaterThan(8));
    }
  });
}
