// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceHealthSnapshot {

@JsonKey(fromJson: _trimmedSourceId) String get sourceId;@JsonKey(fromJson: _sourceHealthLevelFromJson) SourceHealthLevel get level;@JsonKey(fromJson: _enabledFromJson) bool get enabled;@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? get cooldownUntil;@JsonKey(fromJson: _asInt) int get totalSuccesses;@JsonKey(fromJson: _asInt) int get totalFailures;@JsonKey(fromJson: _asInt) int get consecutiveFailures;@JsonKey(fromJson: _asInt) int get browserRiskCount;@JsonKey(fromJson: _asInt) int get challengeCount;@JsonKey(fromJson: _asInt) int get timeoutCount;@JsonKey(fromJson: _asNullableInt) int? get avgSearchLatencyMs;@JsonKey(fromJson: _asNullableInt) int? get avgDetailLatencyMs;@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? get lastSuccessAt;@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? get lastFailureAt;@JsonKey(fromJson: _asNullableString) String? get lastFailureReason;@JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson) SourceHealthFailureKind? get lastFailureKind;@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? get lastAutoDisableAt;@JsonKey(fromJson: _asNullableString) String? get lastAutoDisableReason;@JsonKey(fromJson: _boolFromJson) bool get userDisabled;@JsonKey(fromJson: _asInt) int get userScoreAdjustment;
/// Create a copy of SourceHealthSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceHealthSnapshotCopyWith<SourceHealthSnapshot> get copyWith => _$SourceHealthSnapshotCopyWithImpl<SourceHealthSnapshot>(this as SourceHealthSnapshot, _$identity);

  /// Serializes this SourceHealthSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceHealthSnapshot&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.level, level) || other.level == level)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.totalSuccesses, totalSuccesses) || other.totalSuccesses == totalSuccesses)&&(identical(other.totalFailures, totalFailures) || other.totalFailures == totalFailures)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.browserRiskCount, browserRiskCount) || other.browserRiskCount == browserRiskCount)&&(identical(other.challengeCount, challengeCount) || other.challengeCount == challengeCount)&&(identical(other.timeoutCount, timeoutCount) || other.timeoutCount == timeoutCount)&&(identical(other.avgSearchLatencyMs, avgSearchLatencyMs) || other.avgSearchLatencyMs == avgSearchLatencyMs)&&(identical(other.avgDetailLatencyMs, avgDetailLatencyMs) || other.avgDetailLatencyMs == avgDetailLatencyMs)&&(identical(other.lastSuccessAt, lastSuccessAt) || other.lastSuccessAt == lastSuccessAt)&&(identical(other.lastFailureAt, lastFailureAt) || other.lastFailureAt == lastFailureAt)&&(identical(other.lastFailureReason, lastFailureReason) || other.lastFailureReason == lastFailureReason)&&(identical(other.lastFailureKind, lastFailureKind) || other.lastFailureKind == lastFailureKind)&&(identical(other.lastAutoDisableAt, lastAutoDisableAt) || other.lastAutoDisableAt == lastAutoDisableAt)&&(identical(other.lastAutoDisableReason, lastAutoDisableReason) || other.lastAutoDisableReason == lastAutoDisableReason)&&(identical(other.userDisabled, userDisabled) || other.userDisabled == userDisabled)&&(identical(other.userScoreAdjustment, userScoreAdjustment) || other.userScoreAdjustment == userScoreAdjustment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,sourceId,level,enabled,cooldownUntil,totalSuccesses,totalFailures,consecutiveFailures,browserRiskCount,challengeCount,timeoutCount,avgSearchLatencyMs,avgDetailLatencyMs,lastSuccessAt,lastFailureAt,lastFailureReason,lastFailureKind,lastAutoDisableAt,lastAutoDisableReason,userDisabled,userScoreAdjustment]);

@override
String toString() {
  return 'SourceHealthSnapshot(sourceId: $sourceId, level: $level, enabled: $enabled, cooldownUntil: $cooldownUntil, totalSuccesses: $totalSuccesses, totalFailures: $totalFailures, consecutiveFailures: $consecutiveFailures, browserRiskCount: $browserRiskCount, challengeCount: $challengeCount, timeoutCount: $timeoutCount, avgSearchLatencyMs: $avgSearchLatencyMs, avgDetailLatencyMs: $avgDetailLatencyMs, lastSuccessAt: $lastSuccessAt, lastFailureAt: $lastFailureAt, lastFailureReason: $lastFailureReason, lastFailureKind: $lastFailureKind, lastAutoDisableAt: $lastAutoDisableAt, lastAutoDisableReason: $lastAutoDisableReason, userDisabled: $userDisabled, userScoreAdjustment: $userScoreAdjustment)';
}


}

/// @nodoc
abstract mixin class $SourceHealthSnapshotCopyWith<$Res>  {
  factory $SourceHealthSnapshotCopyWith(SourceHealthSnapshot value, $Res Function(SourceHealthSnapshot) _then) = _$SourceHealthSnapshotCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _trimmedSourceId) String sourceId,@JsonKey(fromJson: _sourceHealthLevelFromJson) SourceHealthLevel level,@JsonKey(fromJson: _enabledFromJson) bool enabled,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? cooldownUntil,@JsonKey(fromJson: _asInt) int totalSuccesses,@JsonKey(fromJson: _asInt) int totalFailures,@JsonKey(fromJson: _asInt) int consecutiveFailures,@JsonKey(fromJson: _asInt) int browserRiskCount,@JsonKey(fromJson: _asInt) int challengeCount,@JsonKey(fromJson: _asInt) int timeoutCount,@JsonKey(fromJson: _asNullableInt) int? avgSearchLatencyMs,@JsonKey(fromJson: _asNullableInt) int? avgDetailLatencyMs,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastSuccessAt,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastFailureAt,@JsonKey(fromJson: _asNullableString) String? lastFailureReason,@JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson) SourceHealthFailureKind? lastFailureKind,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastAutoDisableAt,@JsonKey(fromJson: _asNullableString) String? lastAutoDisableReason,@JsonKey(fromJson: _boolFromJson) bool userDisabled,@JsonKey(fromJson: _asInt) int userScoreAdjustment
});




}
/// @nodoc
class _$SourceHealthSnapshotCopyWithImpl<$Res>
    implements $SourceHealthSnapshotCopyWith<$Res> {
  _$SourceHealthSnapshotCopyWithImpl(this._self, this._then);

  final SourceHealthSnapshot _self;
  final $Res Function(SourceHealthSnapshot) _then;

/// Create a copy of SourceHealthSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? level = null,Object? enabled = null,Object? cooldownUntil = freezed,Object? totalSuccesses = null,Object? totalFailures = null,Object? consecutiveFailures = null,Object? browserRiskCount = null,Object? challengeCount = null,Object? timeoutCount = null,Object? avgSearchLatencyMs = freezed,Object? avgDetailLatencyMs = freezed,Object? lastSuccessAt = freezed,Object? lastFailureAt = freezed,Object? lastFailureReason = freezed,Object? lastFailureKind = freezed,Object? lastAutoDisableAt = freezed,Object? lastAutoDisableReason = freezed,Object? userDisabled = null,Object? userScoreAdjustment = null,}) {
  return _then(_self.copyWith(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as SourceHealthLevel,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,totalSuccesses: null == totalSuccesses ? _self.totalSuccesses : totalSuccesses // ignore: cast_nullable_to_non_nullable
as int,totalFailures: null == totalFailures ? _self.totalFailures : totalFailures // ignore: cast_nullable_to_non_nullable
as int,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,browserRiskCount: null == browserRiskCount ? _self.browserRiskCount : browserRiskCount // ignore: cast_nullable_to_non_nullable
as int,challengeCount: null == challengeCount ? _self.challengeCount : challengeCount // ignore: cast_nullable_to_non_nullable
as int,timeoutCount: null == timeoutCount ? _self.timeoutCount : timeoutCount // ignore: cast_nullable_to_non_nullable
as int,avgSearchLatencyMs: freezed == avgSearchLatencyMs ? _self.avgSearchLatencyMs : avgSearchLatencyMs // ignore: cast_nullable_to_non_nullable
as int?,avgDetailLatencyMs: freezed == avgDetailLatencyMs ? _self.avgDetailLatencyMs : avgDetailLatencyMs // ignore: cast_nullable_to_non_nullable
as int?,lastSuccessAt: freezed == lastSuccessAt ? _self.lastSuccessAt : lastSuccessAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureAt: freezed == lastFailureAt ? _self.lastFailureAt : lastFailureAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureReason: freezed == lastFailureReason ? _self.lastFailureReason : lastFailureReason // ignore: cast_nullable_to_non_nullable
as String?,lastFailureKind: freezed == lastFailureKind ? _self.lastFailureKind : lastFailureKind // ignore: cast_nullable_to_non_nullable
as SourceHealthFailureKind?,lastAutoDisableAt: freezed == lastAutoDisableAt ? _self.lastAutoDisableAt : lastAutoDisableAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAutoDisableReason: freezed == lastAutoDisableReason ? _self.lastAutoDisableReason : lastAutoDisableReason // ignore: cast_nullable_to_non_nullable
as String?,userDisabled: null == userDisabled ? _self.userDisabled : userDisabled // ignore: cast_nullable_to_non_nullable
as bool,userScoreAdjustment: null == userScoreAdjustment ? _self.userScoreAdjustment : userScoreAdjustment // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceHealthSnapshot].
extension SourceHealthSnapshotPatterns on SourceHealthSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceHealthSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceHealthSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceHealthSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _SourceHealthSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceHealthSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _SourceHealthSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _trimmedSourceId)  String sourceId, @JsonKey(fromJson: _sourceHealthLevelFromJson)  SourceHealthLevel level, @JsonKey(fromJson: _enabledFromJson)  bool enabled, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? cooldownUntil, @JsonKey(fromJson: _asInt)  int totalSuccesses, @JsonKey(fromJson: _asInt)  int totalFailures, @JsonKey(fromJson: _asInt)  int consecutiveFailures, @JsonKey(fromJson: _asInt)  int browserRiskCount, @JsonKey(fromJson: _asInt)  int challengeCount, @JsonKey(fromJson: _asInt)  int timeoutCount, @JsonKey(fromJson: _asNullableInt)  int? avgSearchLatencyMs, @JsonKey(fromJson: _asNullableInt)  int? avgDetailLatencyMs, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastSuccessAt, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastFailureAt, @JsonKey(fromJson: _asNullableString)  String? lastFailureReason, @JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson)  SourceHealthFailureKind? lastFailureKind, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastAutoDisableAt, @JsonKey(fromJson: _asNullableString)  String? lastAutoDisableReason, @JsonKey(fromJson: _boolFromJson)  bool userDisabled, @JsonKey(fromJson: _asInt)  int userScoreAdjustment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceHealthSnapshot() when $default != null:
return $default(_that.sourceId,_that.level,_that.enabled,_that.cooldownUntil,_that.totalSuccesses,_that.totalFailures,_that.consecutiveFailures,_that.browserRiskCount,_that.challengeCount,_that.timeoutCount,_that.avgSearchLatencyMs,_that.avgDetailLatencyMs,_that.lastSuccessAt,_that.lastFailureAt,_that.lastFailureReason,_that.lastFailureKind,_that.lastAutoDisableAt,_that.lastAutoDisableReason,_that.userDisabled,_that.userScoreAdjustment);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _trimmedSourceId)  String sourceId, @JsonKey(fromJson: _sourceHealthLevelFromJson)  SourceHealthLevel level, @JsonKey(fromJson: _enabledFromJson)  bool enabled, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? cooldownUntil, @JsonKey(fromJson: _asInt)  int totalSuccesses, @JsonKey(fromJson: _asInt)  int totalFailures, @JsonKey(fromJson: _asInt)  int consecutiveFailures, @JsonKey(fromJson: _asInt)  int browserRiskCount, @JsonKey(fromJson: _asInt)  int challengeCount, @JsonKey(fromJson: _asInt)  int timeoutCount, @JsonKey(fromJson: _asNullableInt)  int? avgSearchLatencyMs, @JsonKey(fromJson: _asNullableInt)  int? avgDetailLatencyMs, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastSuccessAt, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastFailureAt, @JsonKey(fromJson: _asNullableString)  String? lastFailureReason, @JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson)  SourceHealthFailureKind? lastFailureKind, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastAutoDisableAt, @JsonKey(fromJson: _asNullableString)  String? lastAutoDisableReason, @JsonKey(fromJson: _boolFromJson)  bool userDisabled, @JsonKey(fromJson: _asInt)  int userScoreAdjustment)  $default,) {final _that = this;
switch (_that) {
case _SourceHealthSnapshot():
return $default(_that.sourceId,_that.level,_that.enabled,_that.cooldownUntil,_that.totalSuccesses,_that.totalFailures,_that.consecutiveFailures,_that.browserRiskCount,_that.challengeCount,_that.timeoutCount,_that.avgSearchLatencyMs,_that.avgDetailLatencyMs,_that.lastSuccessAt,_that.lastFailureAt,_that.lastFailureReason,_that.lastFailureKind,_that.lastAutoDisableAt,_that.lastAutoDisableReason,_that.userDisabled,_that.userScoreAdjustment);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _trimmedSourceId)  String sourceId, @JsonKey(fromJson: _sourceHealthLevelFromJson)  SourceHealthLevel level, @JsonKey(fromJson: _enabledFromJson)  bool enabled, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? cooldownUntil, @JsonKey(fromJson: _asInt)  int totalSuccesses, @JsonKey(fromJson: _asInt)  int totalFailures, @JsonKey(fromJson: _asInt)  int consecutiveFailures, @JsonKey(fromJson: _asInt)  int browserRiskCount, @JsonKey(fromJson: _asInt)  int challengeCount, @JsonKey(fromJson: _asInt)  int timeoutCount, @JsonKey(fromJson: _asNullableInt)  int? avgSearchLatencyMs, @JsonKey(fromJson: _asNullableInt)  int? avgDetailLatencyMs, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastSuccessAt, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastFailureAt, @JsonKey(fromJson: _asNullableString)  String? lastFailureReason, @JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson)  SourceHealthFailureKind? lastFailureKind, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson)  DateTime? lastAutoDisableAt, @JsonKey(fromJson: _asNullableString)  String? lastAutoDisableReason, @JsonKey(fromJson: _boolFromJson)  bool userDisabled, @JsonKey(fromJson: _asInt)  int userScoreAdjustment)?  $default,) {final _that = this;
switch (_that) {
case _SourceHealthSnapshot() when $default != null:
return $default(_that.sourceId,_that.level,_that.enabled,_that.cooldownUntil,_that.totalSuccesses,_that.totalFailures,_that.consecutiveFailures,_that.browserRiskCount,_that.challengeCount,_that.timeoutCount,_that.avgSearchLatencyMs,_that.avgDetailLatencyMs,_that.lastSuccessAt,_that.lastFailureAt,_that.lastFailureReason,_that.lastFailureKind,_that.lastAutoDisableAt,_that.lastAutoDisableReason,_that.userDisabled,_that.userScoreAdjustment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SourceHealthSnapshot extends SourceHealthSnapshot {
  const _SourceHealthSnapshot({@JsonKey(fromJson: _trimmedSourceId) required this.sourceId, @JsonKey(fromJson: _sourceHealthLevelFromJson) required this.level, @JsonKey(fromJson: _enabledFromJson) required this.enabled, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) this.cooldownUntil, @JsonKey(fromJson: _asInt) this.totalSuccesses = 0, @JsonKey(fromJson: _asInt) this.totalFailures = 0, @JsonKey(fromJson: _asInt) this.consecutiveFailures = 0, @JsonKey(fromJson: _asInt) this.browserRiskCount = 0, @JsonKey(fromJson: _asInt) this.challengeCount = 0, @JsonKey(fromJson: _asInt) this.timeoutCount = 0, @JsonKey(fromJson: _asNullableInt) this.avgSearchLatencyMs, @JsonKey(fromJson: _asNullableInt) this.avgDetailLatencyMs, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) this.lastSuccessAt, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) this.lastFailureAt, @JsonKey(fromJson: _asNullableString) this.lastFailureReason, @JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson) this.lastFailureKind, @JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) this.lastAutoDisableAt, @JsonKey(fromJson: _asNullableString) this.lastAutoDisableReason, @JsonKey(fromJson: _boolFromJson) this.userDisabled = false, @JsonKey(fromJson: _asInt) this.userScoreAdjustment = 0}): super._();
  factory _SourceHealthSnapshot.fromJson(Map<String, dynamic> json) => _$SourceHealthSnapshotFromJson(json);

@override@JsonKey(fromJson: _trimmedSourceId) final  String sourceId;
@override@JsonKey(fromJson: _sourceHealthLevelFromJson) final  SourceHealthLevel level;
@override@JsonKey(fromJson: _enabledFromJson) final  bool enabled;
@override@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) final  DateTime? cooldownUntil;
@override@JsonKey(fromJson: _asInt) final  int totalSuccesses;
@override@JsonKey(fromJson: _asInt) final  int totalFailures;
@override@JsonKey(fromJson: _asInt) final  int consecutiveFailures;
@override@JsonKey(fromJson: _asInt) final  int browserRiskCount;
@override@JsonKey(fromJson: _asInt) final  int challengeCount;
@override@JsonKey(fromJson: _asInt) final  int timeoutCount;
@override@JsonKey(fromJson: _asNullableInt) final  int? avgSearchLatencyMs;
@override@JsonKey(fromJson: _asNullableInt) final  int? avgDetailLatencyMs;
@override@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) final  DateTime? lastSuccessAt;
@override@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) final  DateTime? lastFailureAt;
@override@JsonKey(fromJson: _asNullableString) final  String? lastFailureReason;
@override@JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson) final  SourceHealthFailureKind? lastFailureKind;
@override@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) final  DateTime? lastAutoDisableAt;
@override@JsonKey(fromJson: _asNullableString) final  String? lastAutoDisableReason;
@override@JsonKey(fromJson: _boolFromJson) final  bool userDisabled;
@override@JsonKey(fromJson: _asInt) final  int userScoreAdjustment;

/// Create a copy of SourceHealthSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceHealthSnapshotCopyWith<_SourceHealthSnapshot> get copyWith => __$SourceHealthSnapshotCopyWithImpl<_SourceHealthSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SourceHealthSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceHealthSnapshot&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.level, level) || other.level == level)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.cooldownUntil, cooldownUntil) || other.cooldownUntil == cooldownUntil)&&(identical(other.totalSuccesses, totalSuccesses) || other.totalSuccesses == totalSuccesses)&&(identical(other.totalFailures, totalFailures) || other.totalFailures == totalFailures)&&(identical(other.consecutiveFailures, consecutiveFailures) || other.consecutiveFailures == consecutiveFailures)&&(identical(other.browserRiskCount, browserRiskCount) || other.browserRiskCount == browserRiskCount)&&(identical(other.challengeCount, challengeCount) || other.challengeCount == challengeCount)&&(identical(other.timeoutCount, timeoutCount) || other.timeoutCount == timeoutCount)&&(identical(other.avgSearchLatencyMs, avgSearchLatencyMs) || other.avgSearchLatencyMs == avgSearchLatencyMs)&&(identical(other.avgDetailLatencyMs, avgDetailLatencyMs) || other.avgDetailLatencyMs == avgDetailLatencyMs)&&(identical(other.lastSuccessAt, lastSuccessAt) || other.lastSuccessAt == lastSuccessAt)&&(identical(other.lastFailureAt, lastFailureAt) || other.lastFailureAt == lastFailureAt)&&(identical(other.lastFailureReason, lastFailureReason) || other.lastFailureReason == lastFailureReason)&&(identical(other.lastFailureKind, lastFailureKind) || other.lastFailureKind == lastFailureKind)&&(identical(other.lastAutoDisableAt, lastAutoDisableAt) || other.lastAutoDisableAt == lastAutoDisableAt)&&(identical(other.lastAutoDisableReason, lastAutoDisableReason) || other.lastAutoDisableReason == lastAutoDisableReason)&&(identical(other.userDisabled, userDisabled) || other.userDisabled == userDisabled)&&(identical(other.userScoreAdjustment, userScoreAdjustment) || other.userScoreAdjustment == userScoreAdjustment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,sourceId,level,enabled,cooldownUntil,totalSuccesses,totalFailures,consecutiveFailures,browserRiskCount,challengeCount,timeoutCount,avgSearchLatencyMs,avgDetailLatencyMs,lastSuccessAt,lastFailureAt,lastFailureReason,lastFailureKind,lastAutoDisableAt,lastAutoDisableReason,userDisabled,userScoreAdjustment]);

@override
String toString() {
  return 'SourceHealthSnapshot(sourceId: $sourceId, level: $level, enabled: $enabled, cooldownUntil: $cooldownUntil, totalSuccesses: $totalSuccesses, totalFailures: $totalFailures, consecutiveFailures: $consecutiveFailures, browserRiskCount: $browserRiskCount, challengeCount: $challengeCount, timeoutCount: $timeoutCount, avgSearchLatencyMs: $avgSearchLatencyMs, avgDetailLatencyMs: $avgDetailLatencyMs, lastSuccessAt: $lastSuccessAt, lastFailureAt: $lastFailureAt, lastFailureReason: $lastFailureReason, lastFailureKind: $lastFailureKind, lastAutoDisableAt: $lastAutoDisableAt, lastAutoDisableReason: $lastAutoDisableReason, userDisabled: $userDisabled, userScoreAdjustment: $userScoreAdjustment)';
}


}

/// @nodoc
abstract mixin class _$SourceHealthSnapshotCopyWith<$Res> implements $SourceHealthSnapshotCopyWith<$Res> {
  factory _$SourceHealthSnapshotCopyWith(_SourceHealthSnapshot value, $Res Function(_SourceHealthSnapshot) _then) = __$SourceHealthSnapshotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _trimmedSourceId) String sourceId,@JsonKey(fromJson: _sourceHealthLevelFromJson) SourceHealthLevel level,@JsonKey(fromJson: _enabledFromJson) bool enabled,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? cooldownUntil,@JsonKey(fromJson: _asInt) int totalSuccesses,@JsonKey(fromJson: _asInt) int totalFailures,@JsonKey(fromJson: _asInt) int consecutiveFailures,@JsonKey(fromJson: _asInt) int browserRiskCount,@JsonKey(fromJson: _asInt) int challengeCount,@JsonKey(fromJson: _asInt) int timeoutCount,@JsonKey(fromJson: _asNullableInt) int? avgSearchLatencyMs,@JsonKey(fromJson: _asNullableInt) int? avgDetailLatencyMs,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastSuccessAt,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastFailureAt,@JsonKey(fromJson: _asNullableString) String? lastFailureReason,@JsonKey(fromJson: _parseFailureKind, toJson: _failureKindToJson) SourceHealthFailureKind? lastFailureKind,@JsonKey(fromJson: _parseDateTime, toJson: _dateTimeToJson) DateTime? lastAutoDisableAt,@JsonKey(fromJson: _asNullableString) String? lastAutoDisableReason,@JsonKey(fromJson: _boolFromJson) bool userDisabled,@JsonKey(fromJson: _asInt) int userScoreAdjustment
});




}
/// @nodoc
class __$SourceHealthSnapshotCopyWithImpl<$Res>
    implements _$SourceHealthSnapshotCopyWith<$Res> {
  __$SourceHealthSnapshotCopyWithImpl(this._self, this._then);

  final _SourceHealthSnapshot _self;
  final $Res Function(_SourceHealthSnapshot) _then;

/// Create a copy of SourceHealthSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? level = null,Object? enabled = null,Object? cooldownUntil = freezed,Object? totalSuccesses = null,Object? totalFailures = null,Object? consecutiveFailures = null,Object? browserRiskCount = null,Object? challengeCount = null,Object? timeoutCount = null,Object? avgSearchLatencyMs = freezed,Object? avgDetailLatencyMs = freezed,Object? lastSuccessAt = freezed,Object? lastFailureAt = freezed,Object? lastFailureReason = freezed,Object? lastFailureKind = freezed,Object? lastAutoDisableAt = freezed,Object? lastAutoDisableReason = freezed,Object? userDisabled = null,Object? userScoreAdjustment = null,}) {
  return _then(_SourceHealthSnapshot(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,level: null == level ? _self.level : level // ignore: cast_nullable_to_non_nullable
as SourceHealthLevel,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,cooldownUntil: freezed == cooldownUntil ? _self.cooldownUntil : cooldownUntil // ignore: cast_nullable_to_non_nullable
as DateTime?,totalSuccesses: null == totalSuccesses ? _self.totalSuccesses : totalSuccesses // ignore: cast_nullable_to_non_nullable
as int,totalFailures: null == totalFailures ? _self.totalFailures : totalFailures // ignore: cast_nullable_to_non_nullable
as int,consecutiveFailures: null == consecutiveFailures ? _self.consecutiveFailures : consecutiveFailures // ignore: cast_nullable_to_non_nullable
as int,browserRiskCount: null == browserRiskCount ? _self.browserRiskCount : browserRiskCount // ignore: cast_nullable_to_non_nullable
as int,challengeCount: null == challengeCount ? _self.challengeCount : challengeCount // ignore: cast_nullable_to_non_nullable
as int,timeoutCount: null == timeoutCount ? _self.timeoutCount : timeoutCount // ignore: cast_nullable_to_non_nullable
as int,avgSearchLatencyMs: freezed == avgSearchLatencyMs ? _self.avgSearchLatencyMs : avgSearchLatencyMs // ignore: cast_nullable_to_non_nullable
as int?,avgDetailLatencyMs: freezed == avgDetailLatencyMs ? _self.avgDetailLatencyMs : avgDetailLatencyMs // ignore: cast_nullable_to_non_nullable
as int?,lastSuccessAt: freezed == lastSuccessAt ? _self.lastSuccessAt : lastSuccessAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureAt: freezed == lastFailureAt ? _self.lastFailureAt : lastFailureAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastFailureReason: freezed == lastFailureReason ? _self.lastFailureReason : lastFailureReason // ignore: cast_nullable_to_non_nullable
as String?,lastFailureKind: freezed == lastFailureKind ? _self.lastFailureKind : lastFailureKind // ignore: cast_nullable_to_non_nullable
as SourceHealthFailureKind?,lastAutoDisableAt: freezed == lastAutoDisableAt ? _self.lastAutoDisableAt : lastAutoDisableAt // ignore: cast_nullable_to_non_nullable
as DateTime?,lastAutoDisableReason: freezed == lastAutoDisableReason ? _self.lastAutoDisableReason : lastAutoDisableReason // ignore: cast_nullable_to_non_nullable
as String?,userDisabled: null == userDisabled ? _self.userDisabled : userDisabled // ignore: cast_nullable_to_non_nullable
as bool,userScoreAdjustment: null == userScoreAdjustment ? _self.userScoreAdjustment : userScoreAdjustment // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
