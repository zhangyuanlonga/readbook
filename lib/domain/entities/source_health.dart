// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'source_health.freezed.dart';
part 'source_health.g.dart';

@freezed
abstract class SourceHealthSnapshot with _$SourceHealthSnapshot {
  const factory SourceHealthSnapshot({
    @JsonKey(fromJson: _trimmedSourceId) required String sourceId,
    @JsonKey(fromJson: _sourceHealthLevelFromJson)
    required SourceHealthLevel level,
    @JsonKey(fromJson: _enabledFromJson) required bool enabled,
    @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
    DateTime? cooldownUntil,
    @JsonKey(fromJson: _asInt) @Default(0) int totalSuccesses,
    @JsonKey(fromJson: _asInt) @Default(0) int totalFailures,
    @JsonKey(fromJson: _asInt) @Default(0) int consecutiveFailures,
    @JsonKey(fromJson: _asInt) @Default(0) int browserRiskCount,
    @JsonKey(fromJson: _asInt) @Default(0) int challengeCount,
    @JsonKey(fromJson: _asInt) @Default(0) int timeoutCount,
    @JsonKey(fromJson: _asNullableInt) int? avgSearchLatencyMs,
    @JsonKey(fromJson: _asNullableInt) int? avgDetailLatencyMs,
    @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
    DateTime? lastSuccessAt,
    @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
    DateTime? lastFailureAt,
    @JsonKey(fromJson: _asNullableString) String? lastFailureReason,
    @JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson)
    SourceHealthFailureKind? lastFailureKind,
    @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)
    DateTime? lastAutoDisableAt,
    @JsonKey(fromJson: _asNullableString) String? lastAutoDisableReason,
    @JsonKey(fromJson: _boolFromJson) @Default(false) bool userDisabled,
    @JsonKey(fromJson: _asInt) @Default(0) int userScoreAdjustment,
  }) = _SourceHealthSnapshot;

  const SourceHealthSnapshot._();

  factory SourceHealthSnapshot.fromJson(Map<String, dynamic> json) =>
      _$SourceHealthSnapshotFromJson(json);

  bool get coolingDown {
    final until = cooldownUntil;
    if (until == null) {
      return false;
    }
    return until.isAfter(DateTime.now());
  }
}

enum SourceHealthLevel { unchecked, healthy, warning, risky, unavailable }

enum SourceHealthFailureKind {
  network,
  timeout,
  browserChallenge,
  parser,
  emptyResult,
  cancelled,
  disabled,
  unknown,
}

String _trimmedSourceId(Object? value) => value?.toString().trim() ?? '';

SourceHealthLevel _sourceHealthLevelFromJson(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return SourceHealthLevel.healthy;
  }
  for (final level in SourceHealthLevel.values) {
    if (level.name == raw) {
      return level;
    }
  }
  return SourceHealthLevel.healthy;
}

bool _enabledFromJson(Object? value) => value != false;

bool _boolFromJson(Object? value) => value == true;

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

String? _asNullableString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

DateTime? _parseDateTime(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String? _dateTimeToJson(DateTime? value) => value?.toIso8601String();

SourceHealthFailureKind? _parseFailureKind(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  for (final kind in SourceHealthFailureKind.values) {
    if (kind.name == raw) {
      return kind;
    }
  }
  return null;
}

String? _failureKindToJson(SourceHealthFailureKind? value) => value?.name;
