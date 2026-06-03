// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_release.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUpdateReleaseDownload _$AppUpdateReleaseDownloadFromJson(
  Map<String, dynamic> json,
) => AppUpdateReleaseDownload(
  platform: AppUpdateReleaseDownload._nullableStringFromJson(json['platform']),
  label: AppUpdateReleaseDownload._nullableStringFromJson(json['label']),
  downloadUrl: AppUpdateReleaseDownload._nullableStringFromJson(
    json['download_url'],
  ),
  fileName: AppUpdateReleaseDownload._nullableStringFromJson(json['file_name']),
);

AppUpdateRelease _$AppUpdateReleaseFromJson(
  Map<String, dynamic> json,
) => AppUpdateRelease(
  id: AppUpdateRelease._nullableStringFromJson(json['id']),
  appName: AppUpdateRelease._nullableStringFromJson(json['app_name']),
  versionName: AppUpdateRelease._nullableStringFromJson(json['version_name']),
  versionCode: AppUpdateRelease._nullableIntFromJson(json['version_code']),
  forceUpdate: AppUpdateRelease._nullableBoolFromJson(json['force_update']),
  downloadUrl: AppUpdateRelease._nullableStringFromJson(json['download_url']),
  downloads: AppUpdateRelease._downloadsFromJson(json['downloads']),
  changelog: AppUpdateRelease._nullableStringFromJson(json['changelog']),
);
