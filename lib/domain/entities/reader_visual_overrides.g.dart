// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_visual_overrides.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$ReaderVisualOverridesToJson(
  ReaderVisualOverrides instance,
) => <String, dynamic>{
  'hasBackgroundImageOverride': instance.hasBackgroundImageOverride,
  'backgroundImageBase64': instance.backgroundImageBase64,
  'fontSource': _$ReaderFontSourceEnumMap[instance.fontSource],
  'systemFontPreset':
      _$ReaderSystemFontPresetEnumMap[instance.systemFontPreset],
  'hasFontFamilyKeyOverride': instance.hasFontFamilyKeyOverride,
  'fontFamilyKey': instance.fontFamilyKey,
  'hasCustomFontPathOverride': instance.hasCustomFontPathOverride,
  'customFontPath': instance.customFontPath,
};

const _$ReaderFontSourceEnumMap = {
  ReaderFontSource.system: 'system',
  ReaderFontSource.builtin: 'builtin',
  ReaderFontSource.custom: 'custom',
};

const _$ReaderSystemFontPresetEnumMap = {
  ReaderSystemFontPreset.defaultSans: 'defaultSans',
  ReaderSystemFontPreset.serif: 'serif',
  ReaderSystemFontPreset.monospace: 'monospace',
};
