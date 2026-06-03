// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_login_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SourceLoginState {

@JsonKey(fromJson: _requiredSourceIdFromJson) String get sourceId;@JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson) DateTime get updatedAt;@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? get loginHeaderJson;@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? get loginInfoJson;@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? get sourceVariableJson;
/// Create a copy of SourceLoginState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceLoginStateCopyWith<SourceLoginState> get copyWith => _$SourceLoginStateCopyWithImpl<SourceLoginState>(this as SourceLoginState, _$identity);

  /// Serializes this SourceLoginState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceLoginState&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.loginHeaderJson, loginHeaderJson) || other.loginHeaderJson == loginHeaderJson)&&(identical(other.loginInfoJson, loginInfoJson) || other.loginInfoJson == loginInfoJson)&&(identical(other.sourceVariableJson, sourceVariableJson) || other.sourceVariableJson == sourceVariableJson));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceId,updatedAt,loginHeaderJson,loginInfoJson,sourceVariableJson);

@override
String toString() {
  return 'SourceLoginState(sourceId: $sourceId, updatedAt: $updatedAt, loginHeaderJson: $loginHeaderJson, loginInfoJson: $loginInfoJson, sourceVariableJson: $sourceVariableJson)';
}


}

/// @nodoc
abstract mixin class $SourceLoginStateCopyWith<$Res>  {
  factory $SourceLoginStateCopyWith(SourceLoginState value, $Res Function(SourceLoginState) _then) = _$SourceLoginStateCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _requiredSourceIdFromJson) String sourceId,@JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson) DateTime updatedAt,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? loginHeaderJson,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? loginInfoJson,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? sourceVariableJson
});




}
/// @nodoc
class _$SourceLoginStateCopyWithImpl<$Res>
    implements $SourceLoginStateCopyWith<$Res> {
  _$SourceLoginStateCopyWithImpl(this._self, this._then);

  final SourceLoginState _self;
  final $Res Function(SourceLoginState) _then;

/// Create a copy of SourceLoginState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sourceId = null,Object? updatedAt = null,Object? loginHeaderJson = freezed,Object? loginInfoJson = freezed,Object? sourceVariableJson = freezed,}) {
  return _then(_self.copyWith(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,loginHeaderJson: freezed == loginHeaderJson ? _self.loginHeaderJson : loginHeaderJson // ignore: cast_nullable_to_non_nullable
as String?,loginInfoJson: freezed == loginInfoJson ? _self.loginInfoJson : loginInfoJson // ignore: cast_nullable_to_non_nullable
as String?,sourceVariableJson: freezed == sourceVariableJson ? _self.sourceVariableJson : sourceVariableJson // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceLoginState].
extension SourceLoginStatePatterns on SourceLoginState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceLoginState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceLoginState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceLoginState value)  $default,){
final _that = this;
switch (_that) {
case _SourceLoginState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceLoginState value)?  $default,){
final _that = this;
switch (_that) {
case _SourceLoginState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _requiredSourceIdFromJson)  String sourceId, @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson)  DateTime updatedAt, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginHeaderJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginInfoJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? sourceVariableJson)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceLoginState() when $default != null:
return $default(_that.sourceId,_that.updatedAt,_that.loginHeaderJson,_that.loginInfoJson,_that.sourceVariableJson);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _requiredSourceIdFromJson)  String sourceId, @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson)  DateTime updatedAt, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginHeaderJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginInfoJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? sourceVariableJson)  $default,) {final _that = this;
switch (_that) {
case _SourceLoginState():
return $default(_that.sourceId,_that.updatedAt,_that.loginHeaderJson,_that.loginInfoJson,_that.sourceVariableJson);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _requiredSourceIdFromJson)  String sourceId, @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson)  DateTime updatedAt, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginHeaderJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? loginInfoJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson)  String? sourceVariableJson)?  $default,) {final _that = this;
switch (_that) {
case _SourceLoginState() when $default != null:
return $default(_that.sourceId,_that.updatedAt,_that.loginHeaderJson,_that.loginInfoJson,_that.sourceVariableJson);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SourceLoginState extends SourceLoginState {
  const _SourceLoginState({@JsonKey(fromJson: _requiredSourceIdFromJson) required this.sourceId, @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson) required this.updatedAt, @JsonKey(fromJson: _optionalNormalizedStringFromJson) this.loginHeaderJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson) this.loginInfoJson, @JsonKey(fromJson: _optionalNormalizedStringFromJson) this.sourceVariableJson}): super._();
  factory _SourceLoginState.fromJson(Map<String, dynamic> json) => _$SourceLoginStateFromJson(json);

@override@JsonKey(fromJson: _requiredSourceIdFromJson) final  String sourceId;
@override@JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson) final  DateTime updatedAt;
@override@JsonKey(fromJson: _optionalNormalizedStringFromJson) final  String? loginHeaderJson;
@override@JsonKey(fromJson: _optionalNormalizedStringFromJson) final  String? loginInfoJson;
@override@JsonKey(fromJson: _optionalNormalizedStringFromJson) final  String? sourceVariableJson;

/// Create a copy of SourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceLoginStateCopyWith<_SourceLoginState> get copyWith => __$SourceLoginStateCopyWithImpl<_SourceLoginState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SourceLoginStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceLoginState&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.loginHeaderJson, loginHeaderJson) || other.loginHeaderJson == loginHeaderJson)&&(identical(other.loginInfoJson, loginInfoJson) || other.loginInfoJson == loginInfoJson)&&(identical(other.sourceVariableJson, sourceVariableJson) || other.sourceVariableJson == sourceVariableJson));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,sourceId,updatedAt,loginHeaderJson,loginInfoJson,sourceVariableJson);

@override
String toString() {
  return 'SourceLoginState(sourceId: $sourceId, updatedAt: $updatedAt, loginHeaderJson: $loginHeaderJson, loginInfoJson: $loginInfoJson, sourceVariableJson: $sourceVariableJson)';
}


}

/// @nodoc
abstract mixin class _$SourceLoginStateCopyWith<$Res> implements $SourceLoginStateCopyWith<$Res> {
  factory _$SourceLoginStateCopyWith(_SourceLoginState value, $Res Function(_SourceLoginState) _then) = __$SourceLoginStateCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _requiredSourceIdFromJson) String sourceId,@JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson) DateTime updatedAt,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? loginHeaderJson,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? loginInfoJson,@JsonKey(fromJson: _optionalNormalizedStringFromJson) String? sourceVariableJson
});




}
/// @nodoc
class __$SourceLoginStateCopyWithImpl<$Res>
    implements _$SourceLoginStateCopyWith<$Res> {
  __$SourceLoginStateCopyWithImpl(this._self, this._then);

  final _SourceLoginState _self;
  final $Res Function(_SourceLoginState) _then;

/// Create a copy of SourceLoginState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sourceId = null,Object? updatedAt = null,Object? loginHeaderJson = freezed,Object? loginInfoJson = freezed,Object? sourceVariableJson = freezed,}) {
  return _then(_SourceLoginState(
sourceId: null == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,loginHeaderJson: freezed == loginHeaderJson ? _self.loginHeaderJson : loginHeaderJson // ignore: cast_nullable_to_non_nullable
as String?,loginInfoJson: freezed == loginInfoJson ? _self.loginInfoJson : loginInfoJson // ignore: cast_nullable_to_non_nullable
as String?,sourceVariableJson: freezed == sourceVariableJson ? _self.sourceVariableJson : sourceVariableJson // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
