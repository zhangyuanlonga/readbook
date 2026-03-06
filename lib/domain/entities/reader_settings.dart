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

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.horizontalPadding = 18,
    this.paragraphSpacing = 14,
    this.paragraphIndent = 0,
    this.letterSpacing = defaultLetterSpacing,
    this.brightness = 1,
    this.themeMode = ReaderThemeMode.light,
    this.pageTurnMode = ReaderPageTurnMode.tap,
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
    this.mangaReadMode = ReaderMangaReadMode.continuous,
    this.mangaImageSpacing = 10,
    this.mangaImagePadding = 8,
    this.mangaLoadStrategy = ReaderMangaLoadStrategy.balanced,
    this.switchSourceScoreRankingEnabled = true,
  });

  static const double minAutoReadSpeed = 20;
  static const double maxAutoReadSpeed = 120;
  static const double defaultAutoReadSpeed = 48;
  static const double minLetterSpacing = -0.05;
  static const double maxLetterSpacing = 0.25;
  static const double defaultLetterSpacing = 0;

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final double paragraphSpacing;
  final double paragraphIndent;
  final double letterSpacing;
  final double brightness;
  final ReaderThemeMode themeMode;
  final ReaderPageTurnMode pageTurnMode;
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
  final ReaderMangaReadMode mangaReadMode;
  final double mangaImageSpacing;
  final double mangaImagePadding;
  final ReaderMangaLoadStrategy mangaLoadStrategy;
  final bool switchSourceScoreRankingEnabled;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    double? paragraphSpacing,
    double? paragraphIndent,
    double? letterSpacing,
    double? brightness,
    ReaderThemeMode? themeMode,
    ReaderPageTurnMode? pageTurnMode,
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
    ReaderMangaReadMode? mangaReadMode,
    double? mangaImageSpacing,
    double? mangaImagePadding,
    ReaderMangaLoadStrategy? mangaLoadStrategy,
    bool? switchSourceScoreRankingEnabled,
    bool clearBackgroundImage = false,
    bool clearFontFamilyKey = false,
    bool clearCustomFontPath = false,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      letterSpacing:
          (letterSpacing ?? this.letterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: brightness ?? this.brightness,
      themeMode: themeMode ?? this.themeMode,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
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
      mangaReadMode: mangaReadMode ?? this.mangaReadMode,
      mangaImageSpacing: mangaImageSpacing ?? this.mangaImageSpacing,
      mangaImagePadding: mangaImagePadding ?? this.mangaImagePadding,
      mangaLoadStrategy: mangaLoadStrategy ?? this.mangaLoadStrategy,
      switchSourceScoreRankingEnabled:
          switchSourceScoreRankingEnabled ??
          this.switchSourceScoreRankingEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'horizontalPadding': horizontalPadding,
      'paragraphSpacing': paragraphSpacing,
      'paragraphIndent': paragraphIndent,
      'letterSpacing': letterSpacing,
      'brightness': brightness,
      'themeMode': themeMode.name,
      'pageTurnMode': pageTurnMode.name,
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
      'mangaReadMode': mangaReadMode.name,
      'mangaImageSpacing': mangaImageSpacing,
      'mangaImagePadding': mangaImagePadding,
      'mangaLoadStrategy': mangaLoadStrategy.name,
      'switchSourceScoreRankingEnabled': switchSourceScoreRankingEnabled,
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
      orElse: () => ReaderPageTurnMode.tap,
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
    final fontFamilyKey = json['fontFamilyKey']?.toString().trim();
    final customFontPath = json['customFontPath']?.toString().trim();

    return ReaderSettings(
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.7,
      horizontalPadding: _asDouble(json['horizontalPadding']) ?? 18,
      paragraphSpacing: _asDouble(json['paragraphSpacing']) ?? 14,
      paragraphIndent: _asDouble(json['paragraphIndent']) ?? 0,
      letterSpacing:
          (_asDouble(json['letterSpacing']) ?? defaultLetterSpacing)
              .clamp(minLetterSpacing, maxLetterSpacing)
              .toDouble(),
      brightness: _asDouble(json['brightness'])?.clamp(0.2, 1.0) ?? 1,
      themeMode: mode,
      pageTurnMode: pageTurnMode,
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
      mangaReadMode: mangaReadMode,
      mangaImageSpacing:
          _asDouble(json['mangaImageSpacing'])?.clamp(0.0, 24.0) ?? 10,
      mangaImagePadding:
          _asDouble(json['mangaImagePadding'])?.clamp(0.0, 24.0) ?? 8,
      mangaLoadStrategy: mangaLoadStrategy,
      switchSourceScoreRankingEnabled:
          _asBool(json['switchSourceScoreRankingEnabled']) ?? true,
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
}
