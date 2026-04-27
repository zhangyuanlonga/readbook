import '../../../domain/entities/reader_settings.dart';

class ReaderTypographySettings {
  const ReaderTypographySettings({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.letterSpacing,
    required this.textFullJustifyEnabled,
    required this.fontWeightLevel,
    required this.fontWeightValue,
    required this.fontSource,
    required this.systemFontPreset,
    required this.fontFamilyKey,
    required this.customFontPath,
  });

  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double paragraphIndent;
  final double letterSpacing;
  final bool textFullJustifyEnabled;
  final ReaderFontWeightLevel fontWeightLevel;
  final int? fontWeightValue;
  final ReaderFontSource fontSource;
  final ReaderSystemFontPreset systemFontPreset;
  final String? fontFamilyKey;
  final String? customFontPath;
}

class ReaderBodyLayoutSettings {
  const ReaderBodyLayoutSettings({
    required this.bodyMarginTop,
    required this.bodyMarginBottom,
    required this.bodyMarginLeft,
    required this.bodyMarginRight,
  });

  final double bodyMarginTop;
  final double bodyMarginBottom;
  final double bodyMarginLeft;
  final double bodyMarginRight;
}

class ReaderChapterHeaderSettings {
  const ReaderChapterHeaderSettings({
    required this.showChapterHeader,
    required this.horizontalOffset,
    required this.verticalOffset,
  });

  final bool showChapterHeader;
  final double horizontalOffset;
  final double verticalOffset;
}

class ReaderInfoBarSettings {
  const ReaderInfoBarSettings({
    required this.infoHeaderEnabled,
    required this.infoFooterEnabled,
    required this.infoShowTime,
    required this.infoShowBattery,
    required this.infoShowChapter,
    required this.infoShowProgress,
    required this.infoHeaderPadding,
    required this.infoFooterPadding,
    required this.infoHeaderDividerEnabled,
    required this.infoFooterDividerEnabled,
    required this.infoHeaderMarginTop,
    required this.infoHeaderMarginBottom,
    required this.infoHeaderMarginLeft,
    required this.infoHeaderMarginRight,
    required this.infoFooterMarginTop,
    required this.infoFooterMarginBottom,
    required this.infoFooterMarginLeft,
    required this.infoFooterMarginRight,
  });

  final bool infoHeaderEnabled;
  final bool infoFooterEnabled;
  final bool infoShowTime;
  final bool infoShowBattery;
  final bool infoShowChapter;
  final bool infoShowProgress;
  final double infoHeaderPadding;
  final double infoFooterPadding;
  final bool infoHeaderDividerEnabled;
  final bool infoFooterDividerEnabled;
  final double infoHeaderMarginTop;
  final double infoHeaderMarginBottom;
  final double infoHeaderMarginLeft;
  final double infoHeaderMarginRight;
  final double infoFooterMarginTop;
  final double infoFooterMarginBottom;
  final double infoFooterMarginLeft;
  final double infoFooterMarginRight;
}

class ReaderVisualDecorationSettings {
  const ReaderVisualDecorationSettings({
    required this.backgroundStyle,
    required this.backgroundTone,
    required this.backgroundImageBase64,
    required this.bodyTextColorValue,
    required this.bodyTextItalicEnabled,
    required this.bodyTextShadowEnabled,
    required this.bodyTextShadowColorValue,
    required this.bodyTextShadowBlurRadius,
    required this.bodyTextShadowOffsetDx,
    required this.bodyTextShadowOffsetDy,
    required this.bodyTextDecorationStyle,
    required this.bodyTextDecorationColorValue,
    required this.bodyTextUnderlineThickness,
    required this.bodyTextUnderlineGap,
    required this.bodyTextUnderlineDashLength,
    required this.bodyTextUnderlineDashGapRatio,
  });

  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
  final String? backgroundImageBase64;
  final int? bodyTextColorValue;
  final bool bodyTextItalicEnabled;
  final bool bodyTextShadowEnabled;
  final int? bodyTextShadowColorValue;
  final double bodyTextShadowBlurRadius;
  final double bodyTextShadowOffsetDx;
  final double bodyTextShadowOffsetDy;
  final ReaderBodyTextDecorationStyle bodyTextDecorationStyle;
  final int? bodyTextDecorationColorValue;
  final double bodyTextUnderlineThickness;
  final double bodyTextUnderlineGap;
  final double bodyTextUnderlineDashLength;
  final double bodyTextUnderlineDashGapRatio;
}

class ReaderSettingsGroups {
  const ReaderSettingsGroups({
    required this.typography,
    required this.bodyLayout,
    required this.chapterHeader,
    required this.infoBar,
    required this.visualDecoration,
  });

  final ReaderTypographySettings typography;
  final ReaderBodyLayoutSettings bodyLayout;
  final ReaderChapterHeaderSettings chapterHeader;
  final ReaderInfoBarSettings infoBar;
  final ReaderVisualDecorationSettings visualDecoration;
}

class ReaderSettingsGroupingService {
  const ReaderSettingsGroupingService();

  ReaderSettingsGroups split(ReaderSettings settings) {
    return ReaderSettingsGroups(
      typography: ReaderTypographySettings(
        fontSize: settings.fontSize,
        lineHeight: settings.lineHeight,
        paragraphSpacing: settings.paragraphSpacing,
        paragraphIndent: settings.paragraphIndent,
        letterSpacing: settings.letterSpacing,
        textFullJustifyEnabled: settings.textFullJustifyEnabled,
        fontWeightLevel: settings.fontWeightLevel,
        fontWeightValue: settings.fontWeightValue,
        fontSource: settings.fontSource,
        systemFontPreset: settings.systemFontPreset,
        fontFamilyKey: settings.fontFamilyKey,
        customFontPath: settings.customFontPath,
      ),
      bodyLayout: ReaderBodyLayoutSettings(
        bodyMarginTop: settings.bodyMarginTop,
        bodyMarginBottom: settings.bodyMarginBottom,
        bodyMarginLeft: settings.bodyMarginLeft,
        bodyMarginRight: settings.bodyMarginRight,
      ),
      chapterHeader: ReaderChapterHeaderSettings(
        showChapterHeader: settings.showChapterHeader,
        horizontalOffset: settings.chapterHeaderHorizontalOffset,
        verticalOffset: settings.chapterHeaderVerticalOffset,
      ),
      infoBar: ReaderInfoBarSettings(
        infoHeaderEnabled: settings.infoHeaderEnabled,
        infoFooterEnabled: settings.infoFooterEnabled,
        infoShowTime: settings.infoShowTime,
        infoShowBattery: settings.infoShowBattery,
        infoShowChapter: settings.infoShowChapter,
        infoShowProgress: settings.infoShowProgress,
        infoHeaderPadding: settings.infoHeaderPadding,
        infoFooterPadding: settings.infoFooterPadding,
        infoHeaderDividerEnabled: settings.infoHeaderDividerEnabled,
        infoFooterDividerEnabled: settings.infoFooterDividerEnabled,
        infoHeaderMarginTop: settings.infoHeaderMarginTop,
        infoHeaderMarginBottom: settings.infoHeaderMarginBottom,
        infoHeaderMarginLeft: settings.infoHeaderMarginLeft,
        infoHeaderMarginRight: settings.infoHeaderMarginRight,
        infoFooterMarginTop: settings.infoFooterMarginTop,
        infoFooterMarginBottom: settings.infoFooterMarginBottom,
        infoFooterMarginLeft: settings.infoFooterMarginLeft,
        infoFooterMarginRight: settings.infoFooterMarginRight,
      ),
      visualDecoration: ReaderVisualDecorationSettings(
        backgroundStyle: settings.backgroundStyle,
        backgroundTone: settings.backgroundTone,
        backgroundImageBase64: settings.backgroundImageBase64,
        bodyTextColorValue: settings.bodyTextColorValue,
        bodyTextItalicEnabled: settings.bodyTextItalicEnabled,
        bodyTextShadowEnabled: settings.bodyTextShadowEnabled,
        bodyTextShadowColorValue: settings.bodyTextShadowColorValue,
        bodyTextShadowBlurRadius: settings.bodyTextShadowBlurRadius,
        bodyTextShadowOffsetDx: settings.bodyTextShadowOffsetDx,
        bodyTextShadowOffsetDy: settings.bodyTextShadowOffsetDy,
        bodyTextDecorationStyle: settings.bodyTextDecorationStyle,
        bodyTextDecorationColorValue: settings.bodyTextDecorationColorValue,
        bodyTextUnderlineThickness: settings.bodyTextUnderlineThickness,
        bodyTextUnderlineGap: settings.bodyTextUnderlineGap,
        bodyTextUnderlineDashLength: settings.bodyTextUnderlineDashLength,
        bodyTextUnderlineDashGapRatio: settings.bodyTextUnderlineDashGapRatio,
      ),
    );
  }

  ReaderSettings merge({
    required ReaderSettings base,
    ReaderTypographySettings? typography,
    ReaderBodyLayoutSettings? bodyLayout,
    ReaderChapterHeaderSettings? chapterHeader,
    ReaderInfoBarSettings? infoBar,
    ReaderVisualDecorationSettings? visualDecoration,
  }) {
    return base.copyWith(
      fontSize: typography?.fontSize,
      lineHeight: typography?.lineHeight,
      paragraphSpacing: typography?.paragraphSpacing,
      paragraphIndent: typography?.paragraphIndent,
      letterSpacing: typography?.letterSpacing,
      textFullJustifyEnabled: typography?.textFullJustifyEnabled,
      fontWeightLevel: typography?.fontWeightLevel,
      fontWeightValue: typography?.fontWeightValue,
      fontSource: typography?.fontSource,
      systemFontPreset: typography?.systemFontPreset,
      fontFamilyKey: typography?.fontFamilyKey,
      customFontPath: typography?.customFontPath,
      bodyMarginTop: bodyLayout?.bodyMarginTop,
      bodyMarginBottom: bodyLayout?.bodyMarginBottom,
      bodyMarginLeft: bodyLayout?.bodyMarginLeft,
      bodyMarginRight: bodyLayout?.bodyMarginRight,
      showChapterHeader: chapterHeader?.showChapterHeader,
      chapterHeaderHorizontalOffset: chapterHeader?.horizontalOffset,
      chapterHeaderVerticalOffset: chapterHeader?.verticalOffset,
      infoHeaderEnabled: infoBar?.infoHeaderEnabled,
      infoFooterEnabled: infoBar?.infoFooterEnabled,
      infoShowTime: infoBar?.infoShowTime,
      infoShowBattery: infoBar?.infoShowBattery,
      infoShowChapter: infoBar?.infoShowChapter,
      infoShowProgress: infoBar?.infoShowProgress,
      infoHeaderPadding: infoBar?.infoHeaderPadding,
      infoFooterPadding: infoBar?.infoFooterPadding,
      infoHeaderDividerEnabled: infoBar?.infoHeaderDividerEnabled,
      infoFooterDividerEnabled: infoBar?.infoFooterDividerEnabled,
      infoHeaderMarginTop: infoBar?.infoHeaderMarginTop,
      infoHeaderMarginBottom: infoBar?.infoHeaderMarginBottom,
      infoHeaderMarginLeft: infoBar?.infoHeaderMarginLeft,
      infoHeaderMarginRight: infoBar?.infoHeaderMarginRight,
      infoFooterMarginTop: infoBar?.infoFooterMarginTop,
      infoFooterMarginBottom: infoBar?.infoFooterMarginBottom,
      infoFooterMarginLeft: infoBar?.infoFooterMarginLeft,
      infoFooterMarginRight: infoBar?.infoFooterMarginRight,
      backgroundStyle: visualDecoration?.backgroundStyle,
      backgroundTone: visualDecoration?.backgroundTone,
      backgroundImageBase64: visualDecoration?.backgroundImageBase64,
      bodyTextColorValue: visualDecoration?.bodyTextColorValue,
      bodyTextItalicEnabled: visualDecoration?.bodyTextItalicEnabled,
      bodyTextShadowEnabled: visualDecoration?.bodyTextShadowEnabled,
      bodyTextShadowColorValue: visualDecoration?.bodyTextShadowColorValue,
      bodyTextShadowBlurRadius: visualDecoration?.bodyTextShadowBlurRadius,
      bodyTextShadowOffsetDx: visualDecoration?.bodyTextShadowOffsetDx,
      bodyTextShadowOffsetDy: visualDecoration?.bodyTextShadowOffsetDy,
      bodyTextDecorationStyle: visualDecoration?.bodyTextDecorationStyle,
      bodyTextDecorationColorValue:
          visualDecoration?.bodyTextDecorationColorValue,
      bodyTextUnderlineThickness: visualDecoration?.bodyTextUnderlineThickness,
      bodyTextUnderlineGap: visualDecoration?.bodyTextUnderlineGap,
      bodyTextUnderlineDashLength:
          visualDecoration?.bodyTextUnderlineDashLength,
      bodyTextUnderlineDashGapRatio:
          visualDecoration?.bodyTextUnderlineDashGapRatio,
    );
  }
}
