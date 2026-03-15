import 'app_update_release.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.release,
    required this.hasUpdate,
  });

  final AppUpdateRelease? release;
  final bool hasUpdate;

  factory AppUpdateCheckResult.fromJson(
    Map<String, dynamic> json, {
    required int currentVersionCode,
  }) {
    Map<String, dynamic>? releaseMap;

    Map<String, dynamic>? asMap(Object? value) {
      if (value is Map) {
        return value.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    }

    bool? readBool(Object? value) {
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

    final hasUpdateFlag =
        readBool(json['has_update']) ?? readBool(json['hasUpdate']);
    final forceUpdateFlag =
        readBool(json['force_update']) ?? readBool(json['forceUpdate']);

    releaseMap =
        asMap(json['latest_version']) ??
        asMap(json['latestVersion']) ??
        asMap(json['release']) ??
        asMap(json['update']);

    if (releaseMap == null &&
        (json.containsKey('version_code') ||
            json.containsKey('version_name') ||
            json.containsKey('min_supported_code'))) {
      releaseMap = json;
    }

    if (releaseMap == null) {
      return AppUpdateCheckResult(
        release: null,
        hasUpdate: hasUpdateFlag ?? false,
      );
    }

    if (forceUpdateFlag != null && !releaseMap.containsKey('force_update')) {
      releaseMap = {
        ...releaseMap,
        'force_update': forceUpdateFlag,
      };
    }

    final release = AppUpdateRelease.fromJson(releaseMap);
    final releaseCode = release.versionCode;
    final computedHasUpdate =
        releaseCode == null ? true : releaseCode > currentVersionCode;
    final hasUpdate = hasUpdateFlag ?? computedHasUpdate;

    return AppUpdateCheckResult(release: release, hasUpdate: hasUpdate);
  }
}
