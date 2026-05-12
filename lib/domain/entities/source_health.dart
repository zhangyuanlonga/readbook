class SourceHealthSnapshot {
  const SourceHealthSnapshot({
    required this.sourceId,
    required this.level,
    required this.enabled,
    this.cooldownUntil,
    this.totalSuccesses = 0,
    this.totalFailures = 0,
    this.consecutiveFailures = 0,
    this.browserRiskCount = 0,
    this.challengeCount = 0,
    this.timeoutCount = 0,
    this.avgSearchLatencyMs,
    this.avgDetailLatencyMs,
    this.lastSuccessAt,
    this.lastFailureAt,
    this.lastFailureReason,
    this.lastFailureKind,
    this.lastAutoDisableAt,
    this.lastAutoDisableReason,
    this.userDisabled = false,
    this.userScoreAdjustment = 0,
  });

  final String sourceId;
  final SourceHealthLevel level;
  final bool enabled;
  final DateTime? cooldownUntil;
  final int totalSuccesses;
  final int totalFailures;
  final int consecutiveFailures;
  final int browserRiskCount;
  final int challengeCount;
  final int timeoutCount;
  final int? avgSearchLatencyMs;
  final int? avgDetailLatencyMs;
  final DateTime? lastSuccessAt;
  final DateTime? lastFailureAt;
  final String? lastFailureReason;
  final SourceHealthFailureKind? lastFailureKind;
  final DateTime? lastAutoDisableAt;
  final String? lastAutoDisableReason;
  final bool userDisabled;
  final int userScoreAdjustment;

  bool get coolingDown {
    final until = cooldownUntil;
    if (until == null) {
      return false;
    }
    return until.isAfter(DateTime.now());
  }

  SourceHealthSnapshot copyWith({
    String? sourceId,
    SourceHealthLevel? level,
    bool? enabled,
    Object? cooldownUntil = _sentinel,
    int? totalSuccesses,
    int? totalFailures,
    int? consecutiveFailures,
    int? browserRiskCount,
    int? challengeCount,
    int? timeoutCount,
    Object? avgSearchLatencyMs = _sentinel,
    Object? avgDetailLatencyMs = _sentinel,
    Object? lastSuccessAt = _sentinel,
    Object? lastFailureAt = _sentinel,
    Object? lastFailureReason = _sentinel,
    Object? lastFailureKind = _sentinel,
    Object? lastAutoDisableAt = _sentinel,
    Object? lastAutoDisableReason = _sentinel,
    bool? userDisabled,
    int? userScoreAdjustment,
  }) {
    return SourceHealthSnapshot(
      sourceId: sourceId ?? this.sourceId,
      level: level ?? this.level,
      enabled: enabled ?? this.enabled,
      cooldownUntil:
          identical(cooldownUntil, _sentinel)
              ? this.cooldownUntil
              : cooldownUntil as DateTime?,
      totalSuccesses: totalSuccesses ?? this.totalSuccesses,
      totalFailures: totalFailures ?? this.totalFailures,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      browserRiskCount: browserRiskCount ?? this.browserRiskCount,
      challengeCount: challengeCount ?? this.challengeCount,
      timeoutCount: timeoutCount ?? this.timeoutCount,
      avgSearchLatencyMs:
          identical(avgSearchLatencyMs, _sentinel)
              ? this.avgSearchLatencyMs
              : avgSearchLatencyMs as int?,
      avgDetailLatencyMs:
          identical(avgDetailLatencyMs, _sentinel)
              ? this.avgDetailLatencyMs
              : avgDetailLatencyMs as int?,
      lastSuccessAt:
          identical(lastSuccessAt, _sentinel)
              ? this.lastSuccessAt
              : lastSuccessAt as DateTime?,
      lastFailureAt:
          identical(lastFailureAt, _sentinel)
              ? this.lastFailureAt
              : lastFailureAt as DateTime?,
      lastFailureReason:
          identical(lastFailureReason, _sentinel)
              ? this.lastFailureReason
              : lastFailureReason as String?,
      lastFailureKind:
          identical(lastFailureKind, _sentinel)
              ? this.lastFailureKind
              : lastFailureKind as SourceHealthFailureKind?,
      lastAutoDisableAt:
          identical(lastAutoDisableAt, _sentinel)
              ? this.lastAutoDisableAt
              : lastAutoDisableAt as DateTime?,
      lastAutoDisableReason:
          identical(lastAutoDisableReason, _sentinel)
              ? this.lastAutoDisableReason
              : lastAutoDisableReason as String?,
      userDisabled: userDisabled ?? this.userDisabled,
      userScoreAdjustment: userScoreAdjustment ?? this.userScoreAdjustment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sourceId': sourceId,
      'level': level.name,
      'enabled': enabled,
      'cooldownUntil': cooldownUntil?.toIso8601String(),
      'totalSuccesses': totalSuccesses,
      'totalFailures': totalFailures,
      'consecutiveFailures': consecutiveFailures,
      'browserRiskCount': browserRiskCount,
      'challengeCount': challengeCount,
      'timeoutCount': timeoutCount,
      'avgSearchLatencyMs': avgSearchLatencyMs,
      'avgDetailLatencyMs': avgDetailLatencyMs,
      'lastSuccessAt': lastSuccessAt?.toIso8601String(),
      'lastFailureAt': lastFailureAt?.toIso8601String(),
      'lastFailureReason': lastFailureReason,
      'lastFailureKind': lastFailureKind?.name,
      'lastAutoDisableAt': lastAutoDisableAt?.toIso8601String(),
      'lastAutoDisableReason': lastAutoDisableReason,
      'userDisabled': userDisabled,
      'userScoreAdjustment': userScoreAdjustment,
    };
  }

  factory SourceHealthSnapshot.fromJson(Map<String, dynamic> json) {
    return SourceHealthSnapshot(
      sourceId: (json['sourceId']?.toString() ?? '').trim(),
      level: SourceHealthLevel.values.byName(
        (json['level']?.toString() ?? SourceHealthLevel.healthy.name).trim(),
      ),
      enabled: json['enabled'] != false,
      cooldownUntil: _parseDateTime(json['cooldownUntil']),
      totalSuccesses: _asInt(json['totalSuccesses']),
      totalFailures: _asInt(json['totalFailures']),
      consecutiveFailures: _asInt(json['consecutiveFailures']),
      browserRiskCount: _asInt(json['browserRiskCount']),
      challengeCount: _asInt(json['challengeCount']),
      timeoutCount: _asInt(json['timeoutCount']),
      avgSearchLatencyMs: _asNullableInt(json['avgSearchLatencyMs']),
      avgDetailLatencyMs: _asNullableInt(json['avgDetailLatencyMs']),
      lastSuccessAt: _parseDateTime(json['lastSuccessAt']),
      lastFailureAt: _parseDateTime(json['lastFailureAt']),
      lastFailureReason: _asNullableString(json['lastFailureReason']),
      lastFailureKind: _parseFailureKind(json['lastFailureKind']),
      lastAutoDisableAt: _parseDateTime(json['lastAutoDisableAt']),
      lastAutoDisableReason: _asNullableString(json['lastAutoDisableReason']),
      userDisabled: json['userDisabled'] == true,
      userScoreAdjustment: _asInt(json['userScoreAdjustment']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(Object? value) {
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

  static String? _asNullableString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static DateTime? _parseDateTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static SourceHealthFailureKind? _parseFailureKind(Object? value) {
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

const Object _sentinel = Object();
