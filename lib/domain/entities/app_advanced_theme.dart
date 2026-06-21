import 'package:json_annotation/json_annotation.dart';

import '../../core/storage/managed_asset_directory_policy.dart';
import 'managed_asset.dart';

part 'app_advanced_theme.g.dart';

enum AppAdvancedThemeMode { light, dark }

enum AppAdvancedThemeWallpaperFit { fill, cover }

enum AppAdvancedThemeCardStyle { soft, outlined, elevated }

enum AppAdvancedThemeButtonStyle { stadium, rounded, sharp }

enum AppAdvancedThemeInputStyle { soft, outlined, underlined }

enum AppAdvancedThemeOverlayStyle { comfortable, compact }

enum AppAdvancedThemeNavigationStyle { soft, floating, compact }

enum AppAdvancedThemeSwitchStyle { soft, contrast }

enum AppAdvancedThemeEffect {
  none,
  rain,
  snow,
  leaf,
  sakura,
  rose,
  whitePetal,
  wisteria,
  firefly,
}

@JsonSerializable(createFactory: false, createToJson: false)
class AppAdvancedThemeComponentStyle {
  const AppAdvancedThemeComponentStyle({
    this.globalRadiusScale = 1,
    this.shadowStrength = 0.5,
    this.modalBackgroundBlurSigma = 0,
    this.cardStyle = AppAdvancedThemeCardStyle.soft,
    this.buttonStyle = AppAdvancedThemeButtonStyle.stadium,
    this.inputStyle = AppAdvancedThemeInputStyle.soft,
    this.overlayStyle = AppAdvancedThemeOverlayStyle.comfortable,
    this.navigationStyle = AppAdvancedThemeNavigationStyle.soft,
    this.switchStyle = AppAdvancedThemeSwitchStyle.soft,
  });

  final double globalRadiusScale;
  final double shadowStrength;
  final double modalBackgroundBlurSigma;
  final AppAdvancedThemeCardStyle cardStyle;
  final AppAdvancedThemeButtonStyle buttonStyle;
  final AppAdvancedThemeInputStyle inputStyle;
  final AppAdvancedThemeOverlayStyle overlayStyle;
  final AppAdvancedThemeNavigationStyle navigationStyle;
  final AppAdvancedThemeSwitchStyle switchStyle;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'globalRadiusScale': globalRadiusScale,
      'shadowStrength': shadowStrength,
      'modalBackgroundBlurSigma': modalBackgroundBlurSigma,
      'cardStyle': cardStyle.name,
      'buttonStyle': buttonStyle.name,
      'inputStyle': inputStyle.name,
      'overlayStyle': overlayStyle.name,
      'navigationStyle': navigationStyle.name,
      'switchStyle': switchStyle.name,
    };
  }

  factory AppAdvancedThemeComponentStyle.fromJson(Map<String, dynamic> json) {
    return AppAdvancedThemeComponentStyle(
      globalRadiusScale:
          AppAdvancedThemeModeConfig._readDouble(json, 'globalRadiusScale') ??
          1,
      shadowStrength:
          AppAdvancedThemeModeConfig._readDouble(json, 'shadowStrength') ?? 0.5,
      modalBackgroundBlurSigma:
          AppAdvancedThemeModeConfig._readDouble(
            json,
            'modalBackgroundBlurSigma',
          ) ??
          0,
      cardStyle: _readCardStyle(json['cardStyle']?.toString().trim()),
      buttonStyle: _readButtonStyle(json['buttonStyle']?.toString().trim()),
      inputStyle: _readInputStyle(json['inputStyle']?.toString().trim()),
      overlayStyle: _readOverlayStyle(json['overlayStyle']?.toString().trim()),
      navigationStyle: _readNavigationStyle(
        json['navigationStyle']?.toString().trim(),
      ),
      switchStyle: _readSwitchStyle(json['switchStyle']?.toString().trim()),
    );
  }

  AppAdvancedThemeComponentStyle copyWith({
    double? globalRadiusScale,
    double? shadowStrength,
    double? modalBackgroundBlurSigma,
    AppAdvancedThemeCardStyle? cardStyle,
    AppAdvancedThemeButtonStyle? buttonStyle,
    AppAdvancedThemeInputStyle? inputStyle,
    AppAdvancedThemeOverlayStyle? overlayStyle,
    AppAdvancedThemeNavigationStyle? navigationStyle,
    AppAdvancedThemeSwitchStyle? switchStyle,
  }) {
    return AppAdvancedThemeComponentStyle(
      globalRadiusScale: globalRadiusScale ?? this.globalRadiusScale,
      shadowStrength: shadowStrength ?? this.shadowStrength,
      modalBackgroundBlurSigma:
          modalBackgroundBlurSigma ?? this.modalBackgroundBlurSigma,
      cardStyle: cardStyle ?? this.cardStyle,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      inputStyle: inputStyle ?? this.inputStyle,
      overlayStyle: overlayStyle ?? this.overlayStyle,
      navigationStyle: navigationStyle ?? this.navigationStyle,
      switchStyle: switchStyle ?? this.switchStyle,
    );
  }

  static AppAdvancedThemeCardStyle _readCardStyle(String? raw) {
    return switch (raw) {
      'outlined' => AppAdvancedThemeCardStyle.outlined,
      'elevated' => AppAdvancedThemeCardStyle.elevated,
      _ => AppAdvancedThemeCardStyle.soft,
    };
  }

  static AppAdvancedThemeButtonStyle _readButtonStyle(String? raw) {
    return switch (raw) {
      'rounded' => AppAdvancedThemeButtonStyle.rounded,
      'sharp' => AppAdvancedThemeButtonStyle.sharp,
      _ => AppAdvancedThemeButtonStyle.stadium,
    };
  }

  static AppAdvancedThemeInputStyle _readInputStyle(String? raw) {
    return switch (raw) {
      'outlined' => AppAdvancedThemeInputStyle.outlined,
      'underlined' => AppAdvancedThemeInputStyle.underlined,
      _ => AppAdvancedThemeInputStyle.soft,
    };
  }

  static AppAdvancedThemeOverlayStyle _readOverlayStyle(String? raw) {
    return switch (raw) {
      'compact' => AppAdvancedThemeOverlayStyle.compact,
      _ => AppAdvancedThemeOverlayStyle.comfortable,
    };
  }

  static AppAdvancedThemeNavigationStyle _readNavigationStyle(String? raw) {
    return switch (raw) {
      'floating' => AppAdvancedThemeNavigationStyle.floating,
      'compact' => AppAdvancedThemeNavigationStyle.compact,
      _ => AppAdvancedThemeNavigationStyle.soft,
    };
  }

  static AppAdvancedThemeSwitchStyle _readSwitchStyle(String? raw) {
    return switch (raw) {
      'contrast' => AppAdvancedThemeSwitchStyle.contrast,
      _ => AppAdvancedThemeSwitchStyle.soft,
    };
  }
}

@JsonSerializable(createFactory: false, createToJson: false)
class AppAdvancedThemeColors {
  static const String semanticColorGroupsKey = 'semanticColorGroups';

  const AppAdvancedThemeColors({
    this.primaryColorValue,
    this.secondaryColorValue,
    this.noticeAccentColorValue,
    this.noticeSurfaceColorValue,
    this.primaryContainerColorValue,
    this.backgroundColorValue,
    this.surfaceColorValue,
    this.searchFieldBackgroundColorValue,
    this.elevatedSurfaceColorValue,
    this.cardColorValue,
    this.cardTextColorValue,
    this.cardBorderColorValue,
    this.iconBackgroundColorValue,
    this.textPrimaryColorValue,
    this.textSecondaryColorValue,
    this.buttonTextColorValue,
    this.outlineColorValue,
    this.dividerColorValue,
    this.shadowColorValue,
    this.wallpaperOverlayColorValue,
  });

  final int? primaryColorValue;
  final int? secondaryColorValue;
  final int? noticeAccentColorValue;
  final int? noticeSurfaceColorValue;
  final int? primaryContainerColorValue;
  final int? backgroundColorValue;
  final int? surfaceColorValue;
  final int? searchFieldBackgroundColorValue;
  final int? elevatedSurfaceColorValue;
  final int? cardColorValue;
  final int? cardTextColorValue;
  final int? cardBorderColorValue;
  final int? iconBackgroundColorValue;
  final int? textPrimaryColorValue;
  final int? textSecondaryColorValue;
  final int? buttonTextColorValue;
  final int? outlineColorValue;
  final int? dividerColorValue;
  final int? shadowColorValue;
  final int? wallpaperOverlayColorValue;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      if (primaryColorValue != null) 'primaryColorValue': primaryColorValue,
      if (secondaryColorValue != null)
        'secondaryColorValue': secondaryColorValue,
      if (noticeAccentColorValue != null)
        'noticeAccentColorValue': noticeAccentColorValue,
      if (noticeSurfaceColorValue != null)
        'noticeSurfaceColorValue': noticeSurfaceColorValue,
      if (primaryContainerColorValue != null)
        'primaryContainerColorValue': primaryContainerColorValue,
      if (backgroundColorValue != null)
        'backgroundColorValue': backgroundColorValue,
      if (surfaceColorValue != null) 'surfaceColorValue': surfaceColorValue,
      if (searchFieldBackgroundColorValue != null)
        'searchFieldBackgroundColorValue': searchFieldBackgroundColorValue,
      if (elevatedSurfaceColorValue != null)
        'elevatedSurfaceColorValue': elevatedSurfaceColorValue,
      if (cardColorValue != null) 'cardColorValue': cardColorValue,
      if (cardTextColorValue != null) 'cardTextColorValue': cardTextColorValue,
      if (cardBorderColorValue != null)
        'cardBorderColorValue': cardBorderColorValue,
      if (iconBackgroundColorValue != null)
        'iconBackgroundColorValue': iconBackgroundColorValue,
      if (textPrimaryColorValue != null)
        'textPrimaryColorValue': textPrimaryColorValue,
      if (textSecondaryColorValue != null)
        'textSecondaryColorValue': textSecondaryColorValue,
      if (buttonTextColorValue != null)
        'buttonTextColorValue': buttonTextColorValue,
      if (outlineColorValue != null) 'outlineColorValue': outlineColorValue,
      if (dividerColorValue != null) 'dividerColorValue': dividerColorValue,
      if (shadowColorValue != null) 'shadowColorValue': shadowColorValue,
      if (wallpaperOverlayColorValue != null)
        'wallpaperOverlayColorValue': wallpaperOverlayColorValue,
    };
    final semanticGroups = _semanticColorGroupsToJson();
    if (semanticGroups.isNotEmpty) {
      json[semanticColorGroupsKey] = semanticGroups;
    }
    return json;
  }

  factory AppAdvancedThemeColors.fromJson(Map<String, dynamic> json) {
    return AppAdvancedThemeColors(
      primaryColorValue:
          _readInt(json, 'primaryColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'primary'),
      secondaryColorValue:
          _readInt(json, 'secondaryColorValue') ??
          _readSemanticColor(json, group: 'advanced', key: 'secondary'),
      noticeAccentColorValue:
          _readInt(json, 'noticeAccentColorValue') ??
          _readSemanticColor(json, group: 'state', key: 'noticeAccent'),
      noticeSurfaceColorValue:
          _readInt(json, 'noticeSurfaceColorValue') ??
          _readSemanticColor(json, group: 'state', key: 'noticeSurface'),
      primaryContainerColorValue:
          _readInt(json, 'primaryContainerColorValue') ??
          _readSemanticColor(json, group: 'state', key: 'primaryContainer'),
      backgroundColorValue:
          _readInt(json, 'backgroundColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'background'),
      surfaceColorValue:
          _readInt(json, 'surfaceColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'surface'),
      searchFieldBackgroundColorValue:
          _readInt(json, 'searchFieldBackgroundColorValue') ??
          _readSemanticColor(
            json,
            group: 'advanced',
            key: 'searchFieldBackground',
          ),
      elevatedSurfaceColorValue:
          _readInt(json, 'elevatedSurfaceColorValue') ??
          _readSemanticColor(json, group: 'advanced', key: 'elevatedSurface'),
      cardColorValue:
          _readInt(json, 'cardColorValue') ??
          _readSemanticColor(json, group: 'component', key: 'card'),
      cardTextColorValue:
          _readInt(json, 'cardTextColorValue') ??
          _readSemanticColor(json, group: 'advanced', key: 'cardText'),
      cardBorderColorValue:
          _readInt(json, 'cardBorderColorValue') ??
          _readSemanticColor(json, group: 'advanced', key: 'cardBorder'),
      iconBackgroundColorValue:
          _readInt(json, 'iconBackgroundColorValue') ??
          _readSemanticColor(json, group: 'derived', key: 'iconBackground'),
      textPrimaryColorValue:
          _readInt(json, 'textPrimaryColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'textPrimary'),
      textSecondaryColorValue:
          _readInt(json, 'textSecondaryColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'textSecondary'),
      buttonTextColorValue:
          _readInt(json, 'buttonTextColorValue') ??
          _readSemanticColor(json, group: 'derived', key: 'buttonText'),
      outlineColorValue:
          _readInt(json, 'outlineColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'outline'),
      dividerColorValue:
          _readInt(json, 'dividerColorValue') ??
          _readSemanticColor(json, group: 'core', key: 'divider'),
      shadowColorValue:
          _readInt(json, 'shadowColorValue') ??
          _readSemanticColor(json, group: 'effects', key: 'shadow'),
      wallpaperOverlayColorValue:
          _readInt(json, 'wallpaperOverlayColorValue') ??
          _readSemanticColor(
            json,
            group: 'effects',
            key: 'wallpaperOverlayColor',
          ),
    );
  }

  AppAdvancedThemeColors copyWith({
    int? primaryColorValue,
    bool clearPrimaryColorValue = false,
    int? secondaryColorValue,
    bool clearSecondaryColorValue = false,
    int? noticeAccentColorValue,
    bool clearNoticeAccentColorValue = false,
    int? noticeSurfaceColorValue,
    bool clearNoticeSurfaceColorValue = false,
    int? primaryContainerColorValue,
    bool clearPrimaryContainerColorValue = false,
    int? backgroundColorValue,
    bool clearBackgroundColorValue = false,
    int? surfaceColorValue,
    bool clearSurfaceColorValue = false,
    int? searchFieldBackgroundColorValue,
    bool clearSearchFieldBackgroundColorValue = false,
    int? elevatedSurfaceColorValue,
    bool clearElevatedSurfaceColorValue = false,
    int? cardColorValue,
    bool clearCardColorValue = false,
    int? cardTextColorValue,
    bool clearCardTextColorValue = false,
    int? cardBorderColorValue,
    bool clearCardBorderColorValue = false,
    int? iconBackgroundColorValue,
    bool clearIconBackgroundColorValue = false,
    int? textPrimaryColorValue,
    bool clearTextPrimaryColorValue = false,
    int? textSecondaryColorValue,
    bool clearTextSecondaryColorValue = false,
    int? buttonTextColorValue,
    bool clearButtonTextColorValue = false,
    int? outlineColorValue,
    bool clearOutlineColorValue = false,
    int? dividerColorValue,
    bool clearDividerColorValue = false,
    int? shadowColorValue,
    bool clearShadowColorValue = false,
    int? wallpaperOverlayColorValue,
    bool clearWallpaperOverlayColorValue = false,
  }) {
    return AppAdvancedThemeColors(
      primaryColorValue:
          clearPrimaryColorValue
              ? null
              : (primaryColorValue ?? this.primaryColorValue),
      secondaryColorValue:
          clearSecondaryColorValue
              ? null
              : (secondaryColorValue ?? this.secondaryColorValue),
      noticeAccentColorValue:
          clearNoticeAccentColorValue
              ? null
              : (noticeAccentColorValue ?? this.noticeAccentColorValue),
      noticeSurfaceColorValue:
          clearNoticeSurfaceColorValue
              ? null
              : (noticeSurfaceColorValue ?? this.noticeSurfaceColorValue),
      primaryContainerColorValue:
          clearPrimaryContainerColorValue
              ? null
              : (primaryContainerColorValue ?? this.primaryContainerColorValue),
      backgroundColorValue:
          clearBackgroundColorValue
              ? null
              : (backgroundColorValue ?? this.backgroundColorValue),
      surfaceColorValue:
          clearSurfaceColorValue
              ? null
              : (surfaceColorValue ?? this.surfaceColorValue),
      searchFieldBackgroundColorValue:
          clearSearchFieldBackgroundColorValue
              ? null
              : (searchFieldBackgroundColorValue ??
                  this.searchFieldBackgroundColorValue),
      elevatedSurfaceColorValue:
          clearElevatedSurfaceColorValue
              ? null
              : (elevatedSurfaceColorValue ?? this.elevatedSurfaceColorValue),
      cardColorValue:
          clearCardColorValue ? null : (cardColorValue ?? this.cardColorValue),
      cardTextColorValue:
          clearCardTextColorValue
              ? null
              : (cardTextColorValue ?? this.cardTextColorValue),
      cardBorderColorValue:
          clearCardBorderColorValue
              ? null
              : (cardBorderColorValue ?? this.cardBorderColorValue),
      iconBackgroundColorValue:
          clearIconBackgroundColorValue
              ? null
              : (iconBackgroundColorValue ?? this.iconBackgroundColorValue),
      textPrimaryColorValue:
          clearTextPrimaryColorValue
              ? null
              : (textPrimaryColorValue ?? this.textPrimaryColorValue),
      textSecondaryColorValue:
          clearTextSecondaryColorValue
              ? null
              : (textSecondaryColorValue ?? this.textSecondaryColorValue),
      buttonTextColorValue:
          clearButtonTextColorValue
              ? null
              : (buttonTextColorValue ?? this.buttonTextColorValue),
      outlineColorValue:
          clearOutlineColorValue
              ? null
              : (outlineColorValue ?? this.outlineColorValue),
      dividerColorValue:
          clearDividerColorValue
              ? null
              : (dividerColorValue ?? this.dividerColorValue),
      shadowColorValue:
          clearShadowColorValue
              ? null
              : (shadowColorValue ?? this.shadowColorValue),
      wallpaperOverlayColorValue:
          clearWallpaperOverlayColorValue
              ? null
              : (wallpaperOverlayColorValue ?? this.wallpaperOverlayColorValue),
    );
  }

  int get configuredColorCount {
    return <int?>[
      primaryColorValue,
      secondaryColorValue,
      noticeAccentColorValue,
      noticeSurfaceColorValue,
      primaryContainerColorValue,
      backgroundColorValue,
      surfaceColorValue,
      searchFieldBackgroundColorValue,
      elevatedSurfaceColorValue,
      cardColorValue,
      cardTextColorValue,
      cardBorderColorValue,
      iconBackgroundColorValue,
      textPrimaryColorValue,
      textSecondaryColorValue,
      buttonTextColorValue,
      outlineColorValue,
      dividerColorValue,
      shadowColorValue,
      wallpaperOverlayColorValue,
    ].whereType<int>().length;
  }

  static int? _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  Map<String, dynamic> _semanticColorGroupsToJson() {
    final core = <String, dynamic>{
      if (primaryColorValue != null) 'primary': primaryColorValue,
      if (backgroundColorValue != null) 'background': backgroundColorValue,
      if (surfaceColorValue != null) 'surface': surfaceColorValue,
      if (textPrimaryColorValue != null) 'textPrimary': textPrimaryColorValue,
      if (textSecondaryColorValue != null)
        'textSecondary': textSecondaryColorValue,
      if (outlineColorValue != null) 'outline': outlineColorValue,
      if (dividerColorValue != null) 'divider': dividerColorValue,
    };
    final component = <String, dynamic>{
      if (cardColorValue != null) 'card': cardColorValue,
    };
    final state = <String, dynamic>{
      if (primaryContainerColorValue != null)
        'primaryContainer': primaryContainerColorValue,
      if (noticeAccentColorValue != null)
        'noticeAccent': noticeAccentColorValue,
      if (noticeSurfaceColorValue != null)
        'noticeSurface': noticeSurfaceColorValue,
    };
    final advanced = <String, dynamic>{
      if (searchFieldBackgroundColorValue != null)
        'searchFieldBackground': searchFieldBackgroundColorValue,
      if (elevatedSurfaceColorValue != null)
        'elevatedSurface': elevatedSurfaceColorValue,
      if (cardTextColorValue != null) 'cardText': cardTextColorValue,
      if (cardBorderColorValue != null) 'cardBorder': cardBorderColorValue,
      if (secondaryColorValue != null) 'secondary': secondaryColorValue,
    };
    final derived = <String, dynamic>{
      if (buttonTextColorValue != null) 'buttonText': buttonTextColorValue,
      if (iconBackgroundColorValue != null)
        'iconBackground': iconBackgroundColorValue,
    };
    final effects = <String, dynamic>{
      if (shadowColorValue != null) 'shadow': shadowColorValue,
      if (wallpaperOverlayColorValue != null)
        'wallpaperOverlayColor': wallpaperOverlayColorValue,
    };

    return <String, dynamic>{
      if (core.isNotEmpty) 'core': core,
      if (component.isNotEmpty) 'component': component,
      if (state.isNotEmpty) 'state': state,
      if (advanced.isNotEmpty) 'advanced': advanced,
      if (derived.isNotEmpty) 'derived': derived,
      if (effects.isNotEmpty) 'effects': effects,
    };
  }

  static int? _readSemanticColor(
    Map<String, dynamic> json, {
    required String group,
    required String key,
  }) {
    final root =
        json[semanticColorGroupsKey] ??
        json['semanticColors'] ??
        json['semanticPalette'];
    if (root is! Map) {
      return null;
    }
    final normalizedRoot = root.map(
      (nestedKey, value) => MapEntry(nestedKey.toString(), value),
    );
    final groupMap = normalizedRoot[group];
    if (groupMap is! Map) {
      return null;
    }
    return _readInt(
      groupMap.map((nestedKey, value) => MapEntry(nestedKey.toString(), value)),
      key,
    );
  }
}

@JsonSerializable(createFactory: false, createToJson: false)
class AppAdvancedThemeModeConfig {
  AppAdvancedThemeModeConfig({
    this.colors = const AppAdvancedThemeColors(),
    this.componentStyle = const AppAdvancedThemeComponentStyle(),
    String? wallpaperPath,
    ManagedAssetRef? wallpaperAsset,
    String? readerWallpaperPath,
    ManagedAssetRef? readerWallpaperAsset,
    this.wallpaperOpacity = 1,
    this.wallpaperBlurSigma = 0,
    this.wallpaperFit = AppAdvancedThemeWallpaperFit.cover,
    this.wallpaperOverlayOpacity = 0.32,
    this.readerWallpaperOpacity = 1,
    this.readerWallpaperBlurSigma = 0,
    this.readerWallpaperFit = AppAdvancedThemeWallpaperFit.cover,
    this.readerWallpaperOverlayOpacity = 0,
  }) : wallpaperAsset =
           wallpaperAsset ??
           _legacyAssetRefFromPath(
             path: wallpaperPath,
             type: ManagedAssetType.appBackground,
           ),
       readerWallpaperAsset =
           readerWallpaperAsset ??
           _legacyAssetRefFromPath(
             path: readerWallpaperPath,
             type: ManagedAssetType.readerBackground,
           );

  final AppAdvancedThemeColors colors;
  final AppAdvancedThemeComponentStyle componentStyle;
  final ManagedAssetRef? wallpaperAsset;
  final ManagedAssetRef? readerWallpaperAsset;
  final double wallpaperOpacity;
  final double wallpaperBlurSigma;
  final AppAdvancedThemeWallpaperFit wallpaperFit;
  final double wallpaperOverlayOpacity;
  final double readerWallpaperOpacity;
  final double readerWallpaperBlurSigma;
  final AppAdvancedThemeWallpaperFit readerWallpaperFit;
  final double readerWallpaperOverlayOpacity;

  String? get wallpaperPath {
    return wallpaperAsset?.normalizedResolvedPath ??
        wallpaperAsset?.normalizedRelativePath;
  }

  String? get readerWallpaperPath {
    return readerWallpaperAsset?.normalizedResolvedPath ??
        readerWallpaperAsset?.normalizedRelativePath;
  }

  Map<String, dynamic> toJson() {
    return {
      'colors': colors.toJson(),
      'componentStyle': componentStyle.toJson(),
      if (wallpaperAsset != null) 'wallpaperAsset': wallpaperAsset!.toJson(),
      if (readerWallpaperAsset != null)
        'readerWallpaperAsset': readerWallpaperAsset!.toJson(),
      'wallpaperOpacity': wallpaperOpacity,
      'wallpaperBlurSigma': wallpaperBlurSigma,
      'wallpaperFit': wallpaperFit.name,
      'wallpaperOverlayOpacity': wallpaperOverlayOpacity,
      'readerWallpaperOpacity': readerWallpaperOpacity,
      'readerWallpaperBlurSigma': readerWallpaperBlurSigma,
      'readerWallpaperFit': readerWallpaperFit.name,
      'readerWallpaperOverlayOpacity': readerWallpaperOverlayOpacity,
    };
  }

  factory AppAdvancedThemeModeConfig.fromJson(Map<String, dynamic> json) {
    final rawColors = json['colors'];
    final colors =
        rawColors is Map
            ? AppAdvancedThemeColors.fromJson(
              rawColors.map((key, value) => MapEntry(key.toString(), value)),
            )
            : const AppAdvancedThemeColors();

    return AppAdvancedThemeModeConfig(
      colors: colors,
      componentStyle:
          json['componentStyle'] is Map
              ? AppAdvancedThemeComponentStyle.fromJson(
                (json['componentStyle'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : const AppAdvancedThemeComponentStyle(),
      wallpaperAsset: _readAssetRef(json, 'wallpaperAsset'),
      wallpaperPath: _readNullableString(json, 'wallpaperPath'),
      readerWallpaperAsset: _readAssetRef(json, 'readerWallpaperAsset'),
      readerWallpaperPath: _readNullableString(json, 'readerWallpaperPath'),
      wallpaperOpacity: _readDouble(json, 'wallpaperOpacity') ?? 1,
      wallpaperBlurSigma: _readDouble(json, 'wallpaperBlurSigma') ?? 0,
      wallpaperFit:
          _readWallpaperFit(json, 'wallpaperFit') ??
          AppAdvancedThemeWallpaperFit.cover,
      wallpaperOverlayOpacity:
          _readDouble(json, 'wallpaperOverlayOpacity') ?? 0.32,
      readerWallpaperOpacity: _readDouble(json, 'readerWallpaperOpacity') ?? 1,
      readerWallpaperBlurSigma:
          _readDouble(json, 'readerWallpaperBlurSigma') ?? 0,
      readerWallpaperFit:
          _readWallpaperFit(json, 'readerWallpaperFit') ??
          AppAdvancedThemeWallpaperFit.cover,
      readerWallpaperOverlayOpacity:
          _readDouble(json, 'readerWallpaperOverlayOpacity') ?? 0,
    );
  }

  AppAdvancedThemeModeConfig copyWith({
    AppAdvancedThemeColors? colors,
    AppAdvancedThemeComponentStyle? componentStyle,
    String? wallpaperPath,
    bool clearWallpaperPath = false,
    ManagedAssetRef? wallpaperAsset,
    bool clearWallpaperAsset = false,
    String? readerWallpaperPath,
    bool clearReaderWallpaperPath = false,
    ManagedAssetRef? readerWallpaperAsset,
    bool clearReaderWallpaperAsset = false,
    double? wallpaperOpacity,
    double? wallpaperBlurSigma,
    AppAdvancedThemeWallpaperFit? wallpaperFit,
    double? wallpaperOverlayOpacity,
    double? readerWallpaperOpacity,
    double? readerWallpaperBlurSigma,
    AppAdvancedThemeWallpaperFit? readerWallpaperFit,
    double? readerWallpaperOverlayOpacity,
  }) {
    final nextWallpaperAsset =
        clearWallpaperPath || clearWallpaperAsset
            ? null
            : (wallpaperAsset ??
                _legacyAssetRefFromPath(
                  path: wallpaperPath,
                  type: ManagedAssetType.appBackground,
                ) ??
                this.wallpaperAsset);
    final nextReaderWallpaperAsset =
        clearReaderWallpaperPath || clearReaderWallpaperAsset
            ? null
            : (readerWallpaperAsset ??
                _legacyAssetRefFromPath(
                  path: readerWallpaperPath,
                  type: ManagedAssetType.readerBackground,
                ) ??
                this.readerWallpaperAsset);
    return AppAdvancedThemeModeConfig(
      colors: colors ?? this.colors,
      componentStyle: componentStyle ?? this.componentStyle,
      wallpaperAsset: nextWallpaperAsset,
      readerWallpaperAsset: nextReaderWallpaperAsset,
      wallpaperOpacity: wallpaperOpacity ?? this.wallpaperOpacity,
      wallpaperBlurSigma: wallpaperBlurSigma ?? this.wallpaperBlurSigma,
      wallpaperFit: wallpaperFit ?? this.wallpaperFit,
      wallpaperOverlayOpacity:
          wallpaperOverlayOpacity ?? this.wallpaperOverlayOpacity,
      readerWallpaperOpacity:
          readerWallpaperOpacity ?? this.readerWallpaperOpacity,
      readerWallpaperBlurSigma:
          readerWallpaperBlurSigma ?? this.readerWallpaperBlurSigma,
      readerWallpaperFit: readerWallpaperFit ?? this.readerWallpaperFit,
      readerWallpaperOverlayOpacity:
          readerWallpaperOverlayOpacity ?? this.readerWallpaperOverlayOpacity,
    );
  }

  bool get hasWallpaper {
    return wallpaperAsset != null;
  }

  bool get hasReaderWallpaper {
    return readerWallpaperAsset != null;
  }

  static String? _readNullableString(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  static double? _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString().trim());
  }

  static AppAdvancedThemeWallpaperFit? _readWallpaperFit(
    Map<String, dynamic> json,
    String key,
  ) {
    final raw = json[key]?.toString().trim();
    return switch (raw) {
      'fill' => AppAdvancedThemeWallpaperFit.fill,
      'cover' => AppAdvancedThemeWallpaperFit.cover,
      _ => null,
    };
  }

  static ManagedAssetRef? _legacyAssetRefFromPath({
    required String? path,
    required ManagedAssetType type,
  }) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final policy = ManagedAssetDirectoryPolicies.policyFor(type);
    if (policy == null) {
      return null;
    }
    final normalizedPath = normalized.replaceAll('\\', '/');
    return ManagedAssetRef(
      type: type,
      scope: ManagedAssetScope.themeBinding,
      root: policy.root,
      relativePath: normalizedPath,
      resolvedPath: normalizedPath.startsWith('/') ? normalizedPath : null,
    );
  }

  static ManagedAssetRef? _readAssetRef(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw is! Map) {
      return null;
    }
    return ManagedAssetRef.fromJson(
      raw.map((nestedKey, value) => MapEntry(nestedKey.toString(), value)),
    );
  }
}

@JsonSerializable(createFactory: false, createToJson: false)
class AppAdvancedTheme {
  const AppAdvancedTheme({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.lightConfig,
    required this.darkConfig,
    this.category,
    this.bottomNavGalleryId,
    this.coverGalleryId,
    this.lightCoverGalleryId,
    this.darkCoverGalleryId,
    this.launchImageGalleryId,
    this.themeEffect = AppAdvancedThemeEffect.none,
    this.appInterfaceFontFamilyKey,
    this.readerFontFamilyKey,
    this.importFingerprint,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AppAdvancedThemeModeConfig lightConfig;
  final AppAdvancedThemeModeConfig darkConfig;
  final String? category;
  final String? bottomNavGalleryId;
  // Fallback cover gallery used when a book has neither real nor custom cover.
  final String? coverGalleryId;
  final String? lightCoverGalleryId;
  final String? darkCoverGalleryId;
  final String? launchImageGalleryId;
  final AppAdvancedThemeEffect themeEffect;
  final String? appInterfaceFontFamilyKey;
  final String? readerFontFamilyKey;
  final String? importFingerprint;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lightConfig': lightConfig.toJson(),
      'darkConfig': darkConfig.toJson(),
      if (category != null && category!.trim().isNotEmpty) 'category': category,
      if (bottomNavGalleryId != null && bottomNavGalleryId!.trim().isNotEmpty)
        'bottomNavGalleryId': bottomNavGalleryId,
      if (coverGalleryId != null && coverGalleryId!.trim().isNotEmpty)
        'coverGalleryId': coverGalleryId,
      if (lightCoverGalleryId != null && lightCoverGalleryId!.trim().isNotEmpty)
        'lightCoverGalleryId': lightCoverGalleryId,
      if (darkCoverGalleryId != null && darkCoverGalleryId!.trim().isNotEmpty)
        'darkCoverGalleryId': darkCoverGalleryId,
      if (launchImageGalleryId != null &&
          launchImageGalleryId!.trim().isNotEmpty)
        'launchImageGalleryId': launchImageGalleryId,
      if (themeEffect != AppAdvancedThemeEffect.none)
        'themeEffect': themeEffect.name,
      if (appInterfaceFontFamilyKey != null &&
          appInterfaceFontFamilyKey!.trim().isNotEmpty)
        'appInterfaceFontFamilyKey': appInterfaceFontFamilyKey,
      if (readerFontFamilyKey != null && readerFontFamilyKey!.trim().isNotEmpty)
        'readerFontFamilyKey': readerFontFamilyKey,
      if (importFingerprint != null && importFingerprint!.trim().isNotEmpty)
        'importFingerprint': importFingerprint,
    };
  }

  factory AppAdvancedTheme.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString().trim() ?? '';
    if (rawId.isEmpty) {
      throw const FormatException('Missing required field: id');
    }

    final rawName = json['name']?.toString().trim() ?? '';
    if (rawName.isEmpty) {
      throw const FormatException('Missing required field: name');
    }

    final legacyColors = _readLegacyColors(json);
    final legacyWallpaperPath = _readNullableString(json, 'wallpaperPath');

    return AppAdvancedTheme(
      id: rawId,
      name: rawName,
      createdAt: _readDateTime(json, 'createdAt'),
      updatedAt: _readDateTime(json, 'updatedAt'),
      lightConfig: _readModeConfig(
        json: json,
        key: 'lightConfig',
        fallbackColors: legacyColors,
        fallbackWallpaperPath: legacyWallpaperPath,
      ),
      darkConfig: _readModeConfig(
        json: json,
        key: 'darkConfig',
        fallbackColors: legacyColors,
        fallbackWallpaperPath: legacyWallpaperPath,
      ),
      category: _readNullableString(json, 'category'),
      bottomNavGalleryId: _readNullableString(json, 'bottomNavGalleryId'),
      coverGalleryId: _readNullableString(json, 'coverGalleryId'),
      lightCoverGalleryId: _readNullableString(json, 'lightCoverGalleryId'),
      darkCoverGalleryId: _readNullableString(json, 'darkCoverGalleryId'),
      launchImageGalleryId: _readNullableString(json, 'launchImageGalleryId'),
      themeEffect: _readThemeEffect(json['themeEffect']?.toString().trim()),
      appInterfaceFontFamilyKey: _readNullableString(
        json,
        'appInterfaceFontFamilyKey',
      ),
      readerFontFamilyKey: _readNullableString(json, 'readerFontFamilyKey'),
      importFingerprint: _readNullableString(json, 'importFingerprint'),
    );
  }

  AppAdvancedTheme copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    AppAdvancedThemeModeConfig? lightConfig,
    AppAdvancedThemeModeConfig? darkConfig,
    String? category,
    bool clearCategory = false,
    String? bottomNavGalleryId,
    bool clearBottomNavGalleryId = false,
    String? coverGalleryId,
    bool clearCoverGalleryId = false,
    String? lightCoverGalleryId,
    bool clearLightCoverGalleryId = false,
    String? darkCoverGalleryId,
    bool clearDarkCoverGalleryId = false,
    String? launchImageGalleryId,
    bool clearLaunchImageGalleryId = false,
    AppAdvancedThemeEffect? themeEffect,
    String? appInterfaceFontFamilyKey,
    bool clearAppInterfaceFontFamilyKey = false,
    String? readerFontFamilyKey,
    bool clearReaderFontFamilyKey = false,
    String? importFingerprint,
    bool clearImportFingerprint = false,
  }) {
    return AppAdvancedTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lightConfig: lightConfig ?? this.lightConfig,
      darkConfig: darkConfig ?? this.darkConfig,
      category: clearCategory ? null : (category ?? this.category),
      bottomNavGalleryId:
          clearBottomNavGalleryId
              ? null
              : (bottomNavGalleryId ?? this.bottomNavGalleryId),
      coverGalleryId:
          clearCoverGalleryId ? null : (coverGalleryId ?? this.coverGalleryId),
      lightCoverGalleryId:
          clearLightCoverGalleryId
              ? null
              : (lightCoverGalleryId ?? this.lightCoverGalleryId),
      darkCoverGalleryId:
          clearDarkCoverGalleryId
              ? null
              : (darkCoverGalleryId ?? this.darkCoverGalleryId),
      launchImageGalleryId:
          clearLaunchImageGalleryId
              ? null
              : (launchImageGalleryId ?? this.launchImageGalleryId),
      themeEffect: themeEffect ?? this.themeEffect,
      appInterfaceFontFamilyKey:
          clearAppInterfaceFontFamilyKey
              ? null
              : (appInterfaceFontFamilyKey ?? this.appInterfaceFontFamilyKey),
      readerFontFamilyKey:
          clearReaderFontFamilyKey
              ? null
              : (readerFontFamilyKey ?? this.readerFontFamilyKey),
      importFingerprint:
          clearImportFingerprint
              ? null
              : (importFingerprint ?? this.importFingerprint),
    );
  }

  static AppAdvancedThemeEffect _readThemeEffect(String? raw) {
    return switch (raw) {
      'rain' => AppAdvancedThemeEffect.rain,
      'snow' => AppAdvancedThemeEffect.snow,
      'leaf' => AppAdvancedThemeEffect.leaf,
      'sakura' => AppAdvancedThemeEffect.sakura,
      'rose' => AppAdvancedThemeEffect.rose,
      'whitePetal' => AppAdvancedThemeEffect.whitePetal,
      'wisteria' => AppAdvancedThemeEffect.wisteria,
      'firefly' => AppAdvancedThemeEffect.firefly,
      _ => AppAdvancedThemeEffect.none,
    };
  }

  String? coverGalleryIdFor(AppAdvancedThemeMode mode) {
    final scoped = switch (mode) {
      AppAdvancedThemeMode.light => lightCoverGalleryId,
      AppAdvancedThemeMode.dark => darkCoverGalleryId,
    };
    final normalizedScoped = scoped?.trim();
    if (normalizedScoped != null && normalizedScoped.isNotEmpty) {
      return normalizedScoped;
    }
    final normalizedFallback = coverGalleryId?.trim();
    if (normalizedFallback != null && normalizedFallback.isNotEmpty) {
      return normalizedFallback;
    }
    return null;
  }

  bool get hasCoverGalleryBinding {
    return (coverGalleryId?.trim().isNotEmpty ?? false) ||
        (lightCoverGalleryId?.trim().isNotEmpty ?? false) ||
        (darkCoverGalleryId?.trim().isNotEmpty ?? false);
  }

  AppAdvancedTheme copyWithCoverGalleryForMode(
    AppAdvancedThemeMode mode, {
    String? galleryId,
    bool clear = false,
  }) {
    return switch (mode) {
      AppAdvancedThemeMode.light => copyWith(
        lightCoverGalleryId: galleryId,
        clearLightCoverGalleryId: clear,
      ),
      AppAdvancedThemeMode.dark => copyWith(
        darkCoverGalleryId: galleryId,
        clearDarkCoverGalleryId: clear,
      ),
    };
  }

  AppAdvancedThemeModeConfig configFor(AppAdvancedThemeMode mode) {
    return switch (mode) {
      AppAdvancedThemeMode.light => lightConfig,
      AppAdvancedThemeMode.dark => darkConfig,
    };
  }

  AppAdvancedTheme copyWithModeConfig(
    AppAdvancedThemeMode mode,
    AppAdvancedThemeModeConfig config,
  ) {
    return switch (mode) {
      AppAdvancedThemeMode.light => copyWith(lightConfig: config),
      AppAdvancedThemeMode.dark => copyWith(darkConfig: config),
    };
  }

  bool get hasBothModesConfigured {
    return lightConfig.colors.configuredColorCount > 0 &&
        darkConfig.colors.configuredColorCount > 0;
  }

  static AppAdvancedThemeModeConfig _readModeConfig({
    required Map<String, dynamic> json,
    required String key,
    required AppAdvancedThemeColors? fallbackColors,
    required String? fallbackWallpaperPath,
  }) {
    final raw = json[key];
    if (raw is Map) {
      return AppAdvancedThemeModeConfig.fromJson(
        raw.map(
          (nestedKey, nestedValue) =>
              MapEntry(nestedKey.toString(), nestedValue),
        ),
      );
    }
    return AppAdvancedThemeModeConfig(
      colors: fallbackColors ?? const AppAdvancedThemeColors(),
      wallpaperPath: fallbackWallpaperPath,
    );
  }

  static AppAdvancedThemeColors? _readLegacyColors(Map<String, dynamic> json) {
    final rawColors = json['colors'];
    if (rawColors is! Map) {
      return null;
    }
    return AppAdvancedThemeColors.fromJson(
      rawColors.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  static DateTime _readDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid required field: $key');
    }
    return parsed;
  }

  static String? _readNullableString(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }
}
