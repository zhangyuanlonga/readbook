// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_theme_appearance_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActiveThemeAppearanceSnapshot _$ActiveThemeAppearanceSnapshotFromJson(
  Map<String, dynamic> json,
) => ActiveThemeAppearanceSnapshot(
  lightConfig: _modeConfigFromJson(json['lightConfig']),
  darkConfig: _modeConfigFromJson(json['darkConfig']),
  appInterfaceFontFamilyKey: _fontFamilyKeyFromJson(
    json['appInterfaceFontFamilyKey'],
  ),
);

Map<String, dynamic> _$ActiveThemeAppearanceSnapshotToJson(
  ActiveThemeAppearanceSnapshot instance,
) => <String, dynamic>{
  'lightConfig': _modeConfigToJson(instance.lightConfig),
  'darkConfig': _modeConfigToJson(instance.darkConfig),
  'appInterfaceFontFamilyKey': _fontFamilyKeyToJson(
    instance.appInterfaceFontFamilyKey,
  ),
};
