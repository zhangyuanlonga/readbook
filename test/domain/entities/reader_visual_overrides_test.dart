import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_visual_overrides.dart';

void main() {
  group('ReaderVisualOverrides', () {
    test('serializes sparse override fields', () {
      const overrides = ReaderVisualOverrides(
        hasBackgroundImageOverride: true,
        backgroundImageBase64: 'reader_backgrounds/demo/bg.png',
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.serif,
        hasFontFamilyKeyOverride: true,
        fontFamilyKey: 'reader_font_family',
        hasCustomFontPathOverride: true,
        customFontPath: 'reader_fonts/demo/font.ttf',
      );

      final restored = ReaderVisualOverrides.fromJson(overrides.toJson());

      expect(restored.hasBackgroundImageOverride, isTrue);
      expect(restored.backgroundImageBase64, 'reader_backgrounds/demo/bg.png');
      expect(restored.fontSource, ReaderFontSource.system);
      expect(restored.systemFontPreset, ReaderSystemFontPreset.serif);
      expect(restored.hasFontFamilyKeyOverride, isTrue);
      expect(restored.fontFamilyKey, 'reader_font_family');
      expect(restored.hasCustomFontPathOverride, isTrue);
      expect(restored.customFontPath, 'reader_fonts/demo/font.ttf');
    });

    test('empty override reports empty and supports clear helpers', () {
      const overrides = ReaderVisualOverrides(
        hasBackgroundImageOverride: true,
        backgroundImageBase64: 'foo',
        fontSource: ReaderFontSource.custom,
        hasFontFamilyKeyOverride: true,
        fontFamilyKey: 'bar',
      );

      final cleared = overrides.copyWith(
        clearBackgroundImageOverride: true,
        clearFontSource: true,
        clearFontFamilyKeyOverride: true,
      );

      expect(cleared.isEmpty, isTrue);
      expect(cleared.backgroundImageBase64, isNull);
      expect(cleared.fontSource, isNull);
      expect(cleared.fontFamilyKey, isNull);
    });
  });
}
