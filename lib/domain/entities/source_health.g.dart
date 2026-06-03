// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'source_health.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SourceHealthSnapshot _$SourceHealthSnapshotFromJson(
  Map<String, dynamic> json,
) => _SourceHealthSnapshot(
  sourceId: _trimmedSourceId(json['sourceId']),
  level: _sourceHealthLevelFromJson(json['level']),
  enabled: _enabledFromJson(json['enabled']),
  cooldownUntil: _parseDateTime(json['cooldownUntil']),
  totalSuccesses:
      json['totalSuccesses'] == null ? 0 : _asInt(json['totalSuccesses']),
  totalFailures:
      json['totalFailures'] == null ? 0 : _asInt(json['totalFailures']),
  consecutiveFailures:
      json['consecutiveFailures'] == null
          ? 0
          : _asInt(json['consecutiveFailures']),
  browserRiskCount:
      json['browserRiskCount'] == null ? 0 : _asInt(json['browserRiskCount']),
  challengeCount:
      json['challengeCount'] == null ? 0 : _asInt(json['challengeCount']),
  timeoutCount: json['timeoutCount'] == null ? 0 : _asInt(json['timeoutCount']),
  avgSearchLatencyMs: _asNullableInt(json['avgSearchLatencyMs']),
  avgDetailLatencyMs: _asNullableInt(json['avgDetailLatencyMs']),
  lastSuccessAt: _parseDateTime(json['lastSuccessAt']),
  lastFailureAt: _parseDateTime(json['lastFailureAt']),
  lastFailureReason: _asNullableString(json['lastFailureReason']),
  lastFailureKind: _parseFailureKind(json['lastFailureKind']),
  lastAutoDisableAt: _parseDateTime(json['lastAutoDisableAt']),
  lastAutoDisableReason: _asNullableString(json['lastAutoDisableReason']),
  userDisabled:
      json['userDisabled'] == null
          ? false
          : _boolFromJson(json['userDisabled']),
  userScoreAdjustment:
      json['userScoreAdjustment'] == null
          ? 0
          : _asInt(json['userScoreAdjustment']),
);

Map<String, dynamic> _$SourceHealthSnapshotToJson(
  _SourceHealthSnapshot instance,
) => <String, dynamic>{
  'sourceId': instance.sourceId,
  'level': _$SourceHealthLevelEnumMap[instance.level]!,
  'enabled': instance.enabled,
  'cooldownUntil': _dateTimeToJson(instance.cooldownUntil),
  'totalSuccesses': instance.totalSuccesses,
  'totalFailures': instance.totalFailures,
  'consecutiveFailures': instance.consecutiveFailures,
  'browserRiskCount': instance.browserRiskCount,
  'challengeCount': instance.challengeCount,
  'timeoutCount': instance.timeoutCount,
  'avgSearchLatencyMs': instance.avgSearchLatencyMs,
  'avgDetailLatencyMs': instance.avgDetailLatencyMs,
  'lastSuccessAt': _dateTimeToJson(instance.lastSuccessAt),
  'lastFailureAt': _dateTimeToJson(instance.lastFailureAt),
  'lastFailureReason': instance.lastFailureReason,
  'lastFailureKind': _failureKindToJson(instance.lastFailureKind),
  'lastAutoDisableAt': _dateTimeToJson(instance.lastAutoDisableAt),
  'lastAutoDisableReason': instance.lastAutoDisableReason,
  'userDisabled': instance.userDisabled,
  'userScoreAdjustment': instance.userScoreAdjustment,
};

const _$SourceHealthLevelEnumMap = {
  SourceHealthLevel.unchecked: 'unchecked',
  SourceHealthLevel.healthy: 'healthy',
  SourceHealthLevel.warning: 'warning',
  SourceHealthLevel.risky: 'risky',
  SourceHealthLevel.unavailable: 'unavailable',
};
