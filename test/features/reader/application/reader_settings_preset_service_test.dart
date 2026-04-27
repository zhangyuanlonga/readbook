import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_preset_service.dart';

void main() {
  group('ReaderSettingsPresetService', () {
    const service = ReaderSettingsPresetService();

    test('applies typography preset without touching unrelated fields', () {
      const base = ReaderSettings(brightness: 0.72, autoReadEnabled: true);

      final next = service.applyTypographyPreset(
        base,
        ReaderTypographyPreset.md3Comfortable,
      );

      expect(next.brightness, 0.72);
      expect(next.autoReadEnabled, isTrue);
      expect(next.fontSize, 19);
      expect(next.lineHeight, 1.74);
      expect(next.fontWeightLevel, ReaderFontWeightLevel.medium);
      expect(next.textFullJustifyEnabled, isTrue);
    });

    test('applies spacing preset to paragraph spacing and indent', () {
      final next = service.applySpacingPreset(
        const ReaderSettings(paragraphSpacing: 9, paragraphIndent: 0),
        ReaderSpacingPreset.relaxed,
      );

      expect(next.paragraphSpacing, 3);
      expect(next.paragraphIndent, 2);
    });

    test('applies chapter header preset to chapter header semantics', () {
      final next = service.applyChapterHeaderPreset(
        const ReaderSettings(),
        ReaderChapterHeaderPreset.immersive,
      );

      expect(next.chapterHeaderMode, ReaderChapterHeaderMode.center);
      expect(next.chapterHeaderTopSpacing, 8);
      expect(next.chapterHeaderBottomSpacing, 6);
    });

    test('applies info style preset to header and footer presentation', () {
      final next = service.applyInfoStylePreset(
        const ReaderSettings(
          infoHeaderEnabled: true,
          infoFooterEnabled: false,
          infoShowProgress: false,
        ),
        ReaderInfoStylePreset.minimalFooter,
      );

      expect(next.infoHeaderEnabled, isFalse);
      expect(next.infoFooterEnabled, isTrue);
      expect(next.infoShowTime, isTrue);
      expect(next.infoShowProgress, isTrue);
    });

    test('applies font preset and clears custom font linkage', () {
      final next = service.applyFontPreset(
        const ReaderSettings(
          fontSource: ReaderFontSource.custom,
          fontFamilyKey: 'reader_font',
          customFontPath: '/tmp/reader_font.ttf',
        ),
        ReaderFontPreset.systemMonospace,
      );

      expect(next.fontSource, ReaderFontSource.system);
      expect(next.systemFontPreset, ReaderSystemFontPreset.monospace);
      expect(next.fontFamilyKey, isNull);
      expect(next.customFontPath, isNull);
    });
  });
}
