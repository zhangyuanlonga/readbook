import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_settings.dart';
import 'package:shuxiang_reading_next/features/reader/application/reader_settings_groups.dart';

void main() {
  group('ReaderSettingsGroupingService', () {
    const service = ReaderSettingsGroupingService();

    test('splits settings into stable semantic groups', () {
      const settings = ReaderSettings(
        fontSize: 21,
        lineHeight: 1.9,
        paragraphSpacing: 17,
        paragraphIndent: 3,
        letterSpacing: 0.16,
        textFullJustifyEnabled: true,
        fontWeightLevel: ReaderFontWeightLevel.medium,
        fontWeightValue: 700,
        fontSource: ReaderFontSource.custom,
        systemFontPreset: ReaderSystemFontPreset.serif,
        fontFamilyKey: 'reader_font',
        customFontPath: '/tmp/reader_font.ttf',
        bodyMarginTop: 10,
        bodyMarginBottom: 12,
        bodyMarginLeft: 14,
        bodyMarginRight: 16,
        infoHeaderEnabled: true,
        infoFooterEnabled: true,
        infoShowTime: true,
        infoShowBattery: true,
        infoShowChapter: true,
        infoShowProgress: false,
        infoHeaderPadding: 11,
        infoFooterPadding: 9,
        infoHeaderDividerEnabled: true,
        infoFooterDividerEnabled: false,
        infoHeaderMarginTop: 1,
        infoHeaderMarginBottom: 2,
        infoHeaderMarginLeft: 3,
        infoHeaderMarginRight: 4,
        infoFooterMarginTop: 5,
        infoFooterMarginBottom: 6,
        infoFooterMarginLeft: 7,
        infoFooterMarginRight: 8,
        showChapterHeader: true,
        chapterHeaderHorizontalOffset: 0.3,
        chapterHeaderVerticalOffset: 22,
        backgroundStyle: ReaderBackgroundStyle.warm,
        backgroundTone: ReaderBackgroundTone.amberGoldTint,
        backgroundImageBase64: 'bg',
        bodyTextColorValue: 0xFF123456,
        bodyTextItalicEnabled: true,
        bodyTextShadowEnabled: true,
        bodyTextShadowColorValue: 0x88224466,
        bodyTextShadowBlurRadius: 6,
        bodyTextShadowOffsetDx: 1,
        bodyTextShadowOffsetDy: -2,
        bodyTextDecorationStyle: ReaderBodyTextDecorationStyle.dashed,
        bodyTextDecorationColorValue: 0xFF3366CC,
        bodyTextUnderlineThickness: 3,
        bodyTextUnderlineGap: 4,
        bodyTextUnderlineDashLength: 5,
        bodyTextUnderlineDashGapRatio: 6,
      );

      final groups = service.split(settings);

      expect(groups.typography.fontSize, 21);
      expect(groups.typography.paragraphSpacing, 17);
      expect(groups.typography.letterSpacing, closeTo(0.16, 0.0001));
      expect(groups.typography.fontFamilyKey, 'reader_font');
      expect(groups.bodyLayout.bodyMarginLeft, 14);
      expect(groups.chapterHeader.showChapterHeader, isTrue);
      expect(groups.chapterHeader.horizontalOffset, 0.3);
      expect(groups.chapterHeader.verticalOffset, 22);
      expect(groups.infoBar.infoHeaderEnabled, isTrue);
      expect(groups.infoBar.infoFooterMarginRight, 8);
      expect(
        groups.visualDecoration.backgroundStyle,
        ReaderBackgroundStyle.warm,
      );
      expect(
        groups.visualDecoration.bodyTextDecorationStyle,
        ReaderBodyTextDecorationStyle.dashed,
      );
    });

    test('merges grouped settings back without losing unrelated fields', () {
      const base = ReaderSettings(
        brightness: 0.65,
        autoReadEnabled: true,
        pageTurnMode: ReaderPageTurnMode.tapAndSwipe,
      );

      final merged = service.merge(
        base: base,
        typography: const ReaderTypographySettings(
          fontSize: 20,
          lineHeight: 1.8,
          paragraphSpacing: 15,
          paragraphIndent: 2,
          letterSpacing: 0.12,
          textFullJustifyEnabled: true,
          fontWeightLevel: ReaderFontWeightLevel.medium,
          fontWeightValue: 600,
          fontSource: ReaderFontSource.system,
          systemFontPreset: ReaderSystemFontPreset.serif,
          fontFamilyKey: null,
          customFontPath: null,
        ),
        bodyLayout: const ReaderBodyLayoutSettings(
          bodyMarginTop: 8,
          bodyMarginBottom: 9,
          bodyMarginLeft: 10,
          bodyMarginRight: 11,
        ),
        chapterHeader: const ReaderChapterHeaderSettings(
          showChapterHeader: true,
          horizontalOffset: 0.5,
          verticalOffset: 18,
        ),
      );

      expect(merged.brightness, 0.65);
      expect(merged.autoReadEnabled, isTrue);
      expect(merged.pageTurnMode, ReaderPageTurnMode.tapAndSwipe);
      expect(merged.fontSize, 20);
      expect(merged.bodyMarginRight, 11);
      expect(merged.showChapterHeader, isTrue);
      expect(merged.chapterHeaderHorizontalOffset, 0.5);
      expect(merged.chapterHeaderVerticalOffset, 18);
    });
  });
}
