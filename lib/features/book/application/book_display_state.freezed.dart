// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_display_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookDisplayState {

 String get displayTitle; String? get displayAuthor; String? get displayIntro; String? get displayCover; String? get realCoverUrl; String? get customCoverPath; BookDisplayCoverSource get displayCoverSource; bool get overrideUsed; bool get localMetadataUsed;
/// Create a copy of BookDisplayState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDisplayStateCopyWith<BookDisplayState> get copyWith => _$BookDisplayStateCopyWithImpl<BookDisplayState>(this as BookDisplayState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDisplayState&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle)&&(identical(other.displayAuthor, displayAuthor) || other.displayAuthor == displayAuthor)&&(identical(other.displayIntro, displayIntro) || other.displayIntro == displayIntro)&&(identical(other.displayCover, displayCover) || other.displayCover == displayCover)&&(identical(other.realCoverUrl, realCoverUrl) || other.realCoverUrl == realCoverUrl)&&(identical(other.customCoverPath, customCoverPath) || other.customCoverPath == customCoverPath)&&(identical(other.displayCoverSource, displayCoverSource) || other.displayCoverSource == displayCoverSource)&&(identical(other.overrideUsed, overrideUsed) || other.overrideUsed == overrideUsed)&&(identical(other.localMetadataUsed, localMetadataUsed) || other.localMetadataUsed == localMetadataUsed));
}


@override
int get hashCode => Object.hash(runtimeType,displayTitle,displayAuthor,displayIntro,displayCover,realCoverUrl,customCoverPath,displayCoverSource,overrideUsed,localMetadataUsed);

@override
String toString() {
  return 'BookDisplayState(displayTitle: $displayTitle, displayAuthor: $displayAuthor, displayIntro: $displayIntro, displayCover: $displayCover, realCoverUrl: $realCoverUrl, customCoverPath: $customCoverPath, displayCoverSource: $displayCoverSource, overrideUsed: $overrideUsed, localMetadataUsed: $localMetadataUsed)';
}


}

/// @nodoc
abstract mixin class $BookDisplayStateCopyWith<$Res>  {
  factory $BookDisplayStateCopyWith(BookDisplayState value, $Res Function(BookDisplayState) _then) = _$BookDisplayStateCopyWithImpl;
@useResult
$Res call({
 String displayTitle, String? displayAuthor, String? displayIntro, String? displayCover, String? realCoverUrl, String? customCoverPath, BookDisplayCoverSource displayCoverSource, bool overrideUsed, bool localMetadataUsed
});




}
/// @nodoc
class _$BookDisplayStateCopyWithImpl<$Res>
    implements $BookDisplayStateCopyWith<$Res> {
  _$BookDisplayStateCopyWithImpl(this._self, this._then);

  final BookDisplayState _self;
  final $Res Function(BookDisplayState) _then;

/// Create a copy of BookDisplayState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? displayTitle = null,Object? displayAuthor = freezed,Object? displayIntro = freezed,Object? displayCover = freezed,Object? realCoverUrl = freezed,Object? customCoverPath = freezed,Object? displayCoverSource = null,Object? overrideUsed = null,Object? localMetadataUsed = null,}) {
  return _then(_self.copyWith(
displayTitle: null == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String,displayAuthor: freezed == displayAuthor ? _self.displayAuthor : displayAuthor // ignore: cast_nullable_to_non_nullable
as String?,displayIntro: freezed == displayIntro ? _self.displayIntro : displayIntro // ignore: cast_nullable_to_non_nullable
as String?,displayCover: freezed == displayCover ? _self.displayCover : displayCover // ignore: cast_nullable_to_non_nullable
as String?,realCoverUrl: freezed == realCoverUrl ? _self.realCoverUrl : realCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,customCoverPath: freezed == customCoverPath ? _self.customCoverPath : customCoverPath // ignore: cast_nullable_to_non_nullable
as String?,displayCoverSource: null == displayCoverSource ? _self.displayCoverSource : displayCoverSource // ignore: cast_nullable_to_non_nullable
as BookDisplayCoverSource,overrideUsed: null == overrideUsed ? _self.overrideUsed : overrideUsed // ignore: cast_nullable_to_non_nullable
as bool,localMetadataUsed: null == localMetadataUsed ? _self.localMetadataUsed : localMetadataUsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [BookDisplayState].
extension BookDisplayStatePatterns on BookDisplayState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookDisplayState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookDisplayState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookDisplayState value)  $default,){
final _that = this;
switch (_that) {
case _BookDisplayState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookDisplayState value)?  $default,){
final _that = this;
switch (_that) {
case _BookDisplayState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String displayTitle,  String? displayAuthor,  String? displayIntro,  String? displayCover,  String? realCoverUrl,  String? customCoverPath,  BookDisplayCoverSource displayCoverSource,  bool overrideUsed,  bool localMetadataUsed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookDisplayState() when $default != null:
return $default(_that.displayTitle,_that.displayAuthor,_that.displayIntro,_that.displayCover,_that.realCoverUrl,_that.customCoverPath,_that.displayCoverSource,_that.overrideUsed,_that.localMetadataUsed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String displayTitle,  String? displayAuthor,  String? displayIntro,  String? displayCover,  String? realCoverUrl,  String? customCoverPath,  BookDisplayCoverSource displayCoverSource,  bool overrideUsed,  bool localMetadataUsed)  $default,) {final _that = this;
switch (_that) {
case _BookDisplayState():
return $default(_that.displayTitle,_that.displayAuthor,_that.displayIntro,_that.displayCover,_that.realCoverUrl,_that.customCoverPath,_that.displayCoverSource,_that.overrideUsed,_that.localMetadataUsed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String displayTitle,  String? displayAuthor,  String? displayIntro,  String? displayCover,  String? realCoverUrl,  String? customCoverPath,  BookDisplayCoverSource displayCoverSource,  bool overrideUsed,  bool localMetadataUsed)?  $default,) {final _that = this;
switch (_that) {
case _BookDisplayState() when $default != null:
return $default(_that.displayTitle,_that.displayAuthor,_that.displayIntro,_that.displayCover,_that.realCoverUrl,_that.customCoverPath,_that.displayCoverSource,_that.overrideUsed,_that.localMetadataUsed);case _:
  return null;

}
}

}

/// @nodoc


class _BookDisplayState implements BookDisplayState {
  const _BookDisplayState({required this.displayTitle, this.displayAuthor, this.displayIntro, this.displayCover, this.realCoverUrl, this.customCoverPath, this.displayCoverSource = BookDisplayCoverSource.none, this.overrideUsed = false, this.localMetadataUsed = false});
  

@override final  String displayTitle;
@override final  String? displayAuthor;
@override final  String? displayIntro;
@override final  String? displayCover;
@override final  String? realCoverUrl;
@override final  String? customCoverPath;
@override@JsonKey() final  BookDisplayCoverSource displayCoverSource;
@override@JsonKey() final  bool overrideUsed;
@override@JsonKey() final  bool localMetadataUsed;

/// Create a copy of BookDisplayState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookDisplayStateCopyWith<_BookDisplayState> get copyWith => __$BookDisplayStateCopyWithImpl<_BookDisplayState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookDisplayState&&(identical(other.displayTitle, displayTitle) || other.displayTitle == displayTitle)&&(identical(other.displayAuthor, displayAuthor) || other.displayAuthor == displayAuthor)&&(identical(other.displayIntro, displayIntro) || other.displayIntro == displayIntro)&&(identical(other.displayCover, displayCover) || other.displayCover == displayCover)&&(identical(other.realCoverUrl, realCoverUrl) || other.realCoverUrl == realCoverUrl)&&(identical(other.customCoverPath, customCoverPath) || other.customCoverPath == customCoverPath)&&(identical(other.displayCoverSource, displayCoverSource) || other.displayCoverSource == displayCoverSource)&&(identical(other.overrideUsed, overrideUsed) || other.overrideUsed == overrideUsed)&&(identical(other.localMetadataUsed, localMetadataUsed) || other.localMetadataUsed == localMetadataUsed));
}


@override
int get hashCode => Object.hash(runtimeType,displayTitle,displayAuthor,displayIntro,displayCover,realCoverUrl,customCoverPath,displayCoverSource,overrideUsed,localMetadataUsed);

@override
String toString() {
  return 'BookDisplayState(displayTitle: $displayTitle, displayAuthor: $displayAuthor, displayIntro: $displayIntro, displayCover: $displayCover, realCoverUrl: $realCoverUrl, customCoverPath: $customCoverPath, displayCoverSource: $displayCoverSource, overrideUsed: $overrideUsed, localMetadataUsed: $localMetadataUsed)';
}


}

/// @nodoc
abstract mixin class _$BookDisplayStateCopyWith<$Res> implements $BookDisplayStateCopyWith<$Res> {
  factory _$BookDisplayStateCopyWith(_BookDisplayState value, $Res Function(_BookDisplayState) _then) = __$BookDisplayStateCopyWithImpl;
@override @useResult
$Res call({
 String displayTitle, String? displayAuthor, String? displayIntro, String? displayCover, String? realCoverUrl, String? customCoverPath, BookDisplayCoverSource displayCoverSource, bool overrideUsed, bool localMetadataUsed
});




}
/// @nodoc
class __$BookDisplayStateCopyWithImpl<$Res>
    implements _$BookDisplayStateCopyWith<$Res> {
  __$BookDisplayStateCopyWithImpl(this._self, this._then);

  final _BookDisplayState _self;
  final $Res Function(_BookDisplayState) _then;

/// Create a copy of BookDisplayState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? displayTitle = null,Object? displayAuthor = freezed,Object? displayIntro = freezed,Object? displayCover = freezed,Object? realCoverUrl = freezed,Object? customCoverPath = freezed,Object? displayCoverSource = null,Object? overrideUsed = null,Object? localMetadataUsed = null,}) {
  return _then(_BookDisplayState(
displayTitle: null == displayTitle ? _self.displayTitle : displayTitle // ignore: cast_nullable_to_non_nullable
as String,displayAuthor: freezed == displayAuthor ? _self.displayAuthor : displayAuthor // ignore: cast_nullable_to_non_nullable
as String?,displayIntro: freezed == displayIntro ? _self.displayIntro : displayIntro // ignore: cast_nullable_to_non_nullable
as String?,displayCover: freezed == displayCover ? _self.displayCover : displayCover // ignore: cast_nullable_to_non_nullable
as String?,realCoverUrl: freezed == realCoverUrl ? _self.realCoverUrl : realCoverUrl // ignore: cast_nullable_to_non_nullable
as String?,customCoverPath: freezed == customCoverPath ? _self.customCoverPath : customCoverPath // ignore: cast_nullable_to_non_nullable
as String?,displayCoverSource: null == displayCoverSource ? _self.displayCoverSource : displayCoverSource // ignore: cast_nullable_to_non_nullable
as BookDisplayCoverSource,overrideUsed: null == overrideUsed ? _self.overrideUsed : overrideUsed // ignore: cast_nullable_to_non_nullable
as bool,localMetadataUsed: null == localMetadataUsed ? _self.localMetadataUsed : localMetadataUsed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
