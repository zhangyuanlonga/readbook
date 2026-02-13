enum ReaderThemeMode { light, sepia, dark }

enum ReaderPageTurnMode { tap, scroll }

enum ReaderBackgroundStyle { plain, paper, warm }

enum ReaderFontWeightLevel { light, regular, medium }

enum ReaderPageAnimationStyle { simulation, cover, translate, vertical, none }

class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.7,
    this.horizontalPadding = 18,
    this.paragraphSpacing = 14,
    this.paragraphIndent = 0,
    this.brightness = 1,
    this.themeMode = ReaderThemeMode.light,
    this.pageTurnMode = ReaderPageTurnMode.tap,
    this.backgroundStyle = ReaderBackgroundStyle.plain,
    this.pageTurnStepRatio = 0.88,
    this.fontWeightLevel = ReaderFontWeightLevel.regular,
    this.pageAnimationStyle = ReaderPageAnimationStyle.simulation,
    this.backgroundImageBase64,
  });

  final double fontSize;
  final double lineHeight;
  final double horizontalPadding;
  final double paragraphSpacing;
  final double paragraphIndent;
  final double brightness;
  final ReaderThemeMode themeMode;
  final ReaderPageTurnMode pageTurnMode;
  final ReaderBackgroundStyle backgroundStyle;
  final double pageTurnStepRatio;
  final ReaderFontWeightLevel fontWeightLevel;
  final ReaderPageAnimationStyle pageAnimationStyle;
  final String? backgroundImageBase64;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    double? horizontalPadding,
    double? paragraphSpacing,
    double? paragraphIndent,
    double? brightness,
    ReaderThemeMode? themeMode,
    ReaderPageTurnMode? pageTurnMode,
    ReaderBackgroundStyle? backgroundStyle,
    double? pageTurnStepRatio,
    ReaderFontWeightLevel? fontWeightLevel,
    ReaderPageAnimationStyle? pageAnimationStyle,
    String? backgroundImageBase64,
    bool clearBackgroundImage = false,
  }) {
    return ReaderSettings(
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      paragraphIndent: paragraphIndent ?? this.paragraphIndent,
      brightness: brightness ?? this.brightness,
      themeMode: themeMode ?? this.themeMode,
      pageTurnMode: pageTurnMode ?? this.pageTurnMode,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
      pageTurnStepRatio: pageTurnStepRatio ?? this.pageTurnStepRatio,
      fontWeightLevel: fontWeightLevel ?? this.fontWeightLevel,
      pageAnimationStyle: pageAnimationStyle ?? this.pageAnimationStyle,
      backgroundImageBase64:
          clearBackgroundImage
              ? null
              : backgroundImageBase64 ?? this.backgroundImageBase64,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'horizontalPadding': horizontalPadding,
      'paragraphSpacing': paragraphSpacing,
      'paragraphIndent': paragraphIndent,
      'brightness': brightness,
      'themeMode': themeMode.name,
      'pageTurnMode': pageTurnMode.name,
      'backgroundStyle': backgroundStyle.name,
      'pageTurnStepRatio': pageTurnStepRatio,
      'fontWeightLevel': fontWeightLevel.name,
      'pageAnimationStyle': pageAnimationStyle.name,
      'backgroundImageBase64': backgroundImageBase64,
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

    final fontWeightName = json['fontWeightLevel']?.toString();
    final fontWeightLevel = ReaderFontWeightLevel.values.firstWhere(
      (item) => item.name == fontWeightName,
      orElse: () => ReaderFontWeightLevel.regular,
    );

    final animationName = json['pageAnimationStyle']?.toString();
    final pageAnimationStyle = ReaderPageAnimationStyle.values.firstWhere(
      (item) => item.name == animationName,
      orElse: () => ReaderPageAnimationStyle.simulation,
    );

    final backgroundImageBase64 =
        json['backgroundImageBase64']?.toString().trim();

    return ReaderSettings(
      fontSize: _asDouble(json['fontSize']) ?? 18,
      lineHeight: _asDouble(json['lineHeight']) ?? 1.7,
      horizontalPadding: _asDouble(json['horizontalPadding']) ?? 18,
      paragraphSpacing: _asDouble(json['paragraphSpacing']) ?? 14,
      paragraphIndent: _asDouble(json['paragraphIndent']) ?? 0,
      brightness: _asDouble(json['brightness'])?.clamp(0.2, 1.0) ?? 1,
      themeMode: mode,
      pageTurnMode: pageTurnMode,
      backgroundStyle: backgroundStyle,
      pageTurnStepRatio:
          _asDouble(json['pageTurnStepRatio'])?.clamp(0.6, 1.0) ?? 0.88,
      fontWeightLevel: fontWeightLevel,
      pageAnimationStyle: pageAnimationStyle,
      backgroundImageBase64:
          backgroundImageBase64 == null || backgroundImageBase64.isEmpty
              ? null
              : backgroundImageBase64,
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
}
