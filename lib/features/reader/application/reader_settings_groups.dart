import '../../../domain/entities/reader_settings.dart';

class ReaderTypographySettings {
  const ReaderTypographySettings({
    required this.fontSize,
    required this.lineHeight,
    required this.paragraphSpacing,
    required this.paragraphIndent,
    required this.letterSpacing,
    required this.textFullJustifyEnabled,
    required this.textBottomJustifyEnabled,
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
  final bool textBottomJustifyEnabled;
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

class ReaderPageTurnSettings {
  const ReaderPageTurnSettings({
    required this.pageTurnMode,
    required this.pageAnimationStyle,
    required this.pageTurnStepRatio,
    required this.volumeKeyPageEnabled,
  });

  final ReaderPageTurnMode pageTurnMode;
  final ReaderPageAnimationStyle pageAnimationStyle;
  final double pageTurnStepRatio;
  final bool volumeKeyPageEnabled;
}

class ReaderAutoReadSettings {
  const ReaderAutoReadSettings({
    required this.enabled,
    required this.speed,
    required this.mode,
    required this.speedLevel,
    required this.pauseMode,
    required this.endBehavior,
  });

  final bool enabled;
  final double speed;
  final ReaderAutoReadMode mode;
  final int speedLevel;
  final ReaderAutoReadPauseMode pauseMode;
  final ReaderAutoReadEndBehavior endBehavior;
}

class ReaderAudioSettings {
  const ReaderAudioSettings({
    required this.defaultSpeed,
    required this.rememberSpeed,
    required this.seekStepSeconds,
    required this.autoPlay,
  });

  final double defaultSpeed;
  final bool rememberSpeed;
  final int seekStepSeconds;
  final bool autoPlay;
}

class ReaderMangaSettings {
  const ReaderMangaSettings({
    required this.readMode,
    required this.imageSpacing,
    required this.imagePadding,
    required this.loadStrategy,
  });

  final ReaderMangaReadMode readMode;
  final double imageSpacing;
  final double imagePadding;
  final ReaderMangaLoadStrategy loadStrategy;
}

class ReaderSettingsGroups {
  const ReaderSettingsGroups({
    required this.typography,
    required this.bodyLayout,
    required this.chapterHeader,
    required this.infoBar,
    required this.visualDecoration,
    required this.pageTurn,
    required this.autoRead,
    required this.audio,
    required this.manga,
  });

  final ReaderTypographySettings typography;
  final ReaderBodyLayoutSettings bodyLayout;
  final ReaderChapterHeaderSettings chapterHeader;
  final ReaderInfoBarSettings infoBar;
  final ReaderVisualDecorationSettings visualDecoration;
  final ReaderPageTurnSettings pageTurn;
  final ReaderAutoReadSettings autoRead;
  final ReaderAudioSettings audio;
  final ReaderMangaSettings manga;
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
        textBottomJustifyEnabled: settings.textBottomJustifyEnabled,
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
      pageTurn: ReaderPageTurnSettings(
        pageTurnMode: settings.pageTurnMode,
        pageAnimationStyle: settings.pageAnimationStyle,
        pageTurnStepRatio: settings.pageTurnStepRatio,
        volumeKeyPageEnabled: settings.volumeKeyPageEnabled,
      ),
      autoRead: ReaderAutoReadSettings(
        enabled: settings.autoReadEnabled,
        speed: settings.autoReadSpeed,
        mode: settings.autoReadMode,
        speedLevel: settings.autoReadSpeedLevel,
        pauseMode: settings.autoReadPauseMode,
        endBehavior: settings.autoReadEndBehavior,
      ),
      audio: ReaderAudioSettings(
        defaultSpeed: settings.audioDefaultSpeed,
        rememberSpeed: settings.audioRememberSpeed,
        seekStepSeconds: settings.audioSeekStepSeconds,
        autoPlay: settings.audioAutoPlay,
      ),
      manga: ReaderMangaSettings(
        readMode: settings.mangaReadMode,
        imageSpacing: settings.mangaImageSpacing,
        imagePadding: settings.mangaImagePadding,
        loadStrategy: settings.mangaLoadStrategy,
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
    ReaderPageTurnSettings? pageTurn,
    ReaderAutoReadSettings? autoRead,
    ReaderAudioSettings? audio,
    ReaderMangaSettings? manga,
  }) {
    return base.copyWith(
      fontSize: typography?.fontSize,
      lineHeight: typography?.lineHeight,
      paragraphSpacing: typography?.paragraphSpacing,
      paragraphIndent: typography?.paragraphIndent,
      letterSpacing: typography?.letterSpacing,
      textFullJustifyEnabled: typography?.textFullJustifyEnabled,
      textBottomJustifyEnabled: typography?.textBottomJustifyEnabled,
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
      pageTurnMode: pageTurn?.pageTurnMode,
      pageAnimationStyle: pageTurn?.pageAnimationStyle,
      pageTurnStepRatio: pageTurn?.pageTurnStepRatio,
      volumeKeyPageEnabled: pageTurn?.volumeKeyPageEnabled,
      autoReadEnabled: autoRead?.enabled,
      autoReadSpeed: autoRead?.speed,
      autoReadMode: autoRead?.mode,
      autoReadSpeedLevel: autoRead?.speedLevel,
      autoReadPauseMode: autoRead?.pauseMode,
      autoReadEndBehavior: autoRead?.endBehavior,
      audioDefaultSpeed: audio?.defaultSpeed,
      audioRememberSpeed: audio?.rememberSpeed,
      audioSeekStepSeconds: audio?.seekStepSeconds,
      audioAutoPlay: audio?.autoPlay,
      mangaReadMode: manga?.readMode,
      mangaImageSpacing: manga?.imageSpacing,
      mangaImagePadding: manga?.imagePadding,
      mangaLoadStrategy: manga?.loadStrategy,
    );
  }
}

extension ReaderSettingsGroupedAccess on ReaderSettings {
  ReaderSettingsGroups get grouped =>
      const ReaderSettingsGroupingService().split(this);

  ReaderSettings mergeGroups({
    ReaderTypographySettings? typography,
    ReaderBodyLayoutSettings? bodyLayout,
    ReaderChapterHeaderSettings? chapterHeader,
    ReaderInfoBarSettings? infoBar,
    ReaderVisualDecorationSettings? visualDecoration,
    ReaderPageTurnSettings? pageTurn,
    ReaderAutoReadSettings? autoRead,
    ReaderAudioSettings? audio,
    ReaderMangaSettings? manga,
  }) {
    return const ReaderSettingsGroupingService().merge(
      base: this,
      typography: typography,
      bodyLayout: bodyLayout,
      chapterHeader: chapterHeader,
      infoBar: infoBar,
      visualDecoration: visualDecoration,
      pageTurn: pageTurn,
      autoRead: autoRead,
      audio: audio,
      manga: manga,
    );
  }
}
