import 'package:json_annotation/json_annotation.dart';

import 'reader_settings.dart';

part 'reader_visual_overrides.g.dart';

@JsonSerializable(createFactory: false)
class ReaderVisualOverrides {
  const ReaderVisualOverrides({
    this.hasBackgroundImageOverride = false,
    this.backgroundImageBase64,
    this.fontSource,
    this.systemFontPreset,
    this.hasFontFamilyKeyOverride = false,
    this.fontFamilyKey,
    this.hasCustomFontPathOverride = false,
    this.customFontPath,
  });

  static const ReaderVisualOverrides empty = ReaderVisualOverrides();

  final bool hasBackgroundImageOverride;
  final String? backgroundImageBase64;
  final ReaderFontSource? fontSource;
  final ReaderSystemFontPreset? systemFontPreset;
  final bool hasFontFamilyKeyOverride;
  final String? fontFamilyKey;
  final bool hasCustomFontPathOverride;
  final String? customFontPath;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasFontBindingOverride {
    return fontSource != null ||
        systemFontPreset != null ||
        hasFontFamilyKeyOverride ||
        hasCustomFontPathOverride;
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get isEmpty {
    return !hasBackgroundImageOverride && !hasFontBindingOverride;
  }

  ReaderVisualOverrides copyWith({
    bool? hasBackgroundImageOverride,
    String? backgroundImageBase64,
    bool clearBackgroundImageOverride = false,
    ReaderFontSource? fontSource,
    bool clearFontSource = false,
    ReaderSystemFontPreset? systemFontPreset,
    bool clearSystemFontPreset = false,
    bool? hasFontFamilyKeyOverride,
    String? fontFamilyKey,
    bool clearFontFamilyKeyOverride = false,
    bool? hasCustomFontPathOverride,
    String? customFontPath,
    bool clearCustomFontPathOverride = false,
  }) {
    return ReaderVisualOverrides(
      hasBackgroundImageOverride:
          clearBackgroundImageOverride
              ? false
              : (hasBackgroundImageOverride ?? this.hasBackgroundImageOverride),
      backgroundImageBase64:
          clearBackgroundImageOverride
              ? null
              : (backgroundImageBase64 ?? this.backgroundImageBase64),
      fontSource: clearFontSource ? null : (fontSource ?? this.fontSource),
      systemFontPreset:
          clearSystemFontPreset
              ? null
              : (systemFontPreset ?? this.systemFontPreset),
      hasFontFamilyKeyOverride:
          clearFontFamilyKeyOverride
              ? false
              : (hasFontFamilyKeyOverride ?? this.hasFontFamilyKeyOverride),
      fontFamilyKey:
          clearFontFamilyKeyOverride
              ? null
              : (fontFamilyKey ?? this.fontFamilyKey),
      hasCustomFontPathOverride:
          clearCustomFontPathOverride
              ? false
              : (hasCustomFontPathOverride ?? this.hasCustomFontPathOverride),
      customFontPath:
          clearCustomFontPathOverride
              ? null
              : (customFontPath ?? this.customFontPath),
    );
  }

  Map<String, dynamic> toJson() => _$ReaderVisualOverridesToJson(this);

  factory ReaderVisualOverrides.fromJson(Map<String, dynamic> json) {
    final fontSourceName = json['fontSource']?.toString();
    final systemFontPresetName = json['systemFontPreset']?.toString();
    final fontFamilyKey = json['fontFamilyKey']?.toString().trim();
    final customFontPath = json['customFontPath']?.toString().trim();
    final backgroundImageBase64 =
        json['backgroundImageBase64']?.toString().trim();
    final base = ReaderVisualOverrides(
      hasBackgroundImageOverride:
          _asBool(json['hasBackgroundImageOverride']) ?? false,
      backgroundImageBase64:
          backgroundImageBase64 == null || backgroundImageBase64.isEmpty
              ? null
              : backgroundImageBase64,
      fontSource: ReaderFontSource.values.firstWhere(
        (item) => item.name == fontSourceName,
        orElse: () => ReaderFontSource.system,
      ),
      systemFontPreset: ReaderSystemFontPreset.values.firstWhere(
        (item) => item.name == systemFontPresetName,
        orElse: () => ReaderSystemFontPreset.defaultSans,
      ),
      hasFontFamilyKeyOverride:
          _asBool(json['hasFontFamilyKeyOverride']) ?? false,
      fontFamilyKey:
          fontFamilyKey == null || fontFamilyKey.isEmpty ? null : fontFamilyKey,
      hasCustomFontPathOverride:
          _asBool(json['hasCustomFontPathOverride']) ?? false,
      customFontPath:
          customFontPath == null || customFontPath.isEmpty
              ? null
              : customFontPath,
    );
    return base._normalizeOptionalEnums(
      rawFontSource: fontSourceName,
      rawSystemFontPreset: systemFontPresetName,
    );
  }

  ReaderVisualOverrides _normalizeOptionalEnums({
    required String? rawFontSource,
    required String? rawSystemFontPreset,
  }) {
    return ReaderVisualOverrides(
      hasBackgroundImageOverride: hasBackgroundImageOverride,
      backgroundImageBase64: backgroundImageBase64,
      fontSource:
          rawFontSource == null || rawFontSource.trim().isEmpty
              ? null
              : fontSource,
      systemFontPreset:
          rawSystemFontPreset == null || rawSystemFontPreset.trim().isEmpty
              ? null
              : systemFontPreset,
      hasFontFamilyKeyOverride: hasFontFamilyKeyOverride,
      fontFamilyKey: fontFamilyKey,
      hasCustomFontPathOverride: hasCustomFontPathOverride,
      customFontPath: customFontPath,
    );
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
    return null;
  }
}
