import 'package:json_annotation/json_annotation.dart';

part 'app_update_release.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class AppUpdateReleaseDownload {
  const AppUpdateReleaseDownload({
    required this.platform,
    required this.label,
    required this.downloadUrl,
    required this.fileName,
  });

  @JsonKey(fromJson: _nullableStringFromJson)
  final String? platform;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? label;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? downloadUrl;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? fileName;

  factory AppUpdateReleaseDownload.fromJson(Map<String, dynamic> json) =>
      _$AppUpdateReleaseDownloadFromJson(json);

  static String? _nullableStringFromJson(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

@JsonSerializable(fieldRename: FieldRename.snake, createToJson: false)
class AppUpdateRelease {
  const AppUpdateRelease({
    required this.id,
    required this.appName,
    required this.versionName,
    required this.versionCode,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.downloads,
    required this.changelog,
  });

  @JsonKey(fromJson: _nullableStringFromJson)
  final String? id;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? appName;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? versionName;
  @JsonKey(fromJson: _nullableIntFromJson)
  final int? versionCode;
  @JsonKey(fromJson: _nullableBoolFromJson)
  final bool? forceUpdate;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? downloadUrl;
  @JsonKey(fromJson: _downloadsFromJson)
  final List<AppUpdateReleaseDownload> downloads;
  @JsonKey(fromJson: _nullableStringFromJson)
  final String? changelog;

  factory AppUpdateRelease.fromJson(Map<String, dynamic> json) =>
      _$AppUpdateReleaseFromJson(json);

  static String? _nullableStringFromJson(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static int? _nullableIntFromJson(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _nullableBoolFromJson(Object? value) {
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

  static List<AppUpdateReleaseDownload> _downloadsFromJson(Object? value) {
    if (value is! List) {
      return const <AppUpdateReleaseDownload>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => AppUpdateReleaseDownload.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }
}
