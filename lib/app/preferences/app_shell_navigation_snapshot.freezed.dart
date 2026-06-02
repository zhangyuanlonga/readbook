// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_shell_navigation_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppShellNavigationSnapshot {

 bool get showHome; bool get showBookshelf; bool get showDiscover; bool get showStats;
/// Create a copy of AppShellNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppShellNavigationSnapshotCopyWith<AppShellNavigationSnapshot> get copyWith => _$AppShellNavigationSnapshotCopyWithImpl<AppShellNavigationSnapshot>(this as AppShellNavigationSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppShellNavigationSnapshot&&(identical(other.showHome, showHome) || other.showHome == showHome)&&(identical(other.showBookshelf, showBookshelf) || other.showBookshelf == showBookshelf)&&(identical(other.showDiscover, showDiscover) || other.showDiscover == showDiscover)&&(identical(other.showStats, showStats) || other.showStats == showStats));
}


@override
int get hashCode => Object.hash(runtimeType,showHome,showBookshelf,showDiscover,showStats);

@override
String toString() {
  return 'AppShellNavigationSnapshot(showHome: $showHome, showBookshelf: $showBookshelf, showDiscover: $showDiscover, showStats: $showStats)';
}


}

/// @nodoc
abstract mixin class $AppShellNavigationSnapshotCopyWith<$Res>  {
  factory $AppShellNavigationSnapshotCopyWith(AppShellNavigationSnapshot value, $Res Function(AppShellNavigationSnapshot) _then) = _$AppShellNavigationSnapshotCopyWithImpl;
@useResult
$Res call({
 bool showHome, bool showBookshelf, bool showDiscover, bool showStats
});




}
/// @nodoc
class _$AppShellNavigationSnapshotCopyWithImpl<$Res>
    implements $AppShellNavigationSnapshotCopyWith<$Res> {
  _$AppShellNavigationSnapshotCopyWithImpl(this._self, this._then);

  final AppShellNavigationSnapshot _self;
  final $Res Function(AppShellNavigationSnapshot) _then;

/// Create a copy of AppShellNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? showHome = null,Object? showBookshelf = null,Object? showDiscover = null,Object? showStats = null,}) {
  return _then(_self.copyWith(
showHome: null == showHome ? _self.showHome : showHome // ignore: cast_nullable_to_non_nullable
as bool,showBookshelf: null == showBookshelf ? _self.showBookshelf : showBookshelf // ignore: cast_nullable_to_non_nullable
as bool,showDiscover: null == showDiscover ? _self.showDiscover : showDiscover // ignore: cast_nullable_to_non_nullable
as bool,showStats: null == showStats ? _self.showStats : showStats // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppShellNavigationSnapshot].
extension AppShellNavigationSnapshotPatterns on AppShellNavigationSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppShellNavigationSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppShellNavigationSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppShellNavigationSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool showHome,  bool showBookshelf,  bool showDiscover,  bool showStats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot() when $default != null:
return $default(_that.showHome,_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool showHome,  bool showBookshelf,  bool showDiscover,  bool showStats)  $default,) {final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot():
return $default(_that.showHome,_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool showHome,  bool showBookshelf,  bool showDiscover,  bool showStats)?  $default,) {final _that = this;
switch (_that) {
case _AppShellNavigationSnapshot() when $default != null:
return $default(_that.showHome,_that.showBookshelf,_that.showDiscover,_that.showStats);case _:
  return null;

}
}

}

/// @nodoc


class _AppShellNavigationSnapshot implements AppShellNavigationSnapshot {
  const _AppShellNavigationSnapshot({required this.showHome, required this.showBookshelf, required this.showDiscover, required this.showStats});
  

@override final  bool showHome;
@override final  bool showBookshelf;
@override final  bool showDiscover;
@override final  bool showStats;

/// Create a copy of AppShellNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppShellNavigationSnapshotCopyWith<_AppShellNavigationSnapshot> get copyWith => __$AppShellNavigationSnapshotCopyWithImpl<_AppShellNavigationSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppShellNavigationSnapshot&&(identical(other.showHome, showHome) || other.showHome == showHome)&&(identical(other.showBookshelf, showBookshelf) || other.showBookshelf == showBookshelf)&&(identical(other.showDiscover, showDiscover) || other.showDiscover == showDiscover)&&(identical(other.showStats, showStats) || other.showStats == showStats));
}


@override
int get hashCode => Object.hash(runtimeType,showHome,showBookshelf,showDiscover,showStats);

@override
String toString() {
  return 'AppShellNavigationSnapshot(showHome: $showHome, showBookshelf: $showBookshelf, showDiscover: $showDiscover, showStats: $showStats)';
}


}

/// @nodoc
abstract mixin class _$AppShellNavigationSnapshotCopyWith<$Res> implements $AppShellNavigationSnapshotCopyWith<$Res> {
  factory _$AppShellNavigationSnapshotCopyWith(_AppShellNavigationSnapshot value, $Res Function(_AppShellNavigationSnapshot) _then) = __$AppShellNavigationSnapshotCopyWithImpl;
@override @useResult
$Res call({
 bool showHome, bool showBookshelf, bool showDiscover, bool showStats
});




}
/// @nodoc
class __$AppShellNavigationSnapshotCopyWithImpl<$Res>
    implements _$AppShellNavigationSnapshotCopyWith<$Res> {
  __$AppShellNavigationSnapshotCopyWithImpl(this._self, this._then);

  final _AppShellNavigationSnapshot _self;
  final $Res Function(_AppShellNavigationSnapshot) _then;

/// Create a copy of AppShellNavigationSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? showHome = null,Object? showBookshelf = null,Object? showDiscover = null,Object? showStats = null,}) {
  return _then(_AppShellNavigationSnapshot(
showHome: null == showHome ? _self.showHome : showHome // ignore: cast_nullable_to_non_nullable
as bool,showBookshelf: null == showBookshelf ? _self.showBookshelf : showBookshelf // ignore: cast_nullable_to_non_nullable
as bool,showDiscover: null == showDiscover ? _self.showDiscover : showDiscover // ignore: cast_nullable_to_non_nullable
as bool,showStats: null == showStats ? _self.showStats : showStats // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
