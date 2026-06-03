// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_session_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderSessionGenerationState {

 int get chapterContentGeneration; int get preloadGeneration; int get paginationGeneration;
/// Create a copy of ReaderSessionGenerationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSessionGenerationStateCopyWith<ReaderSessionGenerationState> get copyWith => _$ReaderSessionGenerationStateCopyWithImpl<ReaderSessionGenerationState>(this as ReaderSessionGenerationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSessionGenerationState&&(identical(other.chapterContentGeneration, chapterContentGeneration) || other.chapterContentGeneration == chapterContentGeneration)&&(identical(other.preloadGeneration, preloadGeneration) || other.preloadGeneration == preloadGeneration)&&(identical(other.paginationGeneration, paginationGeneration) || other.paginationGeneration == paginationGeneration));
}


@override
int get hashCode => Object.hash(runtimeType,chapterContentGeneration,preloadGeneration,paginationGeneration);

@override
String toString() {
  return 'ReaderSessionGenerationState(chapterContentGeneration: $chapterContentGeneration, preloadGeneration: $preloadGeneration, paginationGeneration: $paginationGeneration)';
}


}

/// @nodoc
abstract mixin class $ReaderSessionGenerationStateCopyWith<$Res>  {
  factory $ReaderSessionGenerationStateCopyWith(ReaderSessionGenerationState value, $Res Function(ReaderSessionGenerationState) _then) = _$ReaderSessionGenerationStateCopyWithImpl;
@useResult
$Res call({
 int chapterContentGeneration, int preloadGeneration, int paginationGeneration
});




}
/// @nodoc
class _$ReaderSessionGenerationStateCopyWithImpl<$Res>
    implements $ReaderSessionGenerationStateCopyWith<$Res> {
  _$ReaderSessionGenerationStateCopyWithImpl(this._self, this._then);

  final ReaderSessionGenerationState _self;
  final $Res Function(ReaderSessionGenerationState) _then;

/// Create a copy of ReaderSessionGenerationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chapterContentGeneration = null,Object? preloadGeneration = null,Object? paginationGeneration = null,}) {
  return _then(_self.copyWith(
chapterContentGeneration: null == chapterContentGeneration ? _self.chapterContentGeneration : chapterContentGeneration // ignore: cast_nullable_to_non_nullable
as int,preloadGeneration: null == preloadGeneration ? _self.preloadGeneration : preloadGeneration // ignore: cast_nullable_to_non_nullable
as int,paginationGeneration: null == paginationGeneration ? _self.paginationGeneration : paginationGeneration // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSessionGenerationState].
extension ReaderSessionGenerationStatePatterns on ReaderSessionGenerationState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSessionGenerationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSessionGenerationState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSessionGenerationState value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionGenerationState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSessionGenerationState value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionGenerationState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int chapterContentGeneration,  int preloadGeneration,  int paginationGeneration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSessionGenerationState() when $default != null:
return $default(_that.chapterContentGeneration,_that.preloadGeneration,_that.paginationGeneration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int chapterContentGeneration,  int preloadGeneration,  int paginationGeneration)  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionGenerationState():
return $default(_that.chapterContentGeneration,_that.preloadGeneration,_that.paginationGeneration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int chapterContentGeneration,  int preloadGeneration,  int paginationGeneration)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionGenerationState() when $default != null:
return $default(_that.chapterContentGeneration,_that.preloadGeneration,_that.paginationGeneration);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSessionGenerationState implements ReaderSessionGenerationState {
  const _ReaderSessionGenerationState({this.chapterContentGeneration = 0, this.preloadGeneration = 0, this.paginationGeneration = 0});
  

@override@JsonKey() final  int chapterContentGeneration;
@override@JsonKey() final  int preloadGeneration;
@override@JsonKey() final  int paginationGeneration;

/// Create a copy of ReaderSessionGenerationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSessionGenerationStateCopyWith<_ReaderSessionGenerationState> get copyWith => __$ReaderSessionGenerationStateCopyWithImpl<_ReaderSessionGenerationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSessionGenerationState&&(identical(other.chapterContentGeneration, chapterContentGeneration) || other.chapterContentGeneration == chapterContentGeneration)&&(identical(other.preloadGeneration, preloadGeneration) || other.preloadGeneration == preloadGeneration)&&(identical(other.paginationGeneration, paginationGeneration) || other.paginationGeneration == paginationGeneration));
}


@override
int get hashCode => Object.hash(runtimeType,chapterContentGeneration,preloadGeneration,paginationGeneration);

@override
String toString() {
  return 'ReaderSessionGenerationState(chapterContentGeneration: $chapterContentGeneration, preloadGeneration: $preloadGeneration, paginationGeneration: $paginationGeneration)';
}


}

/// @nodoc
abstract mixin class _$ReaderSessionGenerationStateCopyWith<$Res> implements $ReaderSessionGenerationStateCopyWith<$Res> {
  factory _$ReaderSessionGenerationStateCopyWith(_ReaderSessionGenerationState value, $Res Function(_ReaderSessionGenerationState) _then) = __$ReaderSessionGenerationStateCopyWithImpl;
@override @useResult
$Res call({
 int chapterContentGeneration, int preloadGeneration, int paginationGeneration
});




}
/// @nodoc
class __$ReaderSessionGenerationStateCopyWithImpl<$Res>
    implements _$ReaderSessionGenerationStateCopyWith<$Res> {
  __$ReaderSessionGenerationStateCopyWithImpl(this._self, this._then);

  final _ReaderSessionGenerationState _self;
  final $Res Function(_ReaderSessionGenerationState) _then;

/// Create a copy of ReaderSessionGenerationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chapterContentGeneration = null,Object? preloadGeneration = null,Object? paginationGeneration = null,}) {
  return _then(_ReaderSessionGenerationState(
chapterContentGeneration: null == chapterContentGeneration ? _self.chapterContentGeneration : chapterContentGeneration // ignore: cast_nullable_to_non_nullable
as int,preloadGeneration: null == preloadGeneration ? _self.preloadGeneration : preloadGeneration // ignore: cast_nullable_to_non_nullable
as int,paginationGeneration: null == paginationGeneration ? _self.paginationGeneration : paginationGeneration // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ReaderVisiblePosition {

 int? get pageIndex; int? get pageCount; double? get scrollOffset; double? get maxScrollExtent;
/// Create a copy of ReaderVisiblePosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderVisiblePositionCopyWith<ReaderVisiblePosition> get copyWith => _$ReaderVisiblePositionCopyWithImpl<ReaderVisiblePosition>(this as ReaderVisiblePosition, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderVisiblePosition&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset)&&(identical(other.maxScrollExtent, maxScrollExtent) || other.maxScrollExtent == maxScrollExtent));
}


@override
int get hashCode => Object.hash(runtimeType,pageIndex,pageCount,scrollOffset,maxScrollExtent);

@override
String toString() {
  return 'ReaderVisiblePosition(pageIndex: $pageIndex, pageCount: $pageCount, scrollOffset: $scrollOffset, maxScrollExtent: $maxScrollExtent)';
}


}

/// @nodoc
abstract mixin class $ReaderVisiblePositionCopyWith<$Res>  {
  factory $ReaderVisiblePositionCopyWith(ReaderVisiblePosition value, $Res Function(ReaderVisiblePosition) _then) = _$ReaderVisiblePositionCopyWithImpl;
@useResult
$Res call({
 int? pageIndex, int? pageCount, double? scrollOffset, double? maxScrollExtent
});




}
/// @nodoc
class _$ReaderVisiblePositionCopyWithImpl<$Res>
    implements $ReaderVisiblePositionCopyWith<$Res> {
  _$ReaderVisiblePositionCopyWithImpl(this._self, this._then);

  final ReaderVisiblePosition _self;
  final $Res Function(ReaderVisiblePosition) _then;

/// Create a copy of ReaderVisiblePosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pageIndex = freezed,Object? pageCount = freezed,Object? scrollOffset = freezed,Object? maxScrollExtent = freezed,}) {
  return _then(_self.copyWith(
pageIndex: freezed == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int?,pageCount: freezed == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,maxScrollExtent: freezed == maxScrollExtent ? _self.maxScrollExtent : maxScrollExtent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderVisiblePosition].
extension ReaderVisiblePositionPatterns on ReaderVisiblePosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderVisiblePosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderVisiblePosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderVisiblePosition value)  $default,){
final _that = this;
switch (_that) {
case _ReaderVisiblePosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderVisiblePosition value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderVisiblePosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderVisiblePosition() when $default != null:
return $default(_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent)  $default,) {final _that = this;
switch (_that) {
case _ReaderVisiblePosition():
return $default(_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent)?  $default,) {final _that = this;
switch (_that) {
case _ReaderVisiblePosition() when $default != null:
return $default(_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderVisiblePosition implements ReaderVisiblePosition {
  const _ReaderVisiblePosition({this.pageIndex, this.pageCount, this.scrollOffset, this.maxScrollExtent});
  

@override final  int? pageIndex;
@override final  int? pageCount;
@override final  double? scrollOffset;
@override final  double? maxScrollExtent;

/// Create a copy of ReaderVisiblePosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderVisiblePositionCopyWith<_ReaderVisiblePosition> get copyWith => __$ReaderVisiblePositionCopyWithImpl<_ReaderVisiblePosition>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderVisiblePosition&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset)&&(identical(other.maxScrollExtent, maxScrollExtent) || other.maxScrollExtent == maxScrollExtent));
}


@override
int get hashCode => Object.hash(runtimeType,pageIndex,pageCount,scrollOffset,maxScrollExtent);

@override
String toString() {
  return 'ReaderVisiblePosition(pageIndex: $pageIndex, pageCount: $pageCount, scrollOffset: $scrollOffset, maxScrollExtent: $maxScrollExtent)';
}


}

/// @nodoc
abstract mixin class _$ReaderVisiblePositionCopyWith<$Res> implements $ReaderVisiblePositionCopyWith<$Res> {
  factory _$ReaderVisiblePositionCopyWith(_ReaderVisiblePosition value, $Res Function(_ReaderVisiblePosition) _then) = __$ReaderVisiblePositionCopyWithImpl;
@override @useResult
$Res call({
 int? pageIndex, int? pageCount, double? scrollOffset, double? maxScrollExtent
});




}
/// @nodoc
class __$ReaderVisiblePositionCopyWithImpl<$Res>
    implements _$ReaderVisiblePositionCopyWith<$Res> {
  __$ReaderVisiblePositionCopyWithImpl(this._self, this._then);

  final _ReaderVisiblePosition _self;
  final $Res Function(_ReaderVisiblePosition) _then;

/// Create a copy of ReaderVisiblePosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pageIndex = freezed,Object? pageCount = freezed,Object? scrollOffset = freezed,Object? maxScrollExtent = freezed,}) {
  return _then(_ReaderVisiblePosition(
pageIndex: freezed == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int?,pageCount: freezed == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,maxScrollExtent: freezed == maxScrollExtent ? _self.maxScrollExtent : maxScrollExtent // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$ReaderViewportSession {

 String get viewportMode; int? get pageIndex; int? get pageCount; double? get scrollOffset; double? get maxScrollExtent; double? get zoomScale; double? get panDx; double? get panDy; int? get audioPositionMs; int? get audioDurationMs; double? get audioSpeed;
/// Create a copy of ReaderViewportSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderViewportSessionCopyWith<ReaderViewportSession> get copyWith => _$ReaderViewportSessionCopyWithImpl<ReaderViewportSession>(this as ReaderViewportSession, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderViewportSession&&(identical(other.viewportMode, viewportMode) || other.viewportMode == viewportMode)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset)&&(identical(other.maxScrollExtent, maxScrollExtent) || other.maxScrollExtent == maxScrollExtent)&&(identical(other.zoomScale, zoomScale) || other.zoomScale == zoomScale)&&(identical(other.panDx, panDx) || other.panDx == panDx)&&(identical(other.panDy, panDy) || other.panDy == panDy)&&(identical(other.audioPositionMs, audioPositionMs) || other.audioPositionMs == audioPositionMs)&&(identical(other.audioDurationMs, audioDurationMs) || other.audioDurationMs == audioDurationMs)&&(identical(other.audioSpeed, audioSpeed) || other.audioSpeed == audioSpeed));
}


@override
int get hashCode => Object.hash(runtimeType,viewportMode,pageIndex,pageCount,scrollOffset,maxScrollExtent,zoomScale,panDx,panDy,audioPositionMs,audioDurationMs,audioSpeed);

@override
String toString() {
  return 'ReaderViewportSession(viewportMode: $viewportMode, pageIndex: $pageIndex, pageCount: $pageCount, scrollOffset: $scrollOffset, maxScrollExtent: $maxScrollExtent, zoomScale: $zoomScale, panDx: $panDx, panDy: $panDy, audioPositionMs: $audioPositionMs, audioDurationMs: $audioDurationMs, audioSpeed: $audioSpeed)';
}


}

/// @nodoc
abstract mixin class $ReaderViewportSessionCopyWith<$Res>  {
  factory $ReaderViewportSessionCopyWith(ReaderViewportSession value, $Res Function(ReaderViewportSession) _then) = _$ReaderViewportSessionCopyWithImpl;
@useResult
$Res call({
 String viewportMode, int? pageIndex, int? pageCount, double? scrollOffset, double? maxScrollExtent, double? zoomScale, double? panDx, double? panDy, int? audioPositionMs, int? audioDurationMs, double? audioSpeed
});




}
/// @nodoc
class _$ReaderViewportSessionCopyWithImpl<$Res>
    implements $ReaderViewportSessionCopyWith<$Res> {
  _$ReaderViewportSessionCopyWithImpl(this._self, this._then);

  final ReaderViewportSession _self;
  final $Res Function(ReaderViewportSession) _then;

/// Create a copy of ReaderViewportSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? viewportMode = null,Object? pageIndex = freezed,Object? pageCount = freezed,Object? scrollOffset = freezed,Object? maxScrollExtent = freezed,Object? zoomScale = freezed,Object? panDx = freezed,Object? panDy = freezed,Object? audioPositionMs = freezed,Object? audioDurationMs = freezed,Object? audioSpeed = freezed,}) {
  return _then(_self.copyWith(
viewportMode: null == viewportMode ? _self.viewportMode : viewportMode // ignore: cast_nullable_to_non_nullable
as String,pageIndex: freezed == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int?,pageCount: freezed == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,maxScrollExtent: freezed == maxScrollExtent ? _self.maxScrollExtent : maxScrollExtent // ignore: cast_nullable_to_non_nullable
as double?,zoomScale: freezed == zoomScale ? _self.zoomScale : zoomScale // ignore: cast_nullable_to_non_nullable
as double?,panDx: freezed == panDx ? _self.panDx : panDx // ignore: cast_nullable_to_non_nullable
as double?,panDy: freezed == panDy ? _self.panDy : panDy // ignore: cast_nullable_to_non_nullable
as double?,audioPositionMs: freezed == audioPositionMs ? _self.audioPositionMs : audioPositionMs // ignore: cast_nullable_to_non_nullable
as int?,audioDurationMs: freezed == audioDurationMs ? _self.audioDurationMs : audioDurationMs // ignore: cast_nullable_to_non_nullable
as int?,audioSpeed: freezed == audioSpeed ? _self.audioSpeed : audioSpeed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderViewportSession].
extension ReaderViewportSessionPatterns on ReaderViewportSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderViewportSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderViewportSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderViewportSession value)  $default,){
final _that = this;
switch (_that) {
case _ReaderViewportSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderViewportSession value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderViewportSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String viewportMode,  int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent,  double? zoomScale,  double? panDx,  double? panDy,  int? audioPositionMs,  int? audioDurationMs,  double? audioSpeed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderViewportSession() when $default != null:
return $default(_that.viewportMode,_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent,_that.zoomScale,_that.panDx,_that.panDy,_that.audioPositionMs,_that.audioDurationMs,_that.audioSpeed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String viewportMode,  int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent,  double? zoomScale,  double? panDx,  double? panDy,  int? audioPositionMs,  int? audioDurationMs,  double? audioSpeed)  $default,) {final _that = this;
switch (_that) {
case _ReaderViewportSession():
return $default(_that.viewportMode,_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent,_that.zoomScale,_that.panDx,_that.panDy,_that.audioPositionMs,_that.audioDurationMs,_that.audioSpeed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String viewportMode,  int? pageIndex,  int? pageCount,  double? scrollOffset,  double? maxScrollExtent,  double? zoomScale,  double? panDx,  double? panDy,  int? audioPositionMs,  int? audioDurationMs,  double? audioSpeed)?  $default,) {final _that = this;
switch (_that) {
case _ReaderViewportSession() when $default != null:
return $default(_that.viewportMode,_that.pageIndex,_that.pageCount,_that.scrollOffset,_that.maxScrollExtent,_that.zoomScale,_that.panDx,_that.panDy,_that.audioPositionMs,_that.audioDurationMs,_that.audioSpeed);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderViewportSession extends ReaderViewportSession {
  const _ReaderViewportSession({required this.viewportMode, this.pageIndex, this.pageCount, this.scrollOffset, this.maxScrollExtent, this.zoomScale, this.panDx, this.panDy, this.audioPositionMs, this.audioDurationMs, this.audioSpeed}): super._();
  

@override final  String viewportMode;
@override final  int? pageIndex;
@override final  int? pageCount;
@override final  double? scrollOffset;
@override final  double? maxScrollExtent;
@override final  double? zoomScale;
@override final  double? panDx;
@override final  double? panDy;
@override final  int? audioPositionMs;
@override final  int? audioDurationMs;
@override final  double? audioSpeed;

/// Create a copy of ReaderViewportSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderViewportSessionCopyWith<_ReaderViewportSession> get copyWith => __$ReaderViewportSessionCopyWithImpl<_ReaderViewportSession>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderViewportSession&&(identical(other.viewportMode, viewportMode) || other.viewportMode == viewportMode)&&(identical(other.pageIndex, pageIndex) || other.pageIndex == pageIndex)&&(identical(other.pageCount, pageCount) || other.pageCount == pageCount)&&(identical(other.scrollOffset, scrollOffset) || other.scrollOffset == scrollOffset)&&(identical(other.maxScrollExtent, maxScrollExtent) || other.maxScrollExtent == maxScrollExtent)&&(identical(other.zoomScale, zoomScale) || other.zoomScale == zoomScale)&&(identical(other.panDx, panDx) || other.panDx == panDx)&&(identical(other.panDy, panDy) || other.panDy == panDy)&&(identical(other.audioPositionMs, audioPositionMs) || other.audioPositionMs == audioPositionMs)&&(identical(other.audioDurationMs, audioDurationMs) || other.audioDurationMs == audioDurationMs)&&(identical(other.audioSpeed, audioSpeed) || other.audioSpeed == audioSpeed));
}


@override
int get hashCode => Object.hash(runtimeType,viewportMode,pageIndex,pageCount,scrollOffset,maxScrollExtent,zoomScale,panDx,panDy,audioPositionMs,audioDurationMs,audioSpeed);

@override
String toString() {
  return 'ReaderViewportSession(viewportMode: $viewportMode, pageIndex: $pageIndex, pageCount: $pageCount, scrollOffset: $scrollOffset, maxScrollExtent: $maxScrollExtent, zoomScale: $zoomScale, panDx: $panDx, panDy: $panDy, audioPositionMs: $audioPositionMs, audioDurationMs: $audioDurationMs, audioSpeed: $audioSpeed)';
}


}

/// @nodoc
abstract mixin class _$ReaderViewportSessionCopyWith<$Res> implements $ReaderViewportSessionCopyWith<$Res> {
  factory _$ReaderViewportSessionCopyWith(_ReaderViewportSession value, $Res Function(_ReaderViewportSession) _then) = __$ReaderViewportSessionCopyWithImpl;
@override @useResult
$Res call({
 String viewportMode, int? pageIndex, int? pageCount, double? scrollOffset, double? maxScrollExtent, double? zoomScale, double? panDx, double? panDy, int? audioPositionMs, int? audioDurationMs, double? audioSpeed
});




}
/// @nodoc
class __$ReaderViewportSessionCopyWithImpl<$Res>
    implements _$ReaderViewportSessionCopyWith<$Res> {
  __$ReaderViewportSessionCopyWithImpl(this._self, this._then);

  final _ReaderViewportSession _self;
  final $Res Function(_ReaderViewportSession) _then;

/// Create a copy of ReaderViewportSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? viewportMode = null,Object? pageIndex = freezed,Object? pageCount = freezed,Object? scrollOffset = freezed,Object? maxScrollExtent = freezed,Object? zoomScale = freezed,Object? panDx = freezed,Object? panDy = freezed,Object? audioPositionMs = freezed,Object? audioDurationMs = freezed,Object? audioSpeed = freezed,}) {
  return _then(_ReaderViewportSession(
viewportMode: null == viewportMode ? _self.viewportMode : viewportMode // ignore: cast_nullable_to_non_nullable
as String,pageIndex: freezed == pageIndex ? _self.pageIndex : pageIndex // ignore: cast_nullable_to_non_nullable
as int?,pageCount: freezed == pageCount ? _self.pageCount : pageCount // ignore: cast_nullable_to_non_nullable
as int?,scrollOffset: freezed == scrollOffset ? _self.scrollOffset : scrollOffset // ignore: cast_nullable_to_non_nullable
as double?,maxScrollExtent: freezed == maxScrollExtent ? _self.maxScrollExtent : maxScrollExtent // ignore: cast_nullable_to_non_nullable
as double?,zoomScale: freezed == zoomScale ? _self.zoomScale : zoomScale // ignore: cast_nullable_to_non_nullable
as double?,panDx: freezed == panDx ? _self.panDx : panDx // ignore: cast_nullable_to_non_nullable
as double?,panDy: freezed == panDy ? _self.panDy : panDy // ignore: cast_nullable_to_non_nullable
as double?,audioPositionMs: freezed == audioPositionMs ? _self.audioPositionMs : audioPositionMs // ignore: cast_nullable_to_non_nullable
as int?,audioDurationMs: freezed == audioDurationMs ? _self.audioDurationMs : audioDurationMs // ignore: cast_nullable_to_non_nullable
as int?,audioSpeed: freezed == audioSpeed ? _self.audioSpeed : audioSpeed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$ReaderSessionState {

 int get currentChapterIndex; String get currentChapterId; String get currentChapterUrl; String get currentChapterTitle; ReaderLogicalPosition get logicalPosition; ReaderVisiblePosition get visiblePosition; ReaderViewportSession get viewportSession; TextReaderRendererKind get rendererKind; bool get isAutoReading; bool get isChapterTransitioning;
/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSessionStateCopyWith<ReaderSessionState> get copyWith => _$ReaderSessionStateCopyWithImpl<ReaderSessionState>(this as ReaderSessionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSessionState&&(identical(other.currentChapterIndex, currentChapterIndex) || other.currentChapterIndex == currentChapterIndex)&&(identical(other.currentChapterId, currentChapterId) || other.currentChapterId == currentChapterId)&&(identical(other.currentChapterUrl, currentChapterUrl) || other.currentChapterUrl == currentChapterUrl)&&(identical(other.currentChapterTitle, currentChapterTitle) || other.currentChapterTitle == currentChapterTitle)&&(identical(other.logicalPosition, logicalPosition) || other.logicalPosition == logicalPosition)&&(identical(other.visiblePosition, visiblePosition) || other.visiblePosition == visiblePosition)&&(identical(other.viewportSession, viewportSession) || other.viewportSession == viewportSession)&&(identical(other.rendererKind, rendererKind) || other.rendererKind == rendererKind)&&(identical(other.isAutoReading, isAutoReading) || other.isAutoReading == isAutoReading)&&(identical(other.isChapterTransitioning, isChapterTransitioning) || other.isChapterTransitioning == isChapterTransitioning));
}


@override
int get hashCode => Object.hash(runtimeType,currentChapterIndex,currentChapterId,currentChapterUrl,currentChapterTitle,logicalPosition,visiblePosition,viewportSession,rendererKind,isAutoReading,isChapterTransitioning);

@override
String toString() {
  return 'ReaderSessionState(currentChapterIndex: $currentChapterIndex, currentChapterId: $currentChapterId, currentChapterUrl: $currentChapterUrl, currentChapterTitle: $currentChapterTitle, logicalPosition: $logicalPosition, visiblePosition: $visiblePosition, viewportSession: $viewportSession, rendererKind: $rendererKind, isAutoReading: $isAutoReading, isChapterTransitioning: $isChapterTransitioning)';
}


}

/// @nodoc
abstract mixin class $ReaderSessionStateCopyWith<$Res>  {
  factory $ReaderSessionStateCopyWith(ReaderSessionState value, $Res Function(ReaderSessionState) _then) = _$ReaderSessionStateCopyWithImpl;
@useResult
$Res call({
 int currentChapterIndex, String currentChapterId, String currentChapterUrl, String currentChapterTitle, ReaderLogicalPosition logicalPosition, ReaderVisiblePosition visiblePosition, ReaderViewportSession viewportSession, TextReaderRendererKind rendererKind, bool isAutoReading, bool isChapterTransitioning
});


$ReaderVisiblePositionCopyWith<$Res> get visiblePosition;$ReaderViewportSessionCopyWith<$Res> get viewportSession;

}
/// @nodoc
class _$ReaderSessionStateCopyWithImpl<$Res>
    implements $ReaderSessionStateCopyWith<$Res> {
  _$ReaderSessionStateCopyWithImpl(this._self, this._then);

  final ReaderSessionState _self;
  final $Res Function(ReaderSessionState) _then;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentChapterIndex = null,Object? currentChapterId = null,Object? currentChapterUrl = null,Object? currentChapterTitle = null,Object? logicalPosition = null,Object? visiblePosition = null,Object? viewportSession = null,Object? rendererKind = null,Object? isAutoReading = null,Object? isChapterTransitioning = null,}) {
  return _then(_self.copyWith(
currentChapterIndex: null == currentChapterIndex ? _self.currentChapterIndex : currentChapterIndex // ignore: cast_nullable_to_non_nullable
as int,currentChapterId: null == currentChapterId ? _self.currentChapterId : currentChapterId // ignore: cast_nullable_to_non_nullable
as String,currentChapterUrl: null == currentChapterUrl ? _self.currentChapterUrl : currentChapterUrl // ignore: cast_nullable_to_non_nullable
as String,currentChapterTitle: null == currentChapterTitle ? _self.currentChapterTitle : currentChapterTitle // ignore: cast_nullable_to_non_nullable
as String,logicalPosition: null == logicalPosition ? _self.logicalPosition : logicalPosition // ignore: cast_nullable_to_non_nullable
as ReaderLogicalPosition,visiblePosition: null == visiblePosition ? _self.visiblePosition : visiblePosition // ignore: cast_nullable_to_non_nullable
as ReaderVisiblePosition,viewportSession: null == viewportSession ? _self.viewportSession : viewportSession // ignore: cast_nullable_to_non_nullable
as ReaderViewportSession,rendererKind: null == rendererKind ? _self.rendererKind : rendererKind // ignore: cast_nullable_to_non_nullable
as TextReaderRendererKind,isAutoReading: null == isAutoReading ? _self.isAutoReading : isAutoReading // ignore: cast_nullable_to_non_nullable
as bool,isChapterTransitioning: null == isChapterTransitioning ? _self.isChapterTransitioning : isChapterTransitioning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReaderVisiblePositionCopyWith<$Res> get visiblePosition {
  
  return $ReaderVisiblePositionCopyWith<$Res>(_self.visiblePosition, (value) {
    return _then(_self.copyWith(visiblePosition: value));
  });
}/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReaderViewportSessionCopyWith<$Res> get viewportSession {
  
  return $ReaderViewportSessionCopyWith<$Res>(_self.viewportSession, (value) {
    return _then(_self.copyWith(viewportSession: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReaderSessionState].
extension ReaderSessionStatePatterns on ReaderSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSessionState value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int currentChapterIndex,  String currentChapterId,  String currentChapterUrl,  String currentChapterTitle,  ReaderLogicalPosition logicalPosition,  ReaderVisiblePosition visiblePosition,  ReaderViewportSession viewportSession,  TextReaderRendererKind rendererKind,  bool isAutoReading,  bool isChapterTransitioning)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
return $default(_that.currentChapterIndex,_that.currentChapterId,_that.currentChapterUrl,_that.currentChapterTitle,_that.logicalPosition,_that.visiblePosition,_that.viewportSession,_that.rendererKind,_that.isAutoReading,_that.isChapterTransitioning);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int currentChapterIndex,  String currentChapterId,  String currentChapterUrl,  String currentChapterTitle,  ReaderLogicalPosition logicalPosition,  ReaderVisiblePosition visiblePosition,  ReaderViewportSession viewportSession,  TextReaderRendererKind rendererKind,  bool isAutoReading,  bool isChapterTransitioning)  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionState():
return $default(_that.currentChapterIndex,_that.currentChapterId,_that.currentChapterUrl,_that.currentChapterTitle,_that.logicalPosition,_that.visiblePosition,_that.viewportSession,_that.rendererKind,_that.isAutoReading,_that.isChapterTransitioning);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int currentChapterIndex,  String currentChapterId,  String currentChapterUrl,  String currentChapterTitle,  ReaderLogicalPosition logicalPosition,  ReaderVisiblePosition visiblePosition,  ReaderViewportSession viewportSession,  TextReaderRendererKind rendererKind,  bool isAutoReading,  bool isChapterTransitioning)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSessionState() when $default != null:
return $default(_that.currentChapterIndex,_that.currentChapterId,_that.currentChapterUrl,_that.currentChapterTitle,_that.logicalPosition,_that.visiblePosition,_that.viewportSession,_that.rendererKind,_that.isAutoReading,_that.isChapterTransitioning);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSessionState implements ReaderSessionState {
  const _ReaderSessionState({required this.currentChapterIndex, required this.currentChapterId, required this.currentChapterUrl, required this.currentChapterTitle, required this.logicalPosition, required this.visiblePosition, required this.viewportSession, required this.rendererKind, required this.isAutoReading, required this.isChapterTransitioning});
  

@override final  int currentChapterIndex;
@override final  String currentChapterId;
@override final  String currentChapterUrl;
@override final  String currentChapterTitle;
@override final  ReaderLogicalPosition logicalPosition;
@override final  ReaderVisiblePosition visiblePosition;
@override final  ReaderViewportSession viewportSession;
@override final  TextReaderRendererKind rendererKind;
@override final  bool isAutoReading;
@override final  bool isChapterTransitioning;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSessionStateCopyWith<_ReaderSessionState> get copyWith => __$ReaderSessionStateCopyWithImpl<_ReaderSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSessionState&&(identical(other.currentChapterIndex, currentChapterIndex) || other.currentChapterIndex == currentChapterIndex)&&(identical(other.currentChapterId, currentChapterId) || other.currentChapterId == currentChapterId)&&(identical(other.currentChapterUrl, currentChapterUrl) || other.currentChapterUrl == currentChapterUrl)&&(identical(other.currentChapterTitle, currentChapterTitle) || other.currentChapterTitle == currentChapterTitle)&&(identical(other.logicalPosition, logicalPosition) || other.logicalPosition == logicalPosition)&&(identical(other.visiblePosition, visiblePosition) || other.visiblePosition == visiblePosition)&&(identical(other.viewportSession, viewportSession) || other.viewportSession == viewportSession)&&(identical(other.rendererKind, rendererKind) || other.rendererKind == rendererKind)&&(identical(other.isAutoReading, isAutoReading) || other.isAutoReading == isAutoReading)&&(identical(other.isChapterTransitioning, isChapterTransitioning) || other.isChapterTransitioning == isChapterTransitioning));
}


@override
int get hashCode => Object.hash(runtimeType,currentChapterIndex,currentChapterId,currentChapterUrl,currentChapterTitle,logicalPosition,visiblePosition,viewportSession,rendererKind,isAutoReading,isChapterTransitioning);

@override
String toString() {
  return 'ReaderSessionState(currentChapterIndex: $currentChapterIndex, currentChapterId: $currentChapterId, currentChapterUrl: $currentChapterUrl, currentChapterTitle: $currentChapterTitle, logicalPosition: $logicalPosition, visiblePosition: $visiblePosition, viewportSession: $viewportSession, rendererKind: $rendererKind, isAutoReading: $isAutoReading, isChapterTransitioning: $isChapterTransitioning)';
}


}

/// @nodoc
abstract mixin class _$ReaderSessionStateCopyWith<$Res> implements $ReaderSessionStateCopyWith<$Res> {
  factory _$ReaderSessionStateCopyWith(_ReaderSessionState value, $Res Function(_ReaderSessionState) _then) = __$ReaderSessionStateCopyWithImpl;
@override @useResult
$Res call({
 int currentChapterIndex, String currentChapterId, String currentChapterUrl, String currentChapterTitle, ReaderLogicalPosition logicalPosition, ReaderVisiblePosition visiblePosition, ReaderViewportSession viewportSession, TextReaderRendererKind rendererKind, bool isAutoReading, bool isChapterTransitioning
});


@override $ReaderVisiblePositionCopyWith<$Res> get visiblePosition;@override $ReaderViewportSessionCopyWith<$Res> get viewportSession;

}
/// @nodoc
class __$ReaderSessionStateCopyWithImpl<$Res>
    implements _$ReaderSessionStateCopyWith<$Res> {
  __$ReaderSessionStateCopyWithImpl(this._self, this._then);

  final _ReaderSessionState _self;
  final $Res Function(_ReaderSessionState) _then;

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentChapterIndex = null,Object? currentChapterId = null,Object? currentChapterUrl = null,Object? currentChapterTitle = null,Object? logicalPosition = null,Object? visiblePosition = null,Object? viewportSession = null,Object? rendererKind = null,Object? isAutoReading = null,Object? isChapterTransitioning = null,}) {
  return _then(_ReaderSessionState(
currentChapterIndex: null == currentChapterIndex ? _self.currentChapterIndex : currentChapterIndex // ignore: cast_nullable_to_non_nullable
as int,currentChapterId: null == currentChapterId ? _self.currentChapterId : currentChapterId // ignore: cast_nullable_to_non_nullable
as String,currentChapterUrl: null == currentChapterUrl ? _self.currentChapterUrl : currentChapterUrl // ignore: cast_nullable_to_non_nullable
as String,currentChapterTitle: null == currentChapterTitle ? _self.currentChapterTitle : currentChapterTitle // ignore: cast_nullable_to_non_nullable
as String,logicalPosition: null == logicalPosition ? _self.logicalPosition : logicalPosition // ignore: cast_nullable_to_non_nullable
as ReaderLogicalPosition,visiblePosition: null == visiblePosition ? _self.visiblePosition : visiblePosition // ignore: cast_nullable_to_non_nullable
as ReaderVisiblePosition,viewportSession: null == viewportSession ? _self.viewportSession : viewportSession // ignore: cast_nullable_to_non_nullable
as ReaderViewportSession,rendererKind: null == rendererKind ? _self.rendererKind : rendererKind // ignore: cast_nullable_to_non_nullable
as TextReaderRendererKind,isAutoReading: null == isAutoReading ? _self.isAutoReading : isAutoReading // ignore: cast_nullable_to_non_nullable
as bool,isChapterTransitioning: null == isChapterTransitioning ? _self.isChapterTransitioning : isChapterTransitioning // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReaderVisiblePositionCopyWith<$Res> get visiblePosition {
  
  return $ReaderVisiblePositionCopyWith<$Res>(_self.visiblePosition, (value) {
    return _then(_self.copyWith(visiblePosition: value));
  });
}/// Create a copy of ReaderSessionState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReaderViewportSessionCopyWith<$Res> get viewportSession {
  
  return $ReaderViewportSessionCopyWith<$Res>(_self.viewportSession, (value) {
    return _then(_self.copyWith(viewportSession: value));
  });
}
}

// dart format on
