import 'package:json_annotation/json_annotation.dart';

import 'app_update_release.dart';

part 'app_update_check_result.g.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.release,
    required this.hasUpdate,
    required this.forceUpdate,
  });

  final AppUpdateRelease? release;
  final bool hasUpdate;
  final bool forceUpdate;

  factory AppUpdateCheckResult.fromJson(
    Map<String, dynamic> json, {
    required int currentVersionCode,
  }) {
    final response = AppUpdateCheckResponseDto.fromJson(
      _normalizeResponseJson(json),
    );

    if (response.release == null) {
      return AppUpdateCheckResult(
        release: null,
        hasUpdate: response.hasUpdate ?? false,
        forceUpdate: response.forceUpdate ?? false,
      );
    }

    final release = response.release!;
    final releaseCode = release.versionCode;
    final computedHasUpdate =
        releaseCode == null ? true : releaseCode > currentVersionCode;
    final hasUpdate = response.hasUpdate ?? computedHasUpdate;
    final forceUpdate = response.forceUpdate ?? (release.forceUpdate ?? false);

    return AppUpdateCheckResult(
      release: release,
      hasUpdate: hasUpdate,
      forceUpdate: forceUpdate,
    );
  }

  static Map<String, dynamic> _normalizeResponseJson(
    Map<String, dynamic> json,
  ) {
    Map<String, dynamic>? releaseMap;

    final hasUpdateFlag =
        AppUpdateCheckResponseDto.nullableBoolFromJson(json['has_update']) ??
        AppUpdateCheckResponseDto.nullableBoolFromJson(json['hasUpdate']);
    final forceUpdateFlag =
        AppUpdateCheckResponseDto.nullableBoolFromJson(json['force_update']) ??
        AppUpdateCheckResponseDto.nullableBoolFromJson(json['forceUpdate']);

    releaseMap =
        _asStringKeyMap(json['latest_version']) ??
        _asStringKeyMap(json['latestVersion']) ??
        _asStringKeyMap(json['release']) ??
        _asStringKeyMap(json['update']);

    if (releaseMap == null &&
        (json.containsKey('version_code') ||
            json.containsKey('version_name') ||
            json.containsKey('min_supported_code'))) {
      releaseMap = Map<String, dynamic>.of(json);
    }

    if (releaseMap != null && forceUpdateFlag != null) {
      releaseMap = {...releaseMap, 'force_update': forceUpdateFlag};
    }

    return <String, dynamic>{
      'has_update': hasUpdateFlag,
      'force_update': forceUpdateFlag,
      'latest_version': releaseMap,
    };
  }

  static Map<String, dynamic>? _asStringKeyMap(Object? value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
}

@JsonSerializable(createToJson: false)
class AppUpdateCheckResponseDto {
  const AppUpdateCheckResponseDto({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.release,
  });

  @JsonKey(name: 'has_update', fromJson: nullableBoolFromJson)
  final bool? hasUpdate;
  @JsonKey(name: 'force_update', fromJson: nullableBoolFromJson)
  final bool? forceUpdate;
  @JsonKey(name: 'latest_version')
  final AppUpdateRelease? release;

  factory AppUpdateCheckResponseDto.fromJson(Map<String, dynamic> json) =>
      _$AppUpdateCheckResponseDtoFromJson(json);

  static bool? nullableBoolFromJson(Object? value) {
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
