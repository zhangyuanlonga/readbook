enum ReaderThemeMode { light, sepia, dark }

enum ReaderPageTurnMode { tap, swipe, tapAndSwipe, scroll, tapAndScroll }

enum ReaderBackgroundStyle { plain, paper, warm }

enum ReaderBackgroundTone {
  surface,
  containerLow,
  container,
  containerHigh,
  containerHighest,
  pureBlack,
  primaryTint,
  secondaryTint,
  tertiaryTint,
  flameOrangeTint,
  pineGreenTint,
  seaBlueTint,
  nightPurpleTint,
  mistTealTint,
  berryRoseTint,
  amberGoldTint,
}

ReaderBackgroundTone normalizeReaderBackgroundTone({
  required ReaderThemeMode mode,
  required ReaderBackgroundTone tone,
}) {
  if (mode == ReaderThemeMode.dark &&
      (tone == ReaderBackgroundTone.containerHigh ||
          tone == ReaderBackgroundTone.containerHighest)) {
    return ReaderBackgroundTone.pureBlack;
  }
  if (tone == ReaderBackgroundTone.primaryTint ||
      tone == ReaderBackgroundTone.secondaryTint ||
      tone == ReaderBackgroundTone.tertiaryTint) {
    return ReaderBackgroundTone.surface;
  }
  return tone;
}

enum ReaderFontWeightLevel { light, regular, medium }

enum ReaderFontSource { system, builtin, custom }

enum ReaderSystemFontPreset { defaultSans, serif, monospace }

enum ReaderPageAnimationStyle { curl, fade, cover, translate, vertical, none }

enum ReaderMangaReadMode { continuous, paged, horizontal }

enum ReaderMangaLoadStrategy { balanced, smooth, saveData }

enum ReaderBodyTextDecorationStyle { none, solid, dashed }

enum ReaderBodyMarginMode { preset, custom }

enum ReaderBodyMarginPreset { compact, standard, relaxed, immersive }

enum ReaderChapterHeaderMode { start, center, hidden }

enum ReaderAutoReadMode { scroll, page }

enum ReaderAutoReadPauseMode { none, chapterEnd, paragraphEnd }

enum ReaderAutoReadEndBehavior { stop, loopBook, nextBook }

class ReaderBodyMarginValues {
  const ReaderBodyMarginValues({
    required this.top,
    required this.bottom,
    required this.left,
    required this.right,
  });

  final double top;
  final double bottom;
  final double left;
  final double right;
}

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.67,
    this.horizontalPadding = 16,
    this.paragraphSpacing = 2,
    this.paragraphIndent = 2,
    this.textFullJustifyEnabled = true,
    this.textBottomJustifyEnabled = true,
    this.letterSpacing = defaultLetterSpacing,
    this.brightness = 1,
    this.followSystemBrightness = true,
    this.themeMode = ReaderThemeMode.light,
    this.pageTurnMode = ReaderPageTurnMode.tapAndSwipe,
    this.volumeKeyPageEnabled = true,
    this.autoReadEnabled = false,
    this.autoReadSpeed = defaultAutoReadSpeed,
    this.autoReadMode = ReaderAutoReadMode.scroll,
    this.autoReadSpeedLevel = defaultAutoReadSpeedLevel,
    this.autoReadPauseMode = ReaderAutoReadPauseMode.none,
    this.autoReadEndBehavior = ReaderAutoReadEndBehavior.stop,
    this.backgroundStyle = ReaderBackgroundStyle.plain,
    this.backgroundTone = ReaderBackgroundTone.surface,
    this.pageTurnStepRatio = 0.88,
    this.fontWeightLevel = ReaderFontWeightLevel.regular,
    this.fontWeightValue,
    this.fontSource = ReaderFontSource.system,
    this.systemFontPreset = ReaderSystemFontPreset.defaultSans,
    this.fontFamilyKey,
    this.customFontPath,
    this.bodyTextItalicEnabled = false,
    this.bodyTextShadowEnabled = false,
    this.bodyTextShadowColorValue,
    this.bodyTextShadowBlurRadius = 0,
    this.bodyTextShadowOffsetDx = 0,
    this.bodyTextShadowOffsetDy = 0,
    this.pageAnimationStyle = ReaderPageAnimationStyle.curl,
    this.backgroundImageBase64,
    this.bodyTextColorValue,
    this.bodyTextDecorationStyle = ReaderBodyTextDecorationStyle.none,
    this.bodyTextDecorationColorValue,
    this.bodyTextUnderlineThickness = 2.2,
    this.bodyTextUnderlineGap = 2,
    this.bodyTextUnderlineDashLength = 6,
    this.bodyTextUnderlineDashGapRatio = 6,
    this.mangaReadMode = ReaderMangaReadMode.continuous,
    this.mangaImageSpacing = 10,
    this.mangaImagePadding = 8,
    this.mangaLoadStrategy = ReaderMangaLoadStrategy.balanced,
    this.switchSourceScoreRankingEnabled = true,
    this.infoHeaderEnabled = false,
    this.infoFooterEnabled = false,
    this.infoShowTime = true,
    this.infoShowBattery = false,
    this.infoShowChapter = false,
    this.infoShowProgress = true,
    this.infoHeaderPadding = 8,
    this.infoFooterPadding = 8,
    this.infoHeaderDividerEnabled = false,
    this.infoFooterDividerEnabled = false,
    this.infoHeaderMarginTop = 0,
    this.infoHeaderMarginBottom = 0,
    this.infoHeaderMarginLeft = 18,
    this.infoHeaderMarginRight = 18,
    this.bodyMarginMode = ReaderBodyMarginMode.preset,
    this.bodyMarginPreset = ReaderBodyMarginPreset.standard,
    this.bodyMarginTop = 6,
    this.bodyMarginBottom = 6,
    this.bodyMarginLeft = 16,
    this.bodyMarginRight = 16,
    this.infoFooterMarginTop = 0,
    this.infoFooterMarginBottom = 0,
    this.infoFooterMarginLeft = 18,
    this.infoFooterMarginRight = 18,
    this.showChapterHeader = true,
    this.chapterHeaderHorizontalOffset = 0,
    this.chapterHeaderVerticalOffset = 0,
    this.chapterHeaderMode = ReaderChapterHeaderMode.start,
    this.chapterHeaderTopSpacing = 0,
    this.chapterHeaderBottomSpacing = 0,
    this.pinnedChapterHeaderOffsetX = 0,
    this.pinnedChapterHeaderOffsetY = 8,
  });

  static const double minAutoReadSpeed = 20;
  static const double maxAutoReadSpeed = 120;
  static const double defaultAutoReadSpeed = 48;
  static const int minAutoReadSpeedLevel = 1;
  static const int maxAutoReadSpeedLevel = 10;
  static const int defaultAutoReadSpeedLevel = 4;
  static const double minLetterSpacing = -0.5;
  static const double maxLetterSpacing = 0.5;
  static const double defaultLetterSpacing = 0.1;
  static const double minParagraphSpacing = 0;
  static const double maxParagraphSpacing = 20;
  static const double minParagraphIndent = 0;
  static const double maxParagraphIndent = 4;
  static const int minFontWeightValue = 100;
  static const int maxFontWeightValue = 900;
  static const double minInfoBarPadding = 0;
  static const double maxInfoBarPadding = 24;
  static const double minLayoutMargin = 0;
  static const double maxLayoutMargin = 40;
  static const double maxInfoFooterHorizontalMargin = 80;
  static const double minPinnedHeaderOffsetX = 0;
  static const double maxPinnedHeaderOffsetX = 1;
  static const double minPinnedHeaderOffsetY = -40;
  static const double maxPinnedHeaderOffsetY = 180;
  static const double minChapterHeaderVerticalOffset = -50;
  static const double minChapterHeaderSpacing = 0;
  static const double maxChapterHeaderSpacing = 80;

  static int autoReadSpeedLevelFromSpeed(double speed) {
    final normalized = ((speed.clamp(minAutoReadSpeed, maxAutoReadSpeed) -
                minAutoReadSpeed) /
            (maxAutoReadSpeed - minAutoReadSpeed))
        .clamp(0.0, 1.0);
    return (normalized * (maxAutoReadSpeedLevel - minAutoReadSpeedLevel) +
            minAutoReadSpeedLevel)
        .round()
        .clamp(minAutoReadSpeedLevel, maxAutoReadSpeedLevel)
        .toInt();
  }

  static double autoReadSpeedForLevel(int level) {
    final normalized = ((level.clamp(
                  minAutoReadSpeedLevel,
                  maxAutoReadSpeedLevel,
                ) -
                minAutoReadSpeedLevel) /
            (maxAutoReadSpeedLevel - minAutoReadSpeedLevel))
        .clamp(0.0, 1.0);
    return minAutoReadSpeed +
        normalized * (maxAutoReadSpeed - minAutoReadSpeed);
  }

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final double paragraphSpacing;
  final double paragraphIndent;
  final bool textFullJustifyEnabled;
  final bool textBottomJustifyEnabled;
  final double letterSpacing;
  final double brightness;
  final bool followSystemBrightness;
  final ReaderThemeMode themeMode;
  final ReaderPageTurnMode pageTurnMode;
  final bool volumeKeyPageEnabled;
  final bool autoReadEnabled;
  final double autoReadSpeed;
  final ReaderAutoReadMode autoReadMode;
  final int autoReadSpeedLevel;
  final ReaderAutoReadPauseMode autoReadPauseMode;
  final ReaderAutoReadEndBehavior autoReadEndBehavior;
  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
  final double pageTurnStepRatio;
  final ReaderFontWeightLevel fontWeightLevel;
  final int? fontWeightValue;
  final ReaderFontSource fontSource;
  final ReaderSystemFontPreset systemFontPreset;
  final String? fontFamilyKey;
  final String? customFontPath;
  final bool bodyTextItalicEnabled;
  final bool bodyTextShadowEnabled;
  final int? bodyTextShadowColorValue;
  final double bodyTextShadowBlurRadius;
  final double bodyTextShadowOffsetDx;
  final double bodyTextShadowOffsetDy;
  final ReaderPageAnimationStyle pageAnimationStyle;
  final String? backgroundImageBase64;
  final int? bodyTextColorValue;
  final ReaderBodyTextDecorationStyle bodyTextDecorationStyle;
  final int? bodyTextDecorationColorValue;
  final double bodyTextUnderlineThickness;
  final double bodyTextUnderlineGap;
  final double bodyTextUnderlineDashLength;
  final double bodyTextUnderlineDashGapRatio;
  final ReaderMangaReadMode mangaReadMode;
  final double mangaImageSpacing;
  final double mangaImagePadding;
  final ReaderMangaLoadStrategy mangaLoadStrategy;
  final bool switchSourceScoreRankingEnabled;
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
  final ReaderBodyMarginMode bodyMarginMode;
  final ReaderBodyMarginPreset bodyMarginPreset;
  final double bodyMarginTop;
  final double bodyMarginBottom;
  final double bodyMarginLeft;
  final double bodyMarginRight;
  final double infoFooterMarginTop;
  final double infoFooterMarginBottom;
  final double infoFooterMarginLeft;
  final double infoFooterMarginRight;
  final bool showChapterHeader;
  final double chapterHeaderHorizontalOffset;
  final double chapterHeaderVerticalOffset;
  final ReaderChapterHeaderMode chapterHeaderMode;
  final double chapterHeaderTopSpacing;
  final double chapterHeaderBottomSpacing;
  final double pinnedChapterHeaderOffsetX;
  final double pinnedChapterHeaderOffsetY;

  ReaderBodyMarginValues get effectiveBodyMarginValues {
    return ReaderBodyMarginValues(
      top: bodyMarginTop,
      bottom: bodyMarginBottom,
      left: bodyMarginLeft,
      right: bodyMarginRight,
    );
  }

  static ReaderBodyMarginValues bodyMarginValuesForPreset(
    ReaderBodyMarginPreset preset,
  ) {
    return switch (preset) {
      ReaderBodyMarginPreset.compact => const ReaderBodyMarginValues(
        top: 4,
        bottom: 4,
        left: 12,
        right: 12,
      ),
      ReaderBodyMarginPreset.standard => const ReaderBodyMarginValues(
        top: 6,
        bottom: 6,
        left: 16,
        right: 16,
      ),
      ReaderBodyMarginPreset.relaxed => const ReaderBodyMarginValues(
        top: 8,
        bottom: 10,
        left: 20,
        right: 20,
      ),
      ReaderBodyMarginPreset.immersive => const ReaderBodyMarginValues(
        top: 0,
        bottom: 6,
        left: 24,
        right: 24,
      ),
    };
  }

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    double? paragraphSpacing,
    double? paragraphIndent,
    bool? textFullJustifyEnabled,
    bool? textBottomJustifyEnabled,
    double? letterSpacing,
    double? brightness,
    bool? followSystemBrightness,
    ReaderThemeMode? themeMode,
    ReaderPageTurnMode? pageTurnMode,
    bool? volumeKeyPageEnabled,
    bool? autoReadEnabled,
    double? autoReadSpeed,
    ReaderAutoReadMode? autoReadMode,
    int? autoReadSpeedLevel,
    ReaderAutoReadPauseMode? autoReadPauseMode,
    ReaderAutoReadEndBehavior? autoReadEndBehavior,
    ReaderBackgroundStyle? backgroundStyle,
    ReaderBackgroundTone? backgroundTone,
    double? pageTurnStepRatio,
    ReaderFontWeightLevel? fontWeightLevel,
    int? fontWeightValue,
    ReaderFontSource? fontSource,
    ReaderSystemFontPreset? systemFontPreset,
    String? fontFamilyKey,
    String? customFontPath,
    bool? bodyTextItalicEnabled,
    bool? bodyTextShadowEnabled,
    int? bodyTextShadowColorValue,
    double? bodyTextShadowBlurRadius,
    double? bodyTextShadowOffsetDx,
    double? bodyTextShadowOffsetDy,
    ReaderPageAnimationStyle? pageAnimationStyle,
    String? backgroundImageBase64,
    int? bodyTextColorValue,
    ReaderBodyTextDecorationStyle? bodyTextDecorationStyle,
    int? bodyTextDecorationColorValue,
    double? bodyTextUnderlineThickness,
    double? bodyTextUnderlineGap,
    double? bodyTextUnderlineDashLength,
    double? bodyTextUnderlineDashGapRatio,
    ReaderMangaReadMode? mangaReadMode,
    double? mangaImageSpacing,
    double? mangaImagePadding,
    ReaderMangaLoadStrategy? mangaLoadStrategy,
    bool? switchSourceScoreRankingEnabled,
    bool? infoHeaderEnabled,
    bool? infoFooterEnabled,
    bool? infoShowTime,
    bool? infoShowBattery,
    bool? infoShowChapter,
    bool? infoShowProgress,
    double? infoHeaderPadding,
    double? infoFooterPadding,
    bool? infoHeaderDividerEnabled,
    bool? infoFooterDividerEnabled,
    double? infoHeaderMarginTop,
    double? infoHeaderMarginBottom,
    double? infoHeaderMarginLeft,
    double? infoHeaderMarginRight,
    ReaderBodyMarginMode? bodyMarginMode,
    ReaderBodyMarginPreset? bodyMarginPreset,
    double? bodyMarginTop,
    double? bodyMarginBottom,
    double? bodyMarginLeft,
    double? bodyMarginRight,
    double? infoFooterMarginTop,
    double? infoFooterMarginBottom,
    double? infoFooterMarginLeft,
    double? infoFooterMarginRight,
    bool? showChapterHeader,
    double? chapterHeaderHorizontalOffset,
    double? chapterHeaderVerticalOffset,
    ReaderChapterHeaderMode? chapterHeaderMode,
    double? chapterHeaderTopSpacing,
    double? chapterHeaderBottomSpacing,
    double? pinnedChapterHeaderOffsetX,
    double? pinnedChapterHeaderOffsetY,
    bool clearBackgroundImage = false,
    bool clearBodyTextColor = false,
    bool clearBodyTextDecorationColor = false,
    bool clearFontFamilyKey = false,
    bool clearCustomFontPath = false,
  }) {
    final nextBodyMarginTop =
        (bodyMarginTop ?? this.bodyMarginTop)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final nextBodyMarginBottom =
        (bodyMarginBottom ?? this.bodyMarginBottom)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final nextBodyMarginLeft =
        (bodyMarginLeft ?? this.bodyMarginLeft)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final nextBodyMarginRight =
        (bodyMarginRight ?? this.bodyMarginRight)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final nextBodyMarginMode = bodyMarginMode ?? this.bodyMarginMode;
    final nextBodyMarginPreset = bodyMarginPreset ?? this.bodyMarginPreset;
    final nextHorizontalPadding =
        horizontalPadding ??
        ((nextBodyMarginLeft + nextBodyMarginRight) / 2).toDouble();
    final nextAutoReadSpeed =
        autoReadSpeed ??
        (autoReadSpeedLevel == null
            ? this.autoReadSpeed
            : autoReadSpeedForLevel(autoReadSpeedLevel));
    final nextAutoReadSpeedLevel =
        autoReadSpeedLevel ?? autoReadSpeedLevelFromSpeed(nextAutoReadSpeed);

    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: nextHorizontalPadding,
      paragraphSpacing:
          (paragraphSpacing ?? this.paragraphSpacing)
              .clamp(minParagraphSpacing, maxParagraphSpacing)
              .toDouble(),
      paragraphIndent:
          (paragraphIndent ?? this.paragraphIndent)
              .clamp(minParagraphIndent, maxParagraphIndent)
              .toDouble(),
      textFullJustifyEnabled:
          textFullJustifyEnabled ?? this.textFullJustifyEnabled,
      textBottomJustifyEnabled:
          textBottomJustifyEnabled ?? this.textBottomJustifyEnabled,
      letterSpacing:
          (letterSpacing ?? this.letterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: brightness ?? this.brightness,
      followSystemBrightness:
          followSystemBrightness ?? this.followSystemBrightness,
      themeMode: themeMode ?? this.themeMode,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      volumeKeyPageEnabled: volumeKeyPageEnabled ?? this.volumeKeyPageEnabled,
      autoReadEnabled: autoReadEnabled ?? this.autoReadEnabled,
      autoReadSpeed:
          nextAutoReadSpeed
              .clamp(minAutoReadSpeed, maxAutoReadSpeed)
              .toDouble(),
      autoReadMode: autoReadMode ?? this.autoReadMode,
      autoReadSpeedLevel:
          nextAutoReadSpeedLevel
              .clamp(minAutoReadSpeedLevel, maxAutoReadSpeedLevel)
              .toInt(),
      autoReadPauseMode: autoReadPauseMode ?? this.autoReadPauseMode,
      autoReadEndBehavior: autoReadEndBehavior ?? this.autoReadEndBehavior,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundTone: backgroundTone ?? this.backgroundTone,
      pageTurnStepRatio: pageTurnStepRatio ?? this.pageTurnStepRatio,
      fontWeightLevel: fontWeightLevel ?? this.fontWeightLevel,
      fontWeightValue:
          fontWeightValue == null
              ? this.fontWeightValue
              : fontWeightValue
                  .clamp(minFontWeightValue, maxFontWeightValue)
                  .toInt(),
      fontSource: fontSource ?? this.fontSource,
      systemFontPreset: systemFontPreset ?? this.systemFontPreset,
      fontFamilyKey:
          clearFontFamilyKey ? null : fontFamilyKey ?? this.fontFamilyKey,
      customFontPath:
          clearCustomFontPath ? null : customFontPath ?? this.customFontPath,
      bodyTextItalicEnabled:
          bodyTextItalicEnabled ?? this.bodyTextItalicEnabled,
      bodyTextShadowEnabled:
          bodyTextShadowEnabled ?? this.bodyTextShadowEnabled,
      bodyTextShadowColorValue:
          clearBodyTextColor
              ? null
              : bodyTextShadowColorValue ?? this.bodyTextShadowColorValue,
      bodyTextShadowBlurRadius:
          (bodyTextShadowBlurRadius ?? this.bodyTextShadowBlurRadius)
              .clamp(0, 32)
              .toDouble(),
      bodyTextShadowOffsetDx:
          (bodyTextShadowOffsetDx ?? this.bodyTextShadowOffsetDx)
              .clamp(-24, 24)
              .toDouble(),
      bodyTextShadowOffsetDy:
          (bodyTextShadowOffsetDy ?? this.bodyTextShadowOffsetDy)
              .clamp(-24, 24)
              .toDouble(),
      pageAnimationStyle: pageAnimationStyle ?? this.pageAnimationStyle,
      backgroundImageBase64:
          clearBackgroundImage
              ? null
              : backgroundImageBase64 ?? this.backgroundImageBase64,
      bodyTextColorValue:
          clearBodyTextColor
              ? null
              : bodyTextColorValue ?? this.bodyTextColorValue,
      bodyTextDecorationStyle:
          bodyTextDecorationStyle ?? this.bodyTextDecorationStyle,
      bodyTextDecorationColorValue:
          clearBodyTextDecorationColor
              ? null
              : bodyTextDecorationColorValue ??
                  this.bodyTextDecorationColorValue,
      bodyTextUnderlineThickness:
          (bodyTextUnderlineThickness ?? this.bodyTextUnderlineThickness)
              .clamp(1, 10)
              .toDouble(),
      bodyTextUnderlineGap:
          (bodyTextUnderlineGap ?? this.bodyTextUnderlineGap)
              .clamp(0, 16)
              .toDouble(),
      bodyTextUnderlineDashLength:
          (bodyTextUnderlineDashLength ?? this.bodyTextUnderlineDashLength)
              .clamp(1, 24)
              .toDouble(),
      bodyTextUnderlineDashGapRatio:
          (bodyTextUnderlineDashGapRatio ?? this.bodyTextUnderlineDashGapRatio)
              .clamp(1, 12)
              .toDouble(),
      mangaReadMode: mangaReadMode ?? this.mangaReadMode,
      mangaImageSpacing: mangaImageSpacing ?? this.mangaImageSpacing,
      mangaImagePadding: mangaImagePadding ?? this.mangaImagePadding,
      mangaLoadStrategy: mangaLoadStrategy ?? this.mangaLoadStrategy,
      switchSourceScoreRankingEnabled:
          switchSourceScoreRankingEnabled ??
          this.switchSourceScoreRankingEnabled,
      infoHeaderEnabled: infoHeaderEnabled ?? this.infoHeaderEnabled,
      infoFooterEnabled: infoFooterEnabled ?? this.infoFooterEnabled,
      infoShowTime: infoShowTime ?? this.infoShowTime,
      infoShowBattery: infoShowBattery ?? this.infoShowBattery,
      infoShowChapter: infoShowChapter ?? this.infoShowChapter,
      infoShowProgress: infoShowProgress ?? this.infoShowProgress,
      infoHeaderPadding:
          (infoHeaderPadding ?? this.infoHeaderPadding)
              .clamp(minInfoBarPadding, maxInfoBarPadding)
              .toDouble(),
      infoFooterPadding:
          (infoFooterPadding ?? this.infoFooterPadding)
              .clamp(minInfoBarPadding, maxInfoBarPadding)
              .toDouble(),
      infoHeaderDividerEnabled:
          infoHeaderDividerEnabled ?? this.infoHeaderDividerEnabled,
      infoFooterDividerEnabled:
          infoFooterDividerEnabled ?? this.infoFooterDividerEnabled,
      infoHeaderMarginTop:
          (infoHeaderMarginTop ?? this.infoHeaderMarginTop)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginBottom:
          (infoHeaderMarginBottom ?? this.infoHeaderMarginBottom)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginLeft:
          (infoHeaderMarginLeft ?? this.infoHeaderMarginLeft)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginRight:
          (infoHeaderMarginRight ?? this.infoHeaderMarginRight)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginMode: nextBodyMarginMode,
      bodyMarginPreset: nextBodyMarginPreset,
      bodyMarginTop: nextBodyMarginTop,
      bodyMarginBottom: nextBodyMarginBottom,
      bodyMarginLeft: nextBodyMarginLeft,
      bodyMarginRight: nextBodyMarginRight,
      infoFooterMarginTop:
          (infoFooterMarginTop ?? this.infoFooterMarginTop)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginBottom:
          (infoFooterMarginBottom ?? this.infoFooterMarginBottom)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginLeft:
          (infoFooterMarginLeft ?? this.infoFooterMarginLeft)
              .clamp(minLayoutMargin, maxInfoFooterHorizontalMargin)
              .toDouble(),
      infoFooterMarginRight:
          (infoFooterMarginRight ?? this.infoFooterMarginRight)
              .clamp(minLayoutMargin, maxInfoFooterHorizontalMargin)
              .toDouble(),
      showChapterHeader: showChapterHeader ?? this.showChapterHeader,
      chapterHeaderHorizontalOffset:
          (chapterHeaderHorizontalOffset ?? this.chapterHeaderHorizontalOffset)
              .clamp(minPinnedHeaderOffsetX, maxPinnedHeaderOffsetX)
              .toDouble(),
      chapterHeaderVerticalOffset:
          (chapterHeaderVerticalOffset ?? this.chapterHeaderVerticalOffset)
              .clamp(minChapterHeaderVerticalOffset, maxChapterHeaderSpacing)
              .toDouble(),
      chapterHeaderMode: chapterHeaderMode ?? this.chapterHeaderMode,
      chapterHeaderTopSpacing:
          (chapterHeaderTopSpacing ?? this.chapterHeaderTopSpacing)
              .clamp(minChapterHeaderSpacing, maxChapterHeaderSpacing)
              .toDouble(),
      chapterHeaderBottomSpacing:
          (chapterHeaderBottomSpacing ?? this.chapterHeaderBottomSpacing)
              .clamp(minChapterHeaderSpacing, maxChapterHeaderSpacing)
              .toDouble(),
      pinnedChapterHeaderOffsetX:
          (pinnedChapterHeaderOffsetX ?? this.pinnedChapterHeaderOffsetX)
              .clamp(minPinnedHeaderOffsetX, maxPinnedHeaderOffsetX)
              .toDouble(),
      pinnedChapterHeaderOffsetY:
          (pinnedChapterHeaderOffsetY ?? this.pinnedChapterHeaderOffsetY)
              .clamp(minPinnedHeaderOffsetY, maxPinnedHeaderOffsetY)
              .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'paragraphSpacing': paragraphSpacing,
      'paragraphIndent': paragraphIndent,
      'textFullJustifyEnabled': textFullJustifyEnabled,
      'textBottomJustifyEnabled': textBottomJustifyEnabled,
      'letterSpacing': letterSpacing,
      'brightness': brightness,
      'followSystemBrightness': followSystemBrightness,
      'themeMode': themeMode.name,
      'pageTurnMode': pageTurnMode.name,
      'volumeKeyPageEnabled': volumeKeyPageEnabled,
      'autoReadEnabled': autoReadEnabled,
      'autoReadSpeed': autoReadSpeed,
      'autoReadMode': autoReadMode.name,
      'autoReadSpeedLevel': autoReadSpeedLevel,
      'autoReadPauseMode': autoReadPauseMode.name,
      'autoReadEndBehavior': autoReadEndBehavior.name,
      'backgroundStyle': backgroundStyle.name,
      'backgroundTone': backgroundTone.name,
      'pageTurnStepRatio': pageTurnStepRatio,
      'fontWeightLevel': fontWeightLevel.name,
      'fontWeightValue': fontWeightValue,
      'fontSource': fontSource.name,
      'systemFontPreset': systemFontPreset.name,
      'fontFamilyKey': fontFamilyKey,
      'customFontPath': customFontPath,
      'bodyTextItalicEnabled': bodyTextItalicEnabled,
      'bodyTextShadowEnabled': bodyTextShadowEnabled,
      'bodyTextShadowColorValue': bodyTextShadowColorValue,
      'bodyTextShadowBlurRadius': bodyTextShadowBlurRadius,
      'bodyTextShadowOffsetDx': bodyTextShadowOffsetDx,
      'bodyTextShadowOffsetDy': bodyTextShadowOffsetDy,
      'pageAnimationStyle': pageAnimationStyle.name,
      'backgroundImageBase64': backgroundImageBase64,
      'bodyTextColorValue': bodyTextColorValue,
      'bodyTextDecorationStyle': bodyTextDecorationStyle.name,
      'bodyTextDecorationColorValue': bodyTextDecorationColorValue,
      'bodyTextUnderlineThickness': bodyTextUnderlineThickness,
      'bodyTextUnderlineGap': bodyTextUnderlineGap,
      'bodyTextUnderlineDashLength': bodyTextUnderlineDashLength,
      'bodyTextUnderlineDashGapRatio': bodyTextUnderlineDashGapRatio,
      'mangaReadMode': mangaReadMode.name,
      'mangaImageSpacing': mangaImageSpacing,
      'mangaImagePadding': mangaImagePadding,
      'mangaLoadStrategy': mangaLoadStrategy.name,
      'switchSourceScoreRankingEnabled': switchSourceScoreRankingEnabled,
      'infoHeaderEnabled': infoHeaderEnabled,
      'infoFooterEnabled': infoFooterEnabled,
      'infoShowTime': infoShowTime,
      'infoShowBattery': infoShowBattery,
      'infoShowChapter': infoShowChapter,
      'infoShowProgress': infoShowProgress,
      'infoHeaderPadding': infoHeaderPadding,
      'infoFooterPadding': infoFooterPadding,
      'infoHeaderDividerEnabled': infoHeaderDividerEnabled,
      'infoFooterDividerEnabled': infoFooterDividerEnabled,
      'infoHeaderMarginTop': infoHeaderMarginTop,
      'infoHeaderMarginBottom': infoHeaderMarginBottom,
      'infoHeaderMarginLeft': infoHeaderMarginLeft,
      'infoHeaderMarginRight': infoHeaderMarginRight,
      'bodyMarginTop': bodyMarginTop,
      'bodyMarginBottom': bodyMarginBottom,
      'bodyMarginLeft': bodyMarginLeft,
      'bodyMarginRight': bodyMarginRight,
      'infoFooterMarginTop': infoFooterMarginTop,
      'infoFooterMarginBottom': infoFooterMarginBottom,
      'infoFooterMarginLeft': infoFooterMarginLeft,
      'infoFooterMarginRight': infoFooterMarginRight,
      'showChapterHeader': showChapterHeader,
      'chapterHeaderHorizontalOffset': chapterHeaderHorizontalOffset,
      'chapterHeaderVerticalOffset': chapterHeaderVerticalOffset,
    };
  }

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    final modeName = json['themeMode']?.toString();
    final mode = ReaderThemeMode.values.firstWhere(
      (item) => item.name == modeName,
      orElse: () => ReaderThemeMode.light,
    );

    final pageTurnModeName = json['pageTurnMode']?.toString();
    final pageTurnMode = ReaderPageTurnMode.values.firstWhere(
      (item) => item.name == pageTurnModeName,
      orElse: () => ReaderPageTurnMode.tapAndSwipe,
    );

    final autoReadModeName = json['autoReadMode']?.toString();
    final autoReadMode = ReaderAutoReadMode.values.firstWhere(
      (item) => item.name == autoReadModeName,
      orElse: () => ReaderAutoReadMode.scroll,
    );

    final autoReadPauseModeName = json['autoReadPauseMode']?.toString();
    final autoReadPauseMode = ReaderAutoReadPauseMode.values.firstWhere(
      (item) => item.name == autoReadPauseModeName,
      orElse: () => ReaderAutoReadPauseMode.none,
    );

    final autoReadEndBehaviorName = json['autoReadEndBehavior']?.toString();
    final autoReadEndBehavior = ReaderAutoReadEndBehavior.values.firstWhere(
      (item) => item.name == autoReadEndBehaviorName,
      orElse: () => ReaderAutoReadEndBehavior.stop,
    );

    final backgroundName = json['backgroundStyle']?.toString();
    final backgroundStyle = ReaderBackgroundStyle.values.firstWhere(
      (item) => item.name == backgroundName,
      orElse: () => ReaderBackgroundStyle.plain,
    );

    final backgroundToneName = json['backgroundTone']?.toString();
    final backgroundTone = normalizeReaderBackgroundTone(
      mode: mode,
      tone: ReaderBackgroundTone.values.firstWhere(
        (item) => item.name == backgroundToneName,
        orElse: () => ReaderBackgroundTone.surface,
      ),
    );

    final fontWeightName = json['fontWeightLevel']?.toString();
    final fontWeightLevel = ReaderFontWeightLevel.values.firstWhere(
      (item) => item.name == fontWeightName,
      orElse: () => ReaderFontWeightLevel.regular,
    );

    final fontSourceName = json['fontSource']?.toString();
    final fontSource = ReaderFontSource.values.firstWhere(
      (item) => item.name == fontSourceName,
      orElse: () => ReaderFontSource.system,
    );
    final systemFontPresetName = json['systemFontPreset']?.toString();
    final systemFontPreset = ReaderSystemFontPreset.values.firstWhere(
      (item) => item.name == systemFontPresetName,
      orElse: () => ReaderSystemFontPreset.defaultSans,
    );

    final animationName = json['pageAnimationStyle']?.toString();
    final pageAnimationStyle = ReaderPageAnimationStyle.values.firstWhere(
      (item) => item.name == animationName,
      orElse: () => ReaderPageAnimationStyle.curl,
    );

    final mangaReadModeName = json['mangaReadMode']?.toString();
    final mangaReadMode = ReaderMangaReadMode.values.firstWhere(
      (item) => item.name == mangaReadModeName,
      orElse: () => ReaderMangaReadMode.continuous,
    );

    final mangaLoadStrategyName = json['mangaLoadStrategy']?.toString();
    final mangaLoadStrategy = ReaderMangaLoadStrategy.values.firstWhere(
      (item) => item.name == mangaLoadStrategyName,
      orElse: () => ReaderMangaLoadStrategy.balanced,
    );
    final backgroundImageBase64 =
        json['backgroundImageBase64']?.toString().trim();
    final bodyTextColorValue = _asInt(json['bodyTextColorValue']);
    final bodyTextDecorationStyleName =
        json['bodyTextDecorationStyle']?.toString();
    final bodyTextDecorationStyle = ReaderBodyTextDecorationStyle.values
        .firstWhere(
          (item) => item.name == bodyTextDecorationStyleName,
          orElse: () => ReaderBodyTextDecorationStyle.none,
        );
    final bodyTextDecorationColorValue = _asInt(
      json['bodyTextDecorationColorValue'],
    );
    final rawFontWeightValue = _asInt(json['fontWeightValue']);
    final fontFamilyKey = json['fontFamilyKey']?.toString().trim();
    final customFontPath = json['customFontPath']?.toString().trim();
    final bodyMarginLeft =
        (_asDouble(json['bodyMarginLeft']) ??
                const ReaderSettings().bodyMarginLeft)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final bodyMarginRight =
        (_asDouble(json['bodyMarginRight']) ??
                const ReaderSettings().bodyMarginRight)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final autoReadSpeed =
        (_asDouble(json['autoReadSpeed']) ?? defaultAutoReadSpeed)
            .clamp(minAutoReadSpeed, maxAutoReadSpeed)
            .toDouble();

    return ReaderSettings(
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.67,
      horizontalPadding: ((bodyMarginLeft + bodyMarginRight) / 2).toDouble(),
      paragraphSpacing:
          (_asDouble(json['paragraphSpacing']) ?? 2)
              .clamp(minParagraphSpacing, maxParagraphSpacing)
              .toDouble(),
      paragraphIndent:
          (_asDouble(json['paragraphIndent']) ?? 2)
              .clamp(minParagraphIndent, maxParagraphIndent)
              .toDouble(),
      textFullJustifyEnabled: _asBool(json['textFullJustifyEnabled']) ?? true,
      textBottomJustifyEnabled:
          _asBool(json['textBottomJustifyEnabled']) ?? false,
      letterSpacing:
          (_asDouble(json['letterSpacing']) ?? defaultLetterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: _asDouble(json['brightness'])?.clamp(0.2, 1.0) ?? 1,
      followSystemBrightness: _asBool(json['followSystemBrightness']) ?? false,
      themeMode: mode,
      pageTurnMode: pageTurnMode,
      volumeKeyPageEnabled: _asBool(json['volumeKeyPageEnabled']) ?? false,
      autoReadEnabled: _asBool(json['autoReadEnabled']) ?? false,
      autoReadSpeed: autoReadSpeed,
      autoReadMode: autoReadMode,
      autoReadSpeedLevel:
          (_asInt(json['autoReadSpeedLevel']) ??
                  autoReadSpeedLevelFromSpeed(autoReadSpeed))
              .clamp(minAutoReadSpeedLevel, maxAutoReadSpeedLevel)
              .toInt(),
      autoReadPauseMode: autoReadPauseMode,
      autoReadEndBehavior: autoReadEndBehavior,
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
      pageTurnStepRatio:
          _asDouble(json['pageTurnStepRatio'])?.clamp(0.6, 1.0) ?? 0.88,
      fontWeightLevel: fontWeightLevel,
      fontWeightValue:
          rawFontWeightValue
              ?.clamp(minFontWeightValue, maxFontWeightValue)
              .toInt(),
      fontSource: fontSource,
      systemFontPreset: systemFontPreset,
      fontFamilyKey:
          fontFamilyKey == null || fontFamilyKey.isEmpty ? null : fontFamilyKey,
      customFontPath:
          customFontPath == null || customFontPath.isEmpty
              ? null
              : customFontPath,
      bodyTextItalicEnabled: _asBool(json['bodyTextItalicEnabled']) ?? false,
      bodyTextShadowEnabled: _asBool(json['bodyTextShadowEnabled']) ?? false,
      bodyTextShadowColorValue: _asInt(json['bodyTextShadowColorValue']),
      bodyTextShadowBlurRadius:
          _asDouble(json['bodyTextShadowBlurRadius'])?.clamp(0, 32) ?? 0,
      bodyTextShadowOffsetDx:
          _asDouble(json['bodyTextShadowOffsetDx'])?.clamp(-24, 24) ?? 0,
      bodyTextShadowOffsetDy:
          _asDouble(json['bodyTextShadowOffsetDy'])?.clamp(-24, 24) ?? 0,
      pageAnimationStyle: pageAnimationStyle,
      backgroundImageBase64:
          backgroundImageBase64 == null || backgroundImageBase64.isEmpty
              ? null
              : backgroundImageBase64,
      bodyTextColorValue: bodyTextColorValue,
      bodyTextDecorationStyle: bodyTextDecorationStyle,
      bodyTextDecorationColorValue: bodyTextDecorationColorValue,
      bodyTextUnderlineThickness:
          _asDouble(json['bodyTextUnderlineThickness'])?.clamp(1, 10) ?? 2.2,
      bodyTextUnderlineGap:
          _asDouble(json['bodyTextUnderlineGap'])?.clamp(0, 16) ?? 2,
      bodyTextUnderlineDashLength:
          _asDouble(json['bodyTextUnderlineDashLength'])?.clamp(1, 24) ?? 6,
      bodyTextUnderlineDashGapRatio:
          _asDouble(json['bodyTextUnderlineDashGapRatio'])?.clamp(1, 12) ?? 6,
      mangaReadMode: mangaReadMode,
      mangaImageSpacing:
          _asDouble(json['mangaImageSpacing'])?.clamp(0.0, 24.0) ?? 10,
      mangaImagePadding:
          _asDouble(json['mangaImagePadding'])?.clamp(0.0, 24.0) ?? 8,
      mangaLoadStrategy: mangaLoadStrategy,
      switchSourceScoreRankingEnabled:
          _asBool(json['switchSourceScoreRankingEnabled']) ?? true,
      infoHeaderEnabled: _asBool(json['infoHeaderEnabled']) ?? false,
      infoFooterEnabled: _asBool(json['infoFooterEnabled']) ?? false,
      infoShowTime: _asBool(json['infoShowTime']) ?? true,
      infoShowBattery: _asBool(json['infoShowBattery']) ?? false,
      infoShowChapter: _asBool(json['infoShowChapter']) ?? false,
      infoShowProgress: _asBool(json['infoShowProgress']) ?? true,
      infoHeaderPadding:
          (_asDouble(json['infoHeaderPadding']) ?? 8)
              .clamp(minInfoBarPadding, maxInfoBarPadding)
              .toDouble(),
      infoFooterPadding:
          (_asDouble(json['infoFooterPadding']) ?? 8)
              .clamp(minInfoBarPadding, maxInfoBarPadding)
              .toDouble(),
      infoHeaderDividerEnabled:
          _asBool(json['infoHeaderDividerEnabled']) ?? false,
      infoFooterDividerEnabled:
          _asBool(json['infoFooterDividerEnabled']) ?? false,
      infoHeaderMarginTop:
          (_asDouble(json['infoHeaderMarginTop']) ?? 0)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginBottom:
          (_asDouble(json['infoHeaderMarginBottom']) ?? 0)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginLeft:
          (_asDouble(json['infoHeaderMarginLeft']) ??
                  const ReaderSettings().infoHeaderMarginLeft)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginRight:
          (_asDouble(json['infoHeaderMarginRight']) ??
                  const ReaderSettings().infoHeaderMarginRight)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginTop:
          (_asDouble(json['bodyMarginTop']) ??
                  const ReaderSettings().bodyMarginTop)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginBottom:
          (_asDouble(json['bodyMarginBottom']) ??
                  const ReaderSettings().bodyMarginBottom)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginLeft: bodyMarginLeft,
      bodyMarginRight: bodyMarginRight,
      infoFooterMarginTop:
          (_asDouble(json['infoFooterMarginTop']) ?? 0)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginBottom:
          (_asDouble(json['infoFooterMarginBottom']) ?? 0)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginLeft:
          (_asDouble(json['infoFooterMarginLeft']) ??
                  const ReaderSettings().infoFooterMarginLeft)
              .clamp(minLayoutMargin, maxInfoFooterHorizontalMargin)
              .toDouble(),
      infoFooterMarginRight:
          (_asDouble(json['infoFooterMarginRight']) ??
                  const ReaderSettings().infoFooterMarginRight)
              .clamp(minLayoutMargin, maxInfoFooterHorizontalMargin)
              .toDouble(),
      showChapterHeader:
          _asBool(json['showChapterHeader']) ??
          const ReaderSettings().showChapterHeader,
      chapterHeaderHorizontalOffset:
          (_asDouble(json['chapterHeaderHorizontalOffset']) ??
                  const ReaderSettings().chapterHeaderHorizontalOffset)
              .clamp(minPinnedHeaderOffsetX, maxPinnedHeaderOffsetX)
              .toDouble(),
      chapterHeaderVerticalOffset:
          (_asDouble(json['chapterHeaderVerticalOffset']) ??
                  const ReaderSettings().chapterHeaderVerticalOffset)
              .clamp(minChapterHeaderVerticalOffset, maxChapterHeaderSpacing)
              .toDouble(),
    );
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
