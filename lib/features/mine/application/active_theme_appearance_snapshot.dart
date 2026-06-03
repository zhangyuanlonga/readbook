import 'package:json_annotation/json_annotation.dart';

import '../../../domain/entities/app_advanced_theme.dart';

part 'active_theme_appearance_snapshot.g.dart';

@JsonSerializable(explicitToJson: true)
class ActiveThemeAppearanceSnapshot {
  const ActiveThemeAppearanceSnapshot({
    this.lightConfig,
    this.darkConfig,
    this.appInterfaceFontFamilyKey,
  });

  @JsonKey(fromJson: _modeConfigFromJson, toJson: _modeConfigToJson)
  final AppAdvancedThemeModeConfig? lightConfig;
  @JsonKey(fromJson: _modeConfigFromJson, toJson: _modeConfigToJson)
  final AppAdvancedThemeModeConfig? darkConfig;
  @JsonKey(fromJson: _fontFamilyKeyFromJson, toJson: _fontFamilyKeyToJson)
  final String? appInterfaceFontFamilyKey;

  factory ActiveThemeAppearanceSnapshot.fromTheme(AppAdvancedTheme theme) {
    return ActiveThemeAppearanceSnapshot(
      lightConfig: theme.lightConfig,
      darkConfig: theme.darkConfig,
      appInterfaceFontFamilyKey: theme.appInterfaceFontFamilyKey,
    );
  }

  factory ActiveThemeAppearanceSnapshot.fromJson(Map<String, dynamic> json) {
    final decoded = _$ActiveThemeAppearanceSnapshotFromJson(json);
    return ActiveThemeAppearanceSnapshot(
      lightConfig: decoded.lightConfig,
      darkConfig: decoded.darkConfig,
      appInterfaceFontFamilyKey: _fontFamilyKeyFromJson(
        decoded.appInterfaceFontFamilyKey,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    final json = _$ActiveThemeAppearanceSnapshotToJson(this);
    json.removeWhere((key, value) => value == null);
    return json;
  }
}

AppAdvancedThemeModeConfig? _modeConfigFromJson(Object? value) {
  if (value is! Map) {
    return null;
  }
  return AppAdvancedThemeModeConfig.fromJson(
    value.map((key, val) => MapEntry(key.toString(), val)),
  );
}

Map<String, dynamic>? _modeConfigToJson(AppAdvancedThemeModeConfig? value) {
  return value?.toJson();
}

String? _fontFamilyKeyFromJson(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

String? _fontFamilyKeyToJson(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
