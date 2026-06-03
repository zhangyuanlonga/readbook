// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_selection_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReaderSelectionState {

 SelectedContentRange? get range; SelectionStatus get status; bool get isActive; int get startOffset; int get endOffset; String get snippet; bool get highlight; bool get bold; bool get underline; bool get wavy;
/// Create a copy of ReaderSelectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSelectionStateCopyWith<ReaderSelectionState> get copyWith => _$ReaderSelectionStateCopyWithImpl<ReaderSelectionState>(this as ReaderSelectionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSelectionState&&(identical(other.range, range) || other.range == range)&&(identical(other.status, status) || other.status == status)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.highlight, highlight) || other.highlight == highlight)&&(identical(other.bold, bold) || other.bold == bold)&&(identical(other.underline, underline) || other.underline == underline)&&(identical(other.wavy, wavy) || other.wavy == wavy));
}


@override
int get hashCode => Object.hash(runtimeType,range,status,isActive,startOffset,endOffset,snippet,highlight,bold,underline,wavy);

@override
String toString() {
  return 'ReaderSelectionState(range: $range, status: $status, isActive: $isActive, startOffset: $startOffset, endOffset: $endOffset, snippet: $snippet, highlight: $highlight, bold: $bold, underline: $underline, wavy: $wavy)';
}


}

/// @nodoc
abstract mixin class $ReaderSelectionStateCopyWith<$Res>  {
  factory $ReaderSelectionStateCopyWith(ReaderSelectionState value, $Res Function(ReaderSelectionState) _then) = _$ReaderSelectionStateCopyWithImpl;
@useResult
$Res call({
 SelectedContentRange? range, SelectionStatus status, bool isActive, int startOffset, int endOffset, String snippet, bool highlight, bool bold, bool underline, bool wavy
});




}
/// @nodoc
class _$ReaderSelectionStateCopyWithImpl<$Res>
    implements $ReaderSelectionStateCopyWith<$Res> {
  _$ReaderSelectionStateCopyWithImpl(this._self, this._then);

  final ReaderSelectionState _self;
  final $Res Function(ReaderSelectionState) _then;

/// Create a copy of ReaderSelectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? range = freezed,Object? status = null,Object? isActive = null,Object? startOffset = null,Object? endOffset = null,Object? snippet = null,Object? highlight = null,Object? bold = null,Object? underline = null,Object? wavy = null,}) {
  return _then(_self.copyWith(
range: freezed == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as SelectedContentRange?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SelectionStatus,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,startOffset: null == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as int,endOffset: null == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as int,snippet: null == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String,highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as bool,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,underline: null == underline ? _self.underline : underline // ignore: cast_nullable_to_non_nullable
as bool,wavy: null == wavy ? _self.wavy : wavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSelectionState].
extension ReaderSelectionStatePatterns on ReaderSelectionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSelectionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSelectionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSelectionState value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSelectionState value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SelectedContentRange? range,  SelectionStatus status,  bool isActive,  int startOffset,  int endOffset,  String snippet,  bool highlight,  bool bold,  bool underline,  bool wavy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSelectionState() when $default != null:
return $default(_that.range,_that.status,_that.isActive,_that.startOffset,_that.endOffset,_that.snippet,_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SelectedContentRange? range,  SelectionStatus status,  bool isActive,  int startOffset,  int endOffset,  String snippet,  bool highlight,  bool bold,  bool underline,  bool wavy)  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionState():
return $default(_that.range,_that.status,_that.isActive,_that.startOffset,_that.endOffset,_that.snippet,_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SelectedContentRange? range,  SelectionStatus status,  bool isActive,  int startOffset,  int endOffset,  String snippet,  bool highlight,  bool bold,  bool underline,  bool wavy)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionState() when $default != null:
return $default(_that.range,_that.status,_that.isActive,_that.startOffset,_that.endOffset,_that.snippet,_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSelectionState extends ReaderSelectionState {
  const _ReaderSelectionState({this.range, this.status = SelectionStatus.none, this.isActive = false, this.startOffset = 0, this.endOffset = 0, this.snippet = '', this.highlight = false, this.bold = false, this.underline = false, this.wavy = false}): super._();
  

@override final  SelectedContentRange? range;
@override@JsonKey() final  SelectionStatus status;
@override@JsonKey() final  bool isActive;
@override@JsonKey() final  int startOffset;
@override@JsonKey() final  int endOffset;
@override@JsonKey() final  String snippet;
@override@JsonKey() final  bool highlight;
@override@JsonKey() final  bool bold;
@override@JsonKey() final  bool underline;
@override@JsonKey() final  bool wavy;

/// Create a copy of ReaderSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSelectionStateCopyWith<_ReaderSelectionState> get copyWith => __$ReaderSelectionStateCopyWithImpl<_ReaderSelectionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSelectionState&&(identical(other.range, range) || other.range == range)&&(identical(other.status, status) || other.status == status)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.highlight, highlight) || other.highlight == highlight)&&(identical(other.bold, bold) || other.bold == bold)&&(identical(other.underline, underline) || other.underline == underline)&&(identical(other.wavy, wavy) || other.wavy == wavy));
}


@override
int get hashCode => Object.hash(runtimeType,range,status,isActive,startOffset,endOffset,snippet,highlight,bold,underline,wavy);

@override
String toString() {
  return 'ReaderSelectionState(range: $range, status: $status, isActive: $isActive, startOffset: $startOffset, endOffset: $endOffset, snippet: $snippet, highlight: $highlight, bold: $bold, underline: $underline, wavy: $wavy)';
}


}

/// @nodoc
abstract mixin class _$ReaderSelectionStateCopyWith<$Res> implements $ReaderSelectionStateCopyWith<$Res> {
  factory _$ReaderSelectionStateCopyWith(_ReaderSelectionState value, $Res Function(_ReaderSelectionState) _then) = __$ReaderSelectionStateCopyWithImpl;
@override @useResult
$Res call({
 SelectedContentRange? range, SelectionStatus status, bool isActive, int startOffset, int endOffset, String snippet, bool highlight, bool bold, bool underline, bool wavy
});




}
/// @nodoc
class __$ReaderSelectionStateCopyWithImpl<$Res>
    implements _$ReaderSelectionStateCopyWith<$Res> {
  __$ReaderSelectionStateCopyWithImpl(this._self, this._then);

  final _ReaderSelectionState _self;
  final $Res Function(_ReaderSelectionState) _then;

/// Create a copy of ReaderSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? range = freezed,Object? status = null,Object? isActive = null,Object? startOffset = null,Object? endOffset = null,Object? snippet = null,Object? highlight = null,Object? bold = null,Object? underline = null,Object? wavy = null,}) {
  return _then(_ReaderSelectionState(
range: freezed == range ? _self.range : range // ignore: cast_nullable_to_non_nullable
as SelectedContentRange?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as SelectionStatus,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,startOffset: null == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as int,endOffset: null == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as int,snippet: null == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String,highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as bool,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,underline: null == underline ? _self.underline : underline // ignore: cast_nullable_to_non_nullable
as bool,wavy: null == wavy ? _self.wavy : wavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ReaderSelectionSnapshot {

 int get startOffset; int get endOffset; String get snippet; bool get hasHighlight; bool get isBold; bool get isUnderline; bool get isWavy;
/// Create a copy of ReaderSelectionSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSelectionSnapshotCopyWith<ReaderSelectionSnapshot> get copyWith => _$ReaderSelectionSnapshotCopyWithImpl<ReaderSelectionSnapshot>(this as ReaderSelectionSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSelectionSnapshot&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.hasHighlight, hasHighlight) || other.hasHighlight == hasHighlight)&&(identical(other.isBold, isBold) || other.isBold == isBold)&&(identical(other.isUnderline, isUnderline) || other.isUnderline == isUnderline)&&(identical(other.isWavy, isWavy) || other.isWavy == isWavy));
}


@override
int get hashCode => Object.hash(runtimeType,startOffset,endOffset,snippet,hasHighlight,isBold,isUnderline,isWavy);

@override
String toString() {
  return 'ReaderSelectionSnapshot(startOffset: $startOffset, endOffset: $endOffset, snippet: $snippet, hasHighlight: $hasHighlight, isBold: $isBold, isUnderline: $isUnderline, isWavy: $isWavy)';
}


}

/// @nodoc
abstract mixin class $ReaderSelectionSnapshotCopyWith<$Res>  {
  factory $ReaderSelectionSnapshotCopyWith(ReaderSelectionSnapshot value, $Res Function(ReaderSelectionSnapshot) _then) = _$ReaderSelectionSnapshotCopyWithImpl;
@useResult
$Res call({
 int startOffset, int endOffset, String snippet, bool hasHighlight, bool isBold, bool isUnderline, bool isWavy
});




}
/// @nodoc
class _$ReaderSelectionSnapshotCopyWithImpl<$Res>
    implements $ReaderSelectionSnapshotCopyWith<$Res> {
  _$ReaderSelectionSnapshotCopyWithImpl(this._self, this._then);

  final ReaderSelectionSnapshot _self;
  final $Res Function(ReaderSelectionSnapshot) _then;

/// Create a copy of ReaderSelectionSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? startOffset = null,Object? endOffset = null,Object? snippet = null,Object? hasHighlight = null,Object? isBold = null,Object? isUnderline = null,Object? isWavy = null,}) {
  return _then(_self.copyWith(
startOffset: null == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as int,endOffset: null == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as int,snippet: null == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String,hasHighlight: null == hasHighlight ? _self.hasHighlight : hasHighlight // ignore: cast_nullable_to_non_nullable
as bool,isBold: null == isBold ? _self.isBold : isBold // ignore: cast_nullable_to_non_nullable
as bool,isUnderline: null == isUnderline ? _self.isUnderline : isUnderline // ignore: cast_nullable_to_non_nullable
as bool,isWavy: null == isWavy ? _self.isWavy : isWavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSelectionSnapshot].
extension ReaderSelectionSnapshotPatterns on ReaderSelectionSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSelectionSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSelectionSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSelectionSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int startOffset,  int endOffset,  String snippet,  bool hasHighlight,  bool isBold,  bool isUnderline,  bool isWavy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot() when $default != null:
return $default(_that.startOffset,_that.endOffset,_that.snippet,_that.hasHighlight,_that.isBold,_that.isUnderline,_that.isWavy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int startOffset,  int endOffset,  String snippet,  bool hasHighlight,  bool isBold,  bool isUnderline,  bool isWavy)  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot():
return $default(_that.startOffset,_that.endOffset,_that.snippet,_that.hasHighlight,_that.isBold,_that.isUnderline,_that.isWavy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int startOffset,  int endOffset,  String snippet,  bool hasHighlight,  bool isBold,  bool isUnderline,  bool isWavy)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionSnapshot() when $default != null:
return $default(_that.startOffset,_that.endOffset,_that.snippet,_that.hasHighlight,_that.isBold,_that.isUnderline,_that.isWavy);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSelectionSnapshot implements ReaderSelectionSnapshot {
  const _ReaderSelectionSnapshot({required this.startOffset, required this.endOffset, required this.snippet, required this.hasHighlight, required this.isBold, required this.isUnderline, required this.isWavy});
  

@override final  int startOffset;
@override final  int endOffset;
@override final  String snippet;
@override final  bool hasHighlight;
@override final  bool isBold;
@override final  bool isUnderline;
@override final  bool isWavy;

/// Create a copy of ReaderSelectionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSelectionSnapshotCopyWith<_ReaderSelectionSnapshot> get copyWith => __$ReaderSelectionSnapshotCopyWithImpl<_ReaderSelectionSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSelectionSnapshot&&(identical(other.startOffset, startOffset) || other.startOffset == startOffset)&&(identical(other.endOffset, endOffset) || other.endOffset == endOffset)&&(identical(other.snippet, snippet) || other.snippet == snippet)&&(identical(other.hasHighlight, hasHighlight) || other.hasHighlight == hasHighlight)&&(identical(other.isBold, isBold) || other.isBold == isBold)&&(identical(other.isUnderline, isUnderline) || other.isUnderline == isUnderline)&&(identical(other.isWavy, isWavy) || other.isWavy == isWavy));
}


@override
int get hashCode => Object.hash(runtimeType,startOffset,endOffset,snippet,hasHighlight,isBold,isUnderline,isWavy);

@override
String toString() {
  return 'ReaderSelectionSnapshot(startOffset: $startOffset, endOffset: $endOffset, snippet: $snippet, hasHighlight: $hasHighlight, isBold: $isBold, isUnderline: $isUnderline, isWavy: $isWavy)';
}


}

/// @nodoc
abstract mixin class _$ReaderSelectionSnapshotCopyWith<$Res> implements $ReaderSelectionSnapshotCopyWith<$Res> {
  factory _$ReaderSelectionSnapshotCopyWith(_ReaderSelectionSnapshot value, $Res Function(_ReaderSelectionSnapshot) _then) = __$ReaderSelectionSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int startOffset, int endOffset, String snippet, bool hasHighlight, bool isBold, bool isUnderline, bool isWavy
});




}
/// @nodoc
class __$ReaderSelectionSnapshotCopyWithImpl<$Res>
    implements _$ReaderSelectionSnapshotCopyWith<$Res> {
  __$ReaderSelectionSnapshotCopyWithImpl(this._self, this._then);

  final _ReaderSelectionSnapshot _self;
  final $Res Function(_ReaderSelectionSnapshot) _then;

/// Create a copy of ReaderSelectionSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? startOffset = null,Object? endOffset = null,Object? snippet = null,Object? hasHighlight = null,Object? isBold = null,Object? isUnderline = null,Object? isWavy = null,}) {
  return _then(_ReaderSelectionSnapshot(
startOffset: null == startOffset ? _self.startOffset : startOffset // ignore: cast_nullable_to_non_nullable
as int,endOffset: null == endOffset ? _self.endOffset : endOffset // ignore: cast_nullable_to_non_nullable
as int,snippet: null == snippet ? _self.snippet : snippet // ignore: cast_nullable_to_non_nullable
as String,hasHighlight: null == hasHighlight ? _self.hasHighlight : hasHighlight // ignore: cast_nullable_to_non_nullable
as bool,isBold: null == isBold ? _self.isBold : isBold // ignore: cast_nullable_to_non_nullable
as bool,isUnderline: null == isUnderline ? _self.isUnderline : isUnderline // ignore: cast_nullable_to_non_nullable
as bool,isWavy: null == isWavy ? _self.isWavy : isWavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$ReaderSelectionStyle {

 bool get highlight; bool get bold; bool get underline; bool get wavy;
/// Create a copy of ReaderSelectionStyle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderSelectionStyleCopyWith<ReaderSelectionStyle> get copyWith => _$ReaderSelectionStyleCopyWithImpl<ReaderSelectionStyle>(this as ReaderSelectionStyle, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderSelectionStyle&&(identical(other.highlight, highlight) || other.highlight == highlight)&&(identical(other.bold, bold) || other.bold == bold)&&(identical(other.underline, underline) || other.underline == underline)&&(identical(other.wavy, wavy) || other.wavy == wavy));
}


@override
int get hashCode => Object.hash(runtimeType,highlight,bold,underline,wavy);

@override
String toString() {
  return 'ReaderSelectionStyle(highlight: $highlight, bold: $bold, underline: $underline, wavy: $wavy)';
}


}

/// @nodoc
abstract mixin class $ReaderSelectionStyleCopyWith<$Res>  {
  factory $ReaderSelectionStyleCopyWith(ReaderSelectionStyle value, $Res Function(ReaderSelectionStyle) _then) = _$ReaderSelectionStyleCopyWithImpl;
@useResult
$Res call({
 bool highlight, bool bold, bool underline, bool wavy
});




}
/// @nodoc
class _$ReaderSelectionStyleCopyWithImpl<$Res>
    implements $ReaderSelectionStyleCopyWith<$Res> {
  _$ReaderSelectionStyleCopyWithImpl(this._self, this._then);

  final ReaderSelectionStyle _self;
  final $Res Function(ReaderSelectionStyle) _then;

/// Create a copy of ReaderSelectionStyle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? highlight = null,Object? bold = null,Object? underline = null,Object? wavy = null,}) {
  return _then(_self.copyWith(
highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as bool,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,underline: null == underline ? _self.underline : underline // ignore: cast_nullable_to_non_nullable
as bool,wavy: null == wavy ? _self.wavy : wavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReaderSelectionStyle].
extension ReaderSelectionStylePatterns on ReaderSelectionStyle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderSelectionStyle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderSelectionStyle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderSelectionStyle value)  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionStyle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderSelectionStyle value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderSelectionStyle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool highlight,  bool bold,  bool underline,  bool wavy)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderSelectionStyle() when $default != null:
return $default(_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool highlight,  bool bold,  bool underline,  bool wavy)  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionStyle():
return $default(_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool highlight,  bool bold,  bool underline,  bool wavy)?  $default,) {final _that = this;
switch (_that) {
case _ReaderSelectionStyle() when $default != null:
return $default(_that.highlight,_that.bold,_that.underline,_that.wavy);case _:
  return null;

}
}

}

/// @nodoc


class _ReaderSelectionStyle implements ReaderSelectionStyle {
  const _ReaderSelectionStyle({required this.highlight, required this.bold, required this.underline, required this.wavy});
  

@override final  bool highlight;
@override final  bool bold;
@override final  bool underline;
@override final  bool wavy;

/// Create a copy of ReaderSelectionStyle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderSelectionStyleCopyWith<_ReaderSelectionStyle> get copyWith => __$ReaderSelectionStyleCopyWithImpl<_ReaderSelectionStyle>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderSelectionStyle&&(identical(other.highlight, highlight) || other.highlight == highlight)&&(identical(other.bold, bold) || other.bold == bold)&&(identical(other.underline, underline) || other.underline == underline)&&(identical(other.wavy, wavy) || other.wavy == wavy));
}


@override
int get hashCode => Object.hash(runtimeType,highlight,bold,underline,wavy);

@override
String toString() {
  return 'ReaderSelectionStyle(highlight: $highlight, bold: $bold, underline: $underline, wavy: $wavy)';
}


}

/// @nodoc
abstract mixin class _$ReaderSelectionStyleCopyWith<$Res> implements $ReaderSelectionStyleCopyWith<$Res> {
  factory _$ReaderSelectionStyleCopyWith(_ReaderSelectionStyle value, $Res Function(_ReaderSelectionStyle) _then) = __$ReaderSelectionStyleCopyWithImpl;
@override @useResult
$Res call({
 bool highlight, bool bold, bool underline, bool wavy
});




}
/// @nodoc
class __$ReaderSelectionStyleCopyWithImpl<$Res>
    implements _$ReaderSelectionStyleCopyWith<$Res> {
  __$ReaderSelectionStyleCopyWithImpl(this._self, this._then);

  final _ReaderSelectionStyle _self;
  final $Res Function(_ReaderSelectionStyle) _then;

/// Create a copy of ReaderSelectionStyle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? highlight = null,Object? bold = null,Object? underline = null,Object? wavy = null,}) {
  return _then(_ReaderSelectionStyle(
highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as bool,bold: null == bold ? _self.bold : bold // ignore: cast_nullable_to_non_nullable
as bool,underline: null == underline ? _self.underline : underline // ignore: cast_nullable_to_non_nullable
as bool,wavy: null == wavy ? _self.wavy : wavy // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
