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
}

enum ReaderFontWeightLevel { light, regular, medium }

enum ReaderFontSource { system, builtin, custom }

enum ReaderPageAnimationStyle { curl, fade, cover, translate, vertical, none }

enum ReaderMangaReadMode { continuous, paged, horizontal }

enum ReaderMangaLoadStrategy { balanced, smooth, saveData }

enum ReaderBodyTextDecorationStyle { none, solid, dashed }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.horizontalPadding = 18,
    this.paragraphSpacing = 14,
    this.paragraphIndent = 0,
    this.textFullJustifyEnabled = false,
    this.letterSpacing = defaultLetterSpacing,
    this.brightness = 1,
    this.themeMode = ReaderThemeMode.light,
    this.pageTurnMode = ReaderPageTurnMode.tapAndSwipe,
    this.volumeKeyPageEnabled = false,
    this.autoReadEnabled = false,
    this.autoReadSpeed = defaultAutoReadSpeed,
    this.backgroundStyle = ReaderBackgroundStyle.plain,
    this.backgroundTone = ReaderBackgroundTone.surface,
    this.pageTurnStepRatio = 0.88,
    this.fontWeightLevel = ReaderFontWeightLevel.regular,
    this.fontSource = ReaderFontSource.system,
    this.fontFamilyKey,
    this.customFontPath,
    this.pageAnimationStyle = ReaderPageAnimationStyle.curl,
    this.backgroundImageBase64,
    this.bodyTextColorValue,
    this.bodyTextDecorationStyle = ReaderBodyTextDecorationStyle.none,
    this.bodyTextDecorationColorValue,
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
    this.bodyMarginTop = 18,
    this.bodyMarginBottom = 18,
    this.bodyMarginLeft = 18,
    this.bodyMarginRight = 18,
    this.infoFooterMarginTop = 0,
    this.infoFooterMarginBottom = 0,
    this.infoFooterMarginLeft = 18,
    this.infoFooterMarginRight = 18,
  });

  static const double minAutoReadSpeed = 20;
  static const double maxAutoReadSpeed = 120;
  static const double defaultAutoReadSpeed = 48;
  static const double minLetterSpacing = -0.5;
  static const double maxLetterSpacing = 0.5;
  static const double defaultLetterSpacing = 0;
  static const double minInfoBarPadding = 0;
  static const double maxInfoBarPadding = 24;
  static const double minLayoutMargin = 0;
  static const double maxLayoutMargin = 40;

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final double paragraphSpacing;
  final double paragraphIndent;
  final bool textFullJustifyEnabled;
  final double letterSpacing;
  final double brightness;
  final ReaderThemeMode themeMode;
  final ReaderPageTurnMode pageTurnMode;
  final bool volumeKeyPageEnabled;
  final bool autoReadEnabled;
  final double autoReadSpeed;
  final ReaderBackgroundStyle backgroundStyle;
  final ReaderBackgroundTone backgroundTone;
  final double pageTurnStepRatio;
  final ReaderFontWeightLevel fontWeightLevel;
  final ReaderFontSource fontSource;
  final String? fontFamilyKey;
  final String? customFontPath;
  final ReaderPageAnimationStyle pageAnimationStyle;
  final String? backgroundImageBase64;
  final int? bodyTextColorValue;
  final ReaderBodyTextDecorationStyle bodyTextDecorationStyle;
  final int? bodyTextDecorationColorValue;
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
  final double bodyMarginTop;
  final double bodyMarginBottom;
  final double bodyMarginLeft;
  final double bodyMarginRight;
  final double infoFooterMarginTop;
  final double infoFooterMarginBottom;
  final double infoFooterMarginLeft;
  final double infoFooterMarginRight;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    double? paragraphSpacing,
    double? paragraphIndent,
    bool? textFullJustifyEnabled,
    double? letterSpacing,
    double? brightness,
    ReaderThemeMode? themeMode,
    ReaderPageTurnMode? pageTurnMode,
    bool? volumeKeyPageEnabled,
    bool? autoReadEnabled,
    double? autoReadSpeed,
    ReaderBackgroundStyle? backgroundStyle,
    ReaderBackgroundTone? backgroundTone,
    double? pageTurnStepRatio,
    ReaderFontWeightLevel? fontWeightLevel,
    ReaderFontSource? fontSource,
    String? fontFamilyKey,
    String? customFontPath,
    ReaderPageAnimationStyle? pageAnimationStyle,
    String? backgroundImageBase64,
    int? bodyTextColorValue,
    ReaderBodyTextDecorationStyle? bodyTextDecorationStyle,
    int? bodyTextDecorationColorValue,
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
    double? bodyMarginTop,
    double? bodyMarginBottom,
    double? bodyMarginLeft,
    double? bodyMarginRight,
    double? infoFooterMarginTop,
    double? infoFooterMarginBottom,
    double? infoFooterMarginLeft,
    double? infoFooterMarginRight,
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
    final nextHorizontalPadding =
        horizontalPadding ??
        (bodyMarginLeft != null || bodyMarginRight != null
            ? ((nextBodyMarginLeft + nextBodyMarginRight) / 2).toDouble()
            : this.horizontalPadding);

    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: nextHorizontalPadding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      textFullJustifyEnabled:
          textFullJustifyEnabled ?? this.textFullJustifyEnabled,
      letterSpacing:
          (letterSpacing ?? this.letterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: brightness ?? this.brightness,
      themeMode: themeMode ?? this.themeMode,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      volumeKeyPageEnabled: volumeKeyPageEnabled ?? this.volumeKeyPageEnabled,
      autoReadEnabled: autoReadEnabled ?? this.autoReadEnabled,
      autoReadSpeed:
          (autoReadSpeed ?? this.autoReadSpeed)
              .clamp(minAutoReadSpeed, maxAutoReadSpeed)
              .toDouble(),
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      backgroundTone: backgroundTone ?? this.backgroundTone,
      pageTurnStepRatio: pageTurnStepRatio ?? this.pageTurnStepRatio,
      fontWeightLevel: fontWeightLevel ?? this.fontWeightLevel,
      fontSource: fontSource ?? this.fontSource,
      fontFamilyKey:
          clearFontFamilyKey ? null : fontFamilyKey ?? this.fontFamilyKey,
      customFontPath:
          clearCustomFontPath ? null : customFontPath ?? this.customFontPath,
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
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginRight:
          (infoFooterMarginRight ?? this.infoFooterMarginRight)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'horizontalPadding': ((bodyMarginLeft + bodyMarginRight) / 2).toDouble(),
      'paragraphSpacing': paragraphSpacing,
      'paragraphIndent': paragraphIndent,
      'textFullJustifyEnabled': textFullJustifyEnabled,
      'letterSpacing': letterSpacing,
      'brightness': brightness,
      'themeMode': themeMode.name,
      'pageTurnMode': pageTurnMode.name,
      'volumeKeyPageEnabled': volumeKeyPageEnabled,
      'autoReadEnabled': autoReadEnabled,
      'autoReadSpeed': autoReadSpeed,
      'backgroundStyle': backgroundStyle.name,
      'backgroundTone': backgroundTone.name,
      'pageTurnStepRatio': pageTurnStepRatio,
      'fontWeightLevel': fontWeightLevel.name,
      'fontSource': fontSource.name,
      'fontFamilyKey': fontFamilyKey,
      'customFontPath': customFontPath,
      'pageAnimationStyle': pageAnimationStyle.name,
      'backgroundImageBase64': backgroundImageBase64,
      'bodyTextColorValue': bodyTextColorValue,
      'bodyTextDecorationStyle': bodyTextDecorationStyle.name,
      'bodyTextDecorationColorValue': bodyTextDecorationColorValue,
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

    final backgroundName = json['backgroundStyle']?.toString();
    final backgroundStyle = ReaderBackgroundStyle.values.firstWhere(
      (item) => item.name == backgroundName,
      orElse: () => ReaderBackgroundStyle.plain,
    );

    final backgroundToneName = json['backgroundTone']?.toString();
    final backgroundTone = ReaderBackgroundTone.values.firstWhere(
      (item) => item.name == backgroundToneName,
      orElse: () => ReaderBackgroundTone.surface,
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
    final bodyTextDecorationStyle =
        ReaderBodyTextDecorationStyle.values.firstWhere(
          (item) => item.name == bodyTextDecorationStyleName,
          orElse: () => ReaderBodyTextDecorationStyle.none,
        );
    final bodyTextDecorationColorValue =
        _asInt(json['bodyTextDecorationColorValue']);
    final fontFamilyKey = json['fontFamilyKey']?.toString().trim();
    final customFontPath = json['customFontPath']?.toString().trim();
    final legacyHorizontalPadding = _asDouble(json['horizontalPadding']) ?? 18;
    final bodyMarginLeft =
        (_asDouble(json['bodyMarginLeft']) ?? legacyHorizontalPadding)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();
    final bodyMarginRight =
        (_asDouble(json['bodyMarginRight']) ?? legacyHorizontalPadding)
            .clamp(minLayoutMargin, maxLayoutMargin)
            .toDouble();

    return ReaderSettings(
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.7,
      horizontalPadding: ((bodyMarginLeft + bodyMarginRight) / 2).toDouble(),
      paragraphSpacing: _asDouble(json['paragraphSpacing']) ?? 14,
      paragraphIndent: _asDouble(json['paragraphIndent']) ?? 0,
      textFullJustifyEnabled: _asBool(json['textFullJustifyEnabled']) ?? false,
      letterSpacing:
          (_asDouble(json['letterSpacing']) ?? defaultLetterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: _asDouble(json['brightness'])?.clamp(0.2, 1.0) ?? 1,
      themeMode: mode,
      pageTurnMode: pageTurnMode,
      volumeKeyPageEnabled: _asBool(json['volumeKeyPageEnabled']) ?? false,
      autoReadEnabled: _asBool(json['autoReadEnabled']) ?? false,
      autoReadSpeed:
          (_asDouble(json['autoReadSpeed']) ?? defaultAutoReadSpeed)
              .clamp(minAutoReadSpeed, maxAutoReadSpeed)
              .toDouble(),
      backgroundStyle: backgroundStyle,
      backgroundTone: backgroundTone,
      pageTurnStepRatio:
          _asDouble(json['pageTurnStepRatio'])?.clamp(0.6, 1.0) ?? 0.88,
      fontWeightLevel: fontWeightLevel,
      fontSource: fontSource,
      fontFamilyKey:
          fontFamilyKey == null || fontFamilyKey.isEmpty ? null : fontFamilyKey,
      customFontPath:
          customFontPath == null || customFontPath.isEmpty
              ? null
              : customFontPath,
      pageAnimationStyle: pageAnimationStyle,
      backgroundImageBase64:
          backgroundImageBase64 == null || backgroundImageBase64.isEmpty
              ? null
              : backgroundImageBase64,
      bodyTextColorValue: bodyTextColorValue,
      bodyTextDecorationStyle: bodyTextDecorationStyle,
      bodyTextDecorationColorValue: bodyTextDecorationColorValue,
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
          (_asDouble(json['infoHeaderMarginLeft']) ?? legacyHorizontalPadding)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoHeaderMarginRight:
          (_asDouble(json['infoHeaderMarginRight']) ?? legacyHorizontalPadding)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginTop:
          (_asDouble(json['bodyMarginTop']) ?? 18)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      bodyMarginBottom:
          (_asDouble(json['bodyMarginBottom']) ?? 18)
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
          (_asDouble(json['infoFooterMarginLeft']) ?? legacyHorizontalPadding)
              .clamp(minLayoutMargin, maxLayoutMargin)
              .toDouble(),
      infoFooterMarginRight:
          (_asDouble(json['infoFooterMarginRight']) ?? legacyHorizontalPadding)
              .clamp(minLayoutMargin, maxLayoutMargin)
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
