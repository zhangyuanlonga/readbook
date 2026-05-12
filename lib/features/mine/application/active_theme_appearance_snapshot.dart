import '../../../domain/entities/app_advanced_theme.dart';

class ActiveThemeAppearanceSnapshot {
  const ActiveThemeAppearanceSnapshot({
    this.lightConfig,
    this.darkConfig,
    this.appInterfaceFontFamilyKey,
  });

  final AppAdvancedThemeModeConfig? lightConfig;
  final AppAdvancedThemeModeConfig? darkConfig;
  final String? appInterfaceFontFamilyKey;

  factory ActiveThemeAppearanceSnapshot.fromTheme(AppAdvancedTheme theme) {
    return ActiveThemeAppearanceSnapshot(
      lightConfig: theme.lightConfig,
      darkConfig: theme.darkConfig,
      appInterfaceFontFamilyKey: theme.appInterfaceFontFamilyKey,
    );
  }

  factory ActiveThemeAppearanceSnapshot.fromJson(Map<String, dynamic> json) {
    return ActiveThemeAppearanceSnapshot(
      lightConfig:
          json['lightConfig'] is Map
              ? AppAdvancedThemeModeConfig.fromJson(
                (json['lightConfig'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : null,
      darkConfig:
          json['darkConfig'] is Map
              ? AppAdvancedThemeModeConfig.fromJson(
                (json['darkConfig'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              )
              : null,
      appInterfaceFontFamilyKey:
          json['appInterfaceFontFamilyKey']?.toString().trim().isEmpty ?? true
              ? null
              : json['appInterfaceFontFamilyKey']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (lightConfig != null) 'lightConfig': lightConfig!.toJson(),
      if (darkConfig != null) 'darkConfig': darkConfig!.toJson(),
      if (appInterfaceFontFamilyKey != null &&
          appInterfaceFontFamilyKey!.trim().isNotEmpty)
        'appInterfaceFontFamilyKey': appInterfaceFontFamilyKey!.trim(),
    };
  }
}
