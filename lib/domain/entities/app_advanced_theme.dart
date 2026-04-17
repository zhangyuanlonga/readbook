enum AppAdvancedThemeMode { light, dark }

class AppAdvancedThemeColors {
  const AppAdvancedThemeColors({
    this.primaryColorValue,
    this.secondaryColorValue,
    this.noticeAccentColorValue,
    this.noticeSurfaceColorValue,
    this.primaryContainerColorValue,
    this.backgroundColorValue,
    this.surfaceColorValue,
    this.elevatedSurfaceColorValue,
    this.cardColorValue,
    this.cardBorderColorValue,
    this.iconBackgroundColorValue,
    this.textPrimaryColorValue,
    this.textSecondaryColorValue,
    this.buttonTextColorValue,
    this.outlineColorValue,
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
  final int? elevatedSurfaceColorValue;
  final int? cardColorValue;
  final int? cardBorderColorValue;
  final int? iconBackgroundColorValue;
  final int? textPrimaryColorValue;
  final int? textSecondaryColorValue;
  final int? buttonTextColorValue;
  final int? outlineColorValue;
  final int? shadowColorValue;
  final int? wallpaperOverlayColorValue;

  Map<String, dynamic> toJson() {
    return {
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
      if (elevatedSurfaceColorValue != null)
        'elevatedSurfaceColorValue': elevatedSurfaceColorValue,
      if (cardColorValue != null) 'cardColorValue': cardColorValue,
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
      if (shadowColorValue != null) 'shadowColorValue': shadowColorValue,
      if (wallpaperOverlayColorValue != null)
        'wallpaperOverlayColorValue': wallpaperOverlayColorValue,
    };
  }

  factory AppAdvancedThemeColors.fromJson(Map<String, dynamic> json) {
    return AppAdvancedThemeColors(
      primaryColorValue: _readInt(json, 'primaryColorValue'),
      secondaryColorValue: _readInt(json, 'secondaryColorValue'),
      noticeAccentColorValue: _readInt(json, 'noticeAccentColorValue'),
      noticeSurfaceColorValue: _readInt(json, 'noticeSurfaceColorValue'),
      primaryContainerColorValue: _readInt(json, 'primaryContainerColorValue'),
      backgroundColorValue: _readInt(json, 'backgroundColorValue'),
      surfaceColorValue: _readInt(json, 'surfaceColorValue'),
      elevatedSurfaceColorValue: _readInt(json, 'elevatedSurfaceColorValue'),
      cardColorValue: _readInt(json, 'cardColorValue'),
      cardBorderColorValue: _readInt(json, 'cardBorderColorValue'),
      iconBackgroundColorValue: _readInt(json, 'iconBackgroundColorValue'),
      textPrimaryColorValue: _readInt(json, 'textPrimaryColorValue'),
      textSecondaryColorValue: _readInt(json, 'textSecondaryColorValue'),
      buttonTextColorValue: _readInt(json, 'buttonTextColorValue'),
      outlineColorValue: _readInt(json, 'outlineColorValue'),
      shadowColorValue: _readInt(json, 'shadowColorValue'),
      wallpaperOverlayColorValue: _readInt(json, 'wallpaperOverlayColorValue'),
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
    int? elevatedSurfaceColorValue,
    bool clearElevatedSurfaceColorValue = false,
    int? cardColorValue,
    bool clearCardColorValue = false,
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
      elevatedSurfaceColorValue:
          clearElevatedSurfaceColorValue
              ? null
              : (elevatedSurfaceColorValue ?? this.elevatedSurfaceColorValue),
      cardColorValue:
          clearCardColorValue ? null : (cardColorValue ?? this.cardColorValue),
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
      elevatedSurfaceColorValue,
      cardColorValue,
      cardBorderColorValue,
      iconBackgroundColorValue,
      textPrimaryColorValue,
      textSecondaryColorValue,
      buttonTextColorValue,
      outlineColorValue,
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
}

class AppAdvancedThemeModeConfig {
  const AppAdvancedThemeModeConfig({
    this.colors = const AppAdvancedThemeColors(),
    this.wallpaperPath,
    this.wallpaperOverlayOpacity = 0.32,
  });

  final AppAdvancedThemeColors colors;
  final String? wallpaperPath;
  final double wallpaperOverlayOpacity;

  Map<String, dynamic> toJson() {
    return {
      'colors': colors.toJson(),
      if (wallpaperPath != null && wallpaperPath!.trim().isNotEmpty)
        'wallpaperPath': wallpaperPath,
      'wallpaperOverlayOpacity': wallpaperOverlayOpacity,
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
      wallpaperPath: _readNullableString(json, 'wallpaperPath'),
      wallpaperOverlayOpacity:
          _readDouble(json, 'wallpaperOverlayOpacity') ?? 0.32,
    );
  }

  AppAdvancedThemeModeConfig copyWith({
    AppAdvancedThemeColors? colors,
    String? wallpaperPath,
    bool clearWallpaperPath = false,
    double? wallpaperOverlayOpacity,
  }) {
    return AppAdvancedThemeModeConfig(
      colors: colors ?? this.colors,
      wallpaperPath:
          clearWallpaperPath ? null : (wallpaperPath ?? this.wallpaperPath),
      wallpaperOverlayOpacity:
          wallpaperOverlayOpacity ?? this.wallpaperOverlayOpacity,
    );
  }

  bool get hasWallpaper {
    final normalized = wallpaperPath?.trim() ?? '';
    return normalized.isNotEmpty;
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
}

class AppAdvancedTheme {
  const AppAdvancedTheme({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.lightConfig,
    required this.darkConfig,
    this.bottomNavGalleryId,
    this.coverGalleryId,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AppAdvancedThemeModeConfig lightConfig;
  final AppAdvancedThemeModeConfig darkConfig;
  final String? bottomNavGalleryId;
  // Fallback cover gallery used when a book has neither real nor custom cover.
  final String? coverGalleryId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lightConfig': lightConfig.toJson(),
      'darkConfig': darkConfig.toJson(),
      if (bottomNavGalleryId != null && bottomNavGalleryId!.trim().isNotEmpty)
        'bottomNavGalleryId': bottomNavGalleryId,
      if (coverGalleryId != null && coverGalleryId!.trim().isNotEmpty)
        'coverGalleryId': coverGalleryId,
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
      bottomNavGalleryId: _readNullableString(json, 'bottomNavGalleryId'),
      coverGalleryId: _readNullableString(json, 'coverGalleryId'),
    );
  }

  AppAdvancedTheme copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    AppAdvancedThemeModeConfig? lightConfig,
    AppAdvancedThemeModeConfig? darkConfig,
    String? bottomNavGalleryId,
    bool clearBottomNavGalleryId = false,
    String? coverGalleryId,
    bool clearCoverGalleryId = false,
  }) {
    return AppAdvancedTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lightConfig: lightConfig ?? this.lightConfig,
      darkConfig: darkConfig ?? this.darkConfig,
      bottomNavGalleryId:
          clearBottomNavGalleryId
              ? null
              : (bottomNavGalleryId ?? this.bottomNavGalleryId),
      coverGalleryId:
          clearCoverGalleryId ? null : (coverGalleryId ?? this.coverGalleryId),
    );
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
