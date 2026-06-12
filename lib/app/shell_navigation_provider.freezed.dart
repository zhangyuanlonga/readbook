// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shell_navigation_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppShellNavigationState {

 bool get showBookshelf; bool get showDiscover; bool get showStats;
/// Create a copy of AppShellNavigationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppShellNavigationStateCopyWith<AppShellNavigationState> get copyWith => _$AppShellNavigationStateCopyWithImpl<AppShellNavigationState>(this as AppShellNavigationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppShellNavigationState&&(identical(other.showBookshelf, showBookshelf) || other.showBookshelf == showBookshelf)&&(identical(other.showDiscover, showDiscover) || other.showDiscover == showDiscover)&&(identical(other.showStats, showStats) || other.showStats == showStats));
}


@override
int get hashCode => Object.hash(runtimeType,showBookshelf,showDiscover,showStats);

@override
String toString() {
  return 'AppShellNavigationState(showBookshelf: $showBookshelf, showDiscover: $showDiscover, showStats: $showStats)';
}


}

/// @nodoc
abstract mixin class $AppShellNavigationStateCopyWith<$Res>  {
  factory $AppShellNavigationStateCopyWith(AppShellNavigationState value, $Res Function(AppShellNavigationState) _then) = _$AppShellNavigationStateCopyWithImpl;
@useResult
$Res call({
 bool showBookshelf, bool showDiscover, bool showStats
});




}
/// @nodoc
class _$AppShellNavigationStateCopyWithImpl<$Res>
    implements $AppShellNavigationStateCopyWith<$Res> {
  _$AppShellNavigationStateCopyWithImpl(this._self, this._then);

  final AppShellNavigationState _self;
  final $Res Function(AppShellNavigationState) _then;

/// Create a copy of AppShellNavigationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showBookshelf = null,Object? showDiscover = null,Object? showStats = null,}) {
  return _then(_self.copyWith(
showBookshelf: null == showBookshelf ? _self.showBookshelf : showBookshelf // ignore: cast_nullable_to_non_nullable
as bool,showDiscover: null == showDiscover ? _self.showDiscover : showDiscover // ignore: cast_nullable_to_non_nullable
as bool,showStats: null == showStats ? _self.showStats : showStats // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppShellNavigationState].
extension AppShellNavigationStatePatterns on AppShellNavigationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppShellNavigationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppShellNavigationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppShellNavigationState value)  $default,){
final _that = this;
switch (_that) {
case _AppShellNavigationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppShellNavigationState value)?  $default,){
final _that = this;
switch (_that) {
case _AppShellNavigationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool showBookshelf,  bool showDiscover,  bool showStats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppShellNavigationState() when $default != null:
return $default(_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool showBookshelf,  bool showDiscover,  bool showStats)  $default,) {final _that = this;
switch (_that) {
case _AppShellNavigationState():
return $default(_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool showBookshelf,  bool showDiscover,  bool showStats)?  $default,) {final _that = this;
switch (_that) {
case _AppShellNavigationState() when $default != null:
return $default(_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
  return null;

}
}

}

/// @nodoc


class _AppShellNavigationState extends AppShellNavigationState {
  const _AppShellNavigationState({this.showBookshelf = true, this.showDiscover = false, this.showStats = false}): super._();
  

@override@JsonKey() final  bool showBookshelf;
@override@JsonKey() final  bool showDiscover;
@override@JsonKey() final  bool showStats;

/// Create a copy of AppShellNavigationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppShellNavigationStateCopyWith<_AppShellNavigationState> get copyWith => __$AppShellNavigationStateCopyWithImpl<_AppShellNavigationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppShellNavigationState&&(identical(other.showBookshelf, showBookshelf) || other.showBookshelf == showBookshelf)&&(identical(other.showDiscover, showDiscover) || other.showDiscover == showDiscover)&&(identical(other.showStats, showStats) || other.showStats == showStats));
}


@override
int get hashCode => Object.hash(runtimeType,showBookshelf,showDiscover,showStats);

@override
String toString() {
  return 'AppShellNavigationState(showBookshelf: $showBookshelf, showDiscover: $showDiscover, showStats: $showStats)';
}


}

/// @nodoc
abstract mixin class _$AppShellNavigationStateCopyWith<$Res> implements $AppShellNavigationStateCopyWith<$Res> {
  factory _$AppShellNavigationStateCopyWith(_AppShellNavigationState value, $Res Function(_AppShellNavigationState) _then) = __$AppShellNavigationStateCopyWithImpl;
@override @useResult
$Res call({
 bool showBookshelf, bool showDiscover, bool showStats
});




}
/// @nodoc
class __$AppShellNavigationStateCopyWithImpl<$Res>
    implements _$AppShellNavigationStateCopyWith<$Res> {
  __$AppShellNavigationStateCopyWithImpl(this._self, this._then);

  final _AppShellNavigationState _self;
  final $Res Function(_AppShellNavigationState) _then;

/// Create a copy of AppShellNavigationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showBookshelf = null,Object? showDiscover = null,Object? showStats = null,}) {
  return _then(_AppShellNavigationState(
showBookshelf: null == showBookshelf ? _self.showBookshelf : showBookshelf // ignore: cast_nullable_to_non_nullable
as bool,showDiscover: null == showDiscover ? _self.showDiscover : showDiscover // ignore: cast_nullable_to_non_nullable
as bool,showStats: null == showStats ? _self.showStats : showStats // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
