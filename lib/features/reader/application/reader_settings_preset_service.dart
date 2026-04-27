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
        lineHeight: 1.67,
        letterSpacing: 0.1,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.regular,
      ),
      ReaderTypographyPreset.md3Compact => settings.copyWith(
        fontSize: 17,
        lineHeight: 1.59,
        letterSpacing: 0.05,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.regular,
      ),
      ReaderTypographyPreset.md3Comfortable => settings.copyWith(
        fontSize: 19,
        lineHeight: 1.74,
        letterSpacing: 0.12,
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
        paragraphSpacing: 1,
        paragraphIndent: 2,
      ),
      ReaderSpacingPreset.balanced => settings.copyWith(
        paragraphSpacing: 2,
        paragraphIndent: 2,
      ),
      ReaderSpacingPreset.relaxed => settings.copyWith(
        paragraphSpacing: 3,
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
        chapterHeaderMode: ReaderChapterHeaderMode.start,
        chapterHeaderTopSpacing: 0,
        chapterHeaderBottomSpacing: 0,
      ),
      ReaderChapterHeaderPreset.compact => settings.copyWith(
        chapterHeaderMode: ReaderChapterHeaderMode.start,
        chapterHeaderTopSpacing: 0,
        chapterHeaderBottomSpacing: 0,
      ),
      ReaderChapterHeaderPreset.immersive => settings.copyWith(
        chapterHeaderMode: ReaderChapterHeaderMode.center,
        chapterHeaderTopSpacing: 8,
        chapterHeaderBottomSpacing: 6,
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
