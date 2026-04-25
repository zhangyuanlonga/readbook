import '../../../domain/entities/reader_settings.dart';

enum ReaderTypographyPreset { md3Balanced, md3Compact, md3Comfortable }

enum ReaderSpacingPreset { compact, balanced, relaxed }

enum ReaderChapterHeaderPreset { standard, compact, immersive }

enum ReaderInfoStylePreset { minimalFooter, balanced, readingFocused }

enum ReaderFontPreset { systemSans, systemSerif, systemMonospace }

class ReaderSettingsPresetService {
  const ReaderSettingsPresetService();

  ReaderSettings applyTypographyPreset(
    ReaderSettings settings,
    ReaderTypographyPreset preset,
  ) {
    return switch (preset) {
      ReaderTypographyPreset.md3Balanced => settings.copyWith(
        fontSize: 18,
        lineHeight: 1.72,
        letterSpacing: 0.02,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.regular,
      ),
      ReaderTypographyPreset.md3Compact => settings.copyWith(
        fontSize: 17,
        lineHeight: 1.62,
        letterSpacing: 0,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.regular,
      ),
      ReaderTypographyPreset.md3Comfortable => settings.copyWith(
        fontSize: 19,
        lineHeight: 1.82,
        letterSpacing: 0.04,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.medium,
      ),
    };
  }

  ReaderSettings applySpacingPreset(
    ReaderSettings settings,
    ReaderSpacingPreset preset,
  ) {
    return switch (preset) {
      ReaderSpacingPreset.compact => settings.copyWith(
        paragraphSpacing: 10,
        paragraphIndent: 2,
      ),
      ReaderSpacingPreset.balanced => settings.copyWith(
        paragraphSpacing: 14,
        paragraphIndent: 2,
      ),
      ReaderSpacingPreset.relaxed => settings.copyWith(
        paragraphSpacing: 18,
        paragraphIndent: 2,
      ),
    };
  }

  ReaderSettings applyChapterHeaderPreset(
    ReaderSettings settings,
    ReaderChapterHeaderPreset preset,
  ) {
    return switch (preset) {
      ReaderChapterHeaderPreset.standard => settings.copyWith(
        pinnedChapterHeaderOffsetX: 0,
        pinnedChapterHeaderOffsetY: 8,
      ),
      ReaderChapterHeaderPreset.compact => settings.copyWith(
        pinnedChapterHeaderOffsetX: 0,
        pinnedChapterHeaderOffsetY: 0,
      ),
      ReaderChapterHeaderPreset.immersive => settings.copyWith(
        pinnedChapterHeaderOffsetX: 0.08,
        pinnedChapterHeaderOffsetY: 18,
      ),
    };
  }

  ReaderSettings applyInfoStylePreset(
    ReaderSettings settings,
    ReaderInfoStylePreset preset,
  ) {
    return switch (preset) {
      ReaderInfoStylePreset.minimalFooter => settings.copyWith(
        infoHeaderEnabled: false,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: false,
        infoShowChapter: false,
        infoShowProgress: true,
        infoHeaderDividerEnabled: false,
        infoFooterDividerEnabled: false,
        infoHeaderPadding: 8,
        infoFooterPadding: 8,
      ),
      ReaderInfoStylePreset.balanced => settings.copyWith(
        infoHeaderEnabled: true,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: true,
        infoShowChapter: false,
        infoShowProgress: true,
        infoHeaderDividerEnabled: false,
        infoFooterDividerEnabled: true,
        infoHeaderPadding: 8,
        infoFooterPadding: 8,
      ),
      ReaderInfoStylePreset.readingFocused => settings.copyWith(
        infoHeaderEnabled: false,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: true,
        infoShowChapter: false,
        infoShowProgress: false,
        infoHeaderDividerEnabled: false,
        infoFooterDividerEnabled: false,
        infoHeaderPadding: 6,
        infoFooterPadding: 6,
      ),
    };
  }

  ReaderSettings applyFontPreset(
    ReaderSettings settings,
    ReaderFontPreset preset,
  ) {
    return switch (preset) {
      ReaderFontPreset.systemSans => settings.copyWith(
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.defaultSans,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      ),
      ReaderFontPreset.systemSerif => settings.copyWith(
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.serif,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      ),
      ReaderFontPreset.systemMonospace => settings.copyWith(
        fontSource: ReaderFontSource.system,
        systemFontPreset: ReaderSystemFontPreset.monospace,
        clearFontFamilyKey: true,
        clearCustomFontPath: true,
      ),
    };
  }
}
