// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_check_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUpdateCheckResponseDto _$AppUpdateCheckResponseDtoFromJson(
  Map<String, dynamic> json,
) => AppUpdateCheckResponseDto(
  hasUpdate: AppUpdateCheckResponseDto.nullableBoolFromJson(json['has_update']),
  forceUpdate: AppUpdateCheckResponseDto.nullableBoolFromJson(
    json['force_update'],
  ),
  release:
      json['latest_version'] == null
          ? null
          : AppUpdateRelease.fromJson(
            json['latest_version'] as Map<String, dynamic>,
          ),
);
