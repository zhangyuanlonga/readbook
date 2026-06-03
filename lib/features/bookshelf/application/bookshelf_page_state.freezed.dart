// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bookshelf_page_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookshelfViewSelection {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookshelfViewSelection);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'BookshelfViewSelection()';
}


}

/// @nodoc
class $BookshelfViewSelectionCopyWith<$Res>  {
$BookshelfViewSelectionCopyWith(BookshelfViewSelection _, $Res Function(BookshelfViewSelection) __);
}


/// Adds pattern-matching-related methods to [BookshelfViewSelection].
extension BookshelfViewSelectionPatterns on BookshelfViewSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( _BookshelfViewBaseSelection value)?  base,TResult Function( _BookshelfViewTagSelection value)?  tag,TResult Function( _BookshelfViewCategorySelection value)?  category,required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection() when base != null:
return base(_that);case _BookshelfViewTagSelection() when tag != null:
return tag(_that);case _BookshelfViewCategorySelection() when category != null:
return category(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( _BookshelfViewBaseSelection value)  base,required TResult Function( _BookshelfViewTagSelection value)  tag,required TResult Function( _BookshelfViewCategorySelection value)  category,}){
final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection():
return base(_that);case _BookshelfViewTagSelection():
return tag(_that);case _BookshelfViewCategorySelection():
return category(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( _BookshelfViewBaseSelection value)?  base,TResult? Function( _BookshelfViewTagSelection value)?  tag,TResult? Function( _BookshelfViewCategorySelection value)?  category,}){
final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection() when base != null:
return base(_that);case _BookshelfViewTagSelection() when tag != null:
return tag(_that);case _BookshelfViewCategorySelection() when category != null:
return category(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BookshelfFilter filter)?  base,TResult Function( String? tag)?  tag,TResult Function( String? category)?  category,required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection() when base != null:
return base(_that.filter);case _BookshelfViewTagSelection() when tag != null:
return tag(_that.tag);case _BookshelfViewCategorySelection() when category != null:
return category(_that.category);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BookshelfFilter filter)  base,required TResult Function( String? tag)  tag,required TResult Function( String? category)  category,}) {final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection():
return base(_that.filter);case _BookshelfViewTagSelection():
return tag(_that.tag);case _BookshelfViewCategorySelection():
return category(_that.category);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BookshelfFilter filter)?  base,TResult? Function( String? tag)?  tag,TResult? Function( String? category)?  category,}) {final _that = this;
switch (_that) {
case _BookshelfViewBaseSelection() when base != null:
return base(_that.filter);case _BookshelfViewTagSelection() when tag != null:
return tag(_that.tag);case _BookshelfViewCategorySelection() when category != null:
return category(_that.category);case _:
  return null;

}
}

}

/// @nodoc


class _BookshelfViewBaseSelection extends BookshelfViewSelection {
  const _BookshelfViewBaseSelection(this.filter): super._();
  

 final  BookshelfFilter filter;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfViewBaseSelectionCopyWith<_BookshelfViewBaseSelection> get copyWith => __$BookshelfViewBaseSelectionCopyWithImpl<_BookshelfViewBaseSelection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfViewBaseSelection&&(identical(other.filter, filter) || other.filter == filter));
}


@override
int get hashCode => Object.hash(runtimeType,filter);

@override
String toString() {
  return 'BookshelfViewSelection.base(filter: $filter)';
}


}

/// @nodoc
abstract mixin class _$BookshelfViewBaseSelectionCopyWith<$Res> implements $BookshelfViewSelectionCopyWith<$Res> {
  factory _$BookshelfViewBaseSelectionCopyWith(_BookshelfViewBaseSelection value, $Res Function(_BookshelfViewBaseSelection) _then) = __$BookshelfViewBaseSelectionCopyWithImpl;
@useResult
$Res call({
 BookshelfFilter filter
});




}
/// @nodoc
class __$BookshelfViewBaseSelectionCopyWithImpl<$Res>
    implements _$BookshelfViewBaseSelectionCopyWith<$Res> {
  __$BookshelfViewBaseSelectionCopyWithImpl(this._self, this._then);

  final _BookshelfViewBaseSelection _self;
  final $Res Function(_BookshelfViewBaseSelection) _then;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? filter = null,}) {
  return _then(_BookshelfViewBaseSelection(
null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as BookshelfFilter,
  ));
}


}

/// @nodoc


class _BookshelfViewTagSelection extends BookshelfViewSelection {
  const _BookshelfViewTagSelection(this.tag): super._();
  

 final  String? tag;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfViewTagSelectionCopyWith<_BookshelfViewTagSelection> get copyWith => __$BookshelfViewTagSelectionCopyWithImpl<_BookshelfViewTagSelection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfViewTagSelection&&(identical(other.tag, tag) || other.tag == tag));
}


@override
int get hashCode => Object.hash(runtimeType,tag);

@override
String toString() {
  return 'BookshelfViewSelection.tag(tag: $tag)';
}


}

/// @nodoc
abstract mixin class _$BookshelfViewTagSelectionCopyWith<$Res> implements $BookshelfViewSelectionCopyWith<$Res> {
  factory _$BookshelfViewTagSelectionCopyWith(_BookshelfViewTagSelection value, $Res Function(_BookshelfViewTagSelection) _then) = __$BookshelfViewTagSelectionCopyWithImpl;
@useResult
$Res call({
 String? tag
});




}
/// @nodoc
class __$BookshelfViewTagSelectionCopyWithImpl<$Res>
    implements _$BookshelfViewTagSelectionCopyWith<$Res> {
  __$BookshelfViewTagSelectionCopyWithImpl(this._self, this._then);

  final _BookshelfViewTagSelection _self;
  final $Res Function(_BookshelfViewTagSelection) _then;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? tag = freezed,}) {
  return _then(_BookshelfViewTagSelection(
freezed == tag ? _self.tag : tag // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc


class _BookshelfViewCategorySelection extends BookshelfViewSelection {
  const _BookshelfViewCategorySelection(this.category): super._();
  

 final  String? category;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfViewCategorySelectionCopyWith<_BookshelfViewCategorySelection> get copyWith => __$BookshelfViewCategorySelectionCopyWithImpl<_BookshelfViewCategorySelection>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfViewCategorySelection&&(identical(other.category, category) || other.category == category));
}


@override
int get hashCode => Object.hash(runtimeType,category);

@override
String toString() {
  return 'BookshelfViewSelection.category(category: $category)';
}


}

/// @nodoc
abstract mixin class _$BookshelfViewCategorySelectionCopyWith<$Res> implements $BookshelfViewSelectionCopyWith<$Res> {
  factory _$BookshelfViewCategorySelectionCopyWith(_BookshelfViewCategorySelection value, $Res Function(_BookshelfViewCategorySelection) _then) = __$BookshelfViewCategorySelectionCopyWithImpl;
@useResult
$Res call({
 String? category
});




}
/// @nodoc
class __$BookshelfViewCategorySelectionCopyWithImpl<$Res>
    implements _$BookshelfViewCategorySelectionCopyWith<$Res> {
  __$BookshelfViewCategorySelectionCopyWithImpl(this._self, this._then);

  final _BookshelfViewCategorySelection _self;
  final $Res Function(_BookshelfViewCategorySelection) _then;

/// Create a copy of BookshelfViewSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? category = freezed,}) {
  return _then(_BookshelfViewCategorySelection(
freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BookshelfSelectionState {

 bool get enabled; Set<String> get selectedKeys; BookshelfBatchAction? get activeAction;
/// Create a copy of BookshelfSelectionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookshelfSelectionStateCopyWith<BookshelfSelectionState> get copyWith => _$BookshelfSelectionStateCopyWithImpl<BookshelfSelectionState>(this as BookshelfSelectionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookshelfSelectionState&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other.selectedKeys, selectedKeys)&&(identical(other.activeAction, activeAction) || other.activeAction == activeAction));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,const DeepCollectionEquality().hash(selectedKeys),activeAction);

@override
String toString() {
  return 'BookshelfSelectionState(enabled: $enabled, selectedKeys: $selectedKeys, activeAction: $activeAction)';
}


}

/// @nodoc
abstract mixin class $BookshelfSelectionStateCopyWith<$Res>  {
  factory $BookshelfSelectionStateCopyWith(BookshelfSelectionState value, $Res Function(BookshelfSelectionState) _then) = _$BookshelfSelectionStateCopyWithImpl;
@useResult
$Res call({
 bool enabled, Set<String> selectedKeys, BookshelfBatchAction? activeAction
});




}
/// @nodoc
class _$BookshelfSelectionStateCopyWithImpl<$Res>
    implements $BookshelfSelectionStateCopyWith<$Res> {
  _$BookshelfSelectionStateCopyWithImpl(this._self, this._then);

  final BookshelfSelectionState _self;
  final $Res Function(BookshelfSelectionState) _then;

/// Create a copy of BookshelfSelectionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? selectedKeys = null,Object? activeAction = freezed,}) {
  return _then(_self.copyWith(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,selectedKeys: null == selectedKeys ? _self.selectedKeys : selectedKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,activeAction: freezed == activeAction ? _self.activeAction : activeAction // ignore: cast_nullable_to_non_nullable
as BookshelfBatchAction?,
  ));
}

}


/// Adds pattern-matching-related methods to [BookshelfSelectionState].
extension BookshelfSelectionStatePatterns on BookshelfSelectionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookshelfSelectionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookshelfSelectionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookshelfSelectionState value)  $default,){
final _that = this;
switch (_that) {
case _BookshelfSelectionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookshelfSelectionState value)?  $default,){
final _that = this;
switch (_that) {
case _BookshelfSelectionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  Set<String> selectedKeys,  BookshelfBatchAction? activeAction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookshelfSelectionState() when $default != null:
return $default(_that.enabled,_that.selectedKeys,_that.activeAction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  Set<String> selectedKeys,  BookshelfBatchAction? activeAction)  $default,) {final _that = this;
switch (_that) {
case _BookshelfSelectionState():
return $default(_that.enabled,_that.selectedKeys,_that.activeAction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  Set<String> selectedKeys,  BookshelfBatchAction? activeAction)?  $default,) {final _that = this;
switch (_that) {
case _BookshelfSelectionState() when $default != null:
return $default(_that.enabled,_that.selectedKeys,_that.activeAction);case _:
  return null;

}
}

}

/// @nodoc


class _BookshelfSelectionState extends BookshelfSelectionState {
  const _BookshelfSelectionState({this.enabled = false, final  Set<String> selectedKeys = const <String>{}, this.activeAction}): _selectedKeys = selectedKeys,super._();
  

@override@JsonKey() final  bool enabled;
 final  Set<String> _selectedKeys;
@override@JsonKey() Set<String> get selectedKeys {
  if (_selectedKeys is EqualUnmodifiableSetView) return _selectedKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedKeys);
}

@override final  BookshelfBatchAction? activeAction;

/// Create a copy of BookshelfSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfSelectionStateCopyWith<_BookshelfSelectionState> get copyWith => __$BookshelfSelectionStateCopyWithImpl<_BookshelfSelectionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfSelectionState&&(identical(other.enabled, enabled) || other.enabled == enabled)&&const DeepCollectionEquality().equals(other._selectedKeys, _selectedKeys)&&(identical(other.activeAction, activeAction) || other.activeAction == activeAction));
}


@override
int get hashCode => Object.hash(runtimeType,enabled,const DeepCollectionEquality().hash(_selectedKeys),activeAction);

@override
String toString() {
  return 'BookshelfSelectionState(enabled: $enabled, selectedKeys: $selectedKeys, activeAction: $activeAction)';
}


}

/// @nodoc
abstract mixin class _$BookshelfSelectionStateCopyWith<$Res> implements $BookshelfSelectionStateCopyWith<$Res> {
  factory _$BookshelfSelectionStateCopyWith(_BookshelfSelectionState value, $Res Function(_BookshelfSelectionState) _then) = __$BookshelfSelectionStateCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, Set<String> selectedKeys, BookshelfBatchAction? activeAction
});




}
/// @nodoc
class __$BookshelfSelectionStateCopyWithImpl<$Res>
    implements _$BookshelfSelectionStateCopyWith<$Res> {
  __$BookshelfSelectionStateCopyWithImpl(this._self, this._then);

  final _BookshelfSelectionState _self;
  final $Res Function(_BookshelfSelectionState) _then;

/// Create a copy of BookshelfSelectionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? selectedKeys = null,Object? activeAction = freezed,}) {
  return _then(_BookshelfSelectionState(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,selectedKeys: null == selectedKeys ? _self._selectedKeys : selectedKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,activeAction: freezed == activeAction ? _self.activeAction : activeAction // ignore: cast_nullable_to_non_nullable
as BookshelfBatchAction?,
  ));
}


}

/// @nodoc
mixin _$BookshelfBookCardState {

 ReadingProgress? get progress; String? get latestCachedChapterTitle; int get cachedChapterCount; LocalBook? get localBook; BookDisplayState? get presentation;
/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookshelfBookCardStateCopyWith<BookshelfBookCardState> get copyWith => _$BookshelfBookCardStateCopyWithImpl<BookshelfBookCardState>(this as BookshelfBookCardState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookshelfBookCardState&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.latestCachedChapterTitle, latestCachedChapterTitle) || other.latestCachedChapterTitle == latestCachedChapterTitle)&&(identical(other.cachedChapterCount, cachedChapterCount) || other.cachedChapterCount == cachedChapterCount)&&(identical(other.localBook, localBook) || other.localBook == localBook)&&(identical(other.presentation, presentation) || other.presentation == presentation));
}


@override
int get hashCode => Object.hash(runtimeType,progress,latestCachedChapterTitle,cachedChapterCount,localBook,presentation);

@override
String toString() {
  return 'BookshelfBookCardState(progress: $progress, latestCachedChapterTitle: $latestCachedChapterTitle, cachedChapterCount: $cachedChapterCount, localBook: $localBook, presentation: $presentation)';
}


}

/// @nodoc
abstract mixin class $BookshelfBookCardStateCopyWith<$Res>  {
  factory $BookshelfBookCardStateCopyWith(BookshelfBookCardState value, $Res Function(BookshelfBookCardState) _then) = _$BookshelfBookCardStateCopyWithImpl;
@useResult
$Res call({
 ReadingProgress? progress, String? latestCachedChapterTitle, int cachedChapterCount, LocalBook? localBook, BookDisplayState? presentation
});


$BookDisplayStateCopyWith<$Res>? get presentation;

}
/// @nodoc
class _$BookshelfBookCardStateCopyWithImpl<$Res>
    implements $BookshelfBookCardStateCopyWith<$Res> {
  _$BookshelfBookCardStateCopyWithImpl(this._self, this._then);

  final BookshelfBookCardState _self;
  final $Res Function(BookshelfBookCardState) _then;

/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? progress = freezed,Object? latestCachedChapterTitle = freezed,Object? cachedChapterCount = null,Object? localBook = freezed,Object? presentation = freezed,}) {
  return _then(_self.copyWith(
progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingProgress?,latestCachedChapterTitle: freezed == latestCachedChapterTitle ? _self.latestCachedChapterTitle : latestCachedChapterTitle // ignore: cast_nullable_to_non_nullable
as String?,cachedChapterCount: null == cachedChapterCount ? _self.cachedChapterCount : cachedChapterCount // ignore: cast_nullable_to_non_nullable
as int,localBook: freezed == localBook ? _self.localBook : localBook // ignore: cast_nullable_to_non_nullable
as LocalBook?,presentation: freezed == presentation ? _self.presentation : presentation // ignore: cast_nullable_to_non_nullable
as BookDisplayState?,
  ));
}
/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookDisplayStateCopyWith<$Res>? get presentation {
    if (_self.presentation == null) {
    return null;
  }

  return $BookDisplayStateCopyWith<$Res>(_self.presentation!, (value) {
    return _then(_self.copyWith(presentation: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookshelfBookCardState].
extension BookshelfBookCardStatePatterns on BookshelfBookCardState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookshelfBookCardState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookshelfBookCardState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookshelfBookCardState value)  $default,){
final _that = this;
switch (_that) {
case _BookshelfBookCardState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookshelfBookCardState value)?  $default,){
final _that = this;
switch (_that) {
case _BookshelfBookCardState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReadingProgress? progress,  String? latestCachedChapterTitle,  int cachedChapterCount,  LocalBook? localBook,  BookDisplayState? presentation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookshelfBookCardState() when $default != null:
return $default(_that.progress,_that.latestCachedChapterTitle,_that.cachedChapterCount,_that.localBook,_that.presentation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReadingProgress? progress,  String? latestCachedChapterTitle,  int cachedChapterCount,  LocalBook? localBook,  BookDisplayState? presentation)  $default,) {final _that = this;
switch (_that) {
case _BookshelfBookCardState():
return $default(_that.progress,_that.latestCachedChapterTitle,_that.cachedChapterCount,_that.localBook,_that.presentation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReadingProgress? progress,  String? latestCachedChapterTitle,  int cachedChapterCount,  LocalBook? localBook,  BookDisplayState? presentation)?  $default,) {final _that = this;
switch (_that) {
case _BookshelfBookCardState() when $default != null:
return $default(_that.progress,_that.latestCachedChapterTitle,_that.cachedChapterCount,_that.localBook,_that.presentation);case _:
  return null;

}
}

}

/// @nodoc


class _BookshelfBookCardState extends BookshelfBookCardState {
  const _BookshelfBookCardState({this.progress, this.latestCachedChapterTitle, this.cachedChapterCount = 0, this.localBook, this.presentation}): super._();
  

@override final  ReadingProgress? progress;
@override final  String? latestCachedChapterTitle;
@override@JsonKey() final  int cachedChapterCount;
@override final  LocalBook? localBook;
@override final  BookDisplayState? presentation;

/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfBookCardStateCopyWith<_BookshelfBookCardState> get copyWith => __$BookshelfBookCardStateCopyWithImpl<_BookshelfBookCardState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfBookCardState&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.latestCachedChapterTitle, latestCachedChapterTitle) || other.latestCachedChapterTitle == latestCachedChapterTitle)&&(identical(other.cachedChapterCount, cachedChapterCount) || other.cachedChapterCount == cachedChapterCount)&&(identical(other.localBook, localBook) || other.localBook == localBook)&&(identical(other.presentation, presentation) || other.presentation == presentation));
}


@override
int get hashCode => Object.hash(runtimeType,progress,latestCachedChapterTitle,cachedChapterCount,localBook,presentation);

@override
String toString() {
  return 'BookshelfBookCardState(progress: $progress, latestCachedChapterTitle: $latestCachedChapterTitle, cachedChapterCount: $cachedChapterCount, localBook: $localBook, presentation: $presentation)';
}


}

/// @nodoc
abstract mixin class _$BookshelfBookCardStateCopyWith<$Res> implements $BookshelfBookCardStateCopyWith<$Res> {
  factory _$BookshelfBookCardStateCopyWith(_BookshelfBookCardState value, $Res Function(_BookshelfBookCardState) _then) = __$BookshelfBookCardStateCopyWithImpl;
@override @useResult
$Res call({
 ReadingProgress? progress, String? latestCachedChapterTitle, int cachedChapterCount, LocalBook? localBook, BookDisplayState? presentation
});


@override $BookDisplayStateCopyWith<$Res>? get presentation;

}
/// @nodoc
class __$BookshelfBookCardStateCopyWithImpl<$Res>
    implements _$BookshelfBookCardStateCopyWith<$Res> {
  __$BookshelfBookCardStateCopyWithImpl(this._self, this._then);

  final _BookshelfBookCardState _self;
  final $Res Function(_BookshelfBookCardState) _then;

/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? progress = freezed,Object? latestCachedChapterTitle = freezed,Object? cachedChapterCount = null,Object? localBook = freezed,Object? presentation = freezed,}) {
  return _then(_BookshelfBookCardState(
progress: freezed == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingProgress?,latestCachedChapterTitle: freezed == latestCachedChapterTitle ? _self.latestCachedChapterTitle : latestCachedChapterTitle // ignore: cast_nullable_to_non_nullable
as String?,cachedChapterCount: null == cachedChapterCount ? _self.cachedChapterCount : cachedChapterCount // ignore: cast_nullable_to_non_nullable
as int,localBook: freezed == localBook ? _self.localBook : localBook // ignore: cast_nullable_to_non_nullable
as LocalBook?,presentation: freezed == presentation ? _self.presentation : presentation // ignore: cast_nullable_to_non_nullable
as BookDisplayState?,
  ));
}

/// Create a copy of BookshelfBookCardState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookDisplayStateCopyWith<$Res>? get presentation {
    if (_self.presentation == null) {
    return null;
  }

  return $BookDisplayStateCopyWith<$Res>(_self.presentation!, (value) {
    return _then(_self.copyWith(presentation: value));
  });
}
}

/// @nodoc
mixin _$BookshelfPageState {

 List<BookshelfFilter> get baseFilterOrder; BookshelfViewSelection get activeView; BookshelfSortMode get sortMode; BookshelfSelectionState get selection; Map<String, BookshelfBookCardState> get cardStatesByKey;
/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookshelfPageStateCopyWith<BookshelfPageState> get copyWith => _$BookshelfPageStateCopyWithImpl<BookshelfPageState>(this as BookshelfPageState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookshelfPageState&&const DeepCollectionEquality().equals(other.baseFilterOrder, baseFilterOrder)&&(identical(other.activeView, activeView) || other.activeView == activeView)&&(identical(other.sortMode, sortMode) || other.sortMode == sortMode)&&(identical(other.selection, selection) || other.selection == selection)&&const DeepCollectionEquality().equals(other.cardStatesByKey, cardStatesByKey));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(baseFilterOrder),activeView,sortMode,selection,const DeepCollectionEquality().hash(cardStatesByKey));

@override
String toString() {
  return 'BookshelfPageState(baseFilterOrder: $baseFilterOrder, activeView: $activeView, sortMode: $sortMode, selection: $selection, cardStatesByKey: $cardStatesByKey)';
}


}

/// @nodoc
abstract mixin class $BookshelfPageStateCopyWith<$Res>  {
  factory $BookshelfPageStateCopyWith(BookshelfPageState value, $Res Function(BookshelfPageState) _then) = _$BookshelfPageStateCopyWithImpl;
@useResult
$Res call({
 List<BookshelfFilter> baseFilterOrder, BookshelfViewSelection activeView, BookshelfSortMode sortMode, BookshelfSelectionState selection, Map<String, BookshelfBookCardState> cardStatesByKey
});


$BookshelfViewSelectionCopyWith<$Res> get activeView;$BookshelfSelectionStateCopyWith<$Res> get selection;

}
/// @nodoc
class _$BookshelfPageStateCopyWithImpl<$Res>
    implements $BookshelfPageStateCopyWith<$Res> {
  _$BookshelfPageStateCopyWithImpl(this._self, this._then);

  final BookshelfPageState _self;
  final $Res Function(BookshelfPageState) _then;

/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? baseFilterOrder = null,Object? activeView = null,Object? sortMode = null,Object? selection = null,Object? cardStatesByKey = null,}) {
  return _then(_self.copyWith(
baseFilterOrder: null == baseFilterOrder ? _self.baseFilterOrder : baseFilterOrder // ignore: cast_nullable_to_non_nullable
as List<BookshelfFilter>,activeView: null == activeView ? _self.activeView : activeView // ignore: cast_nullable_to_non_nullable
as BookshelfViewSelection,sortMode: null == sortMode ? _self.sortMode : sortMode // ignore: cast_nullable_to_non_nullable
as BookshelfSortMode,selection: null == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as BookshelfSelectionState,cardStatesByKey: null == cardStatesByKey ? _self.cardStatesByKey : cardStatesByKey // ignore: cast_nullable_to_non_nullable
as Map<String, BookshelfBookCardState>,
  ));
}
/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookshelfViewSelectionCopyWith<$Res> get activeView {
  
  return $BookshelfViewSelectionCopyWith<$Res>(_self.activeView, (value) {
    return _then(_self.copyWith(activeView: value));
  });
}/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookshelfSelectionStateCopyWith<$Res> get selection {
  
  return $BookshelfSelectionStateCopyWith<$Res>(_self.selection, (value) {
    return _then(_self.copyWith(selection: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookshelfPageState].
extension BookshelfPageStatePatterns on BookshelfPageState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookshelfPageState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookshelfPageState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookshelfPageState value)  $default,){
final _that = this;
switch (_that) {
case _BookshelfPageState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookshelfPageState value)?  $default,){
final _that = this;
switch (_that) {
case _BookshelfPageState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<BookshelfFilter> baseFilterOrder,  BookshelfViewSelection activeView,  BookshelfSortMode sortMode,  BookshelfSelectionState selection,  Map<String, BookshelfBookCardState> cardStatesByKey)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookshelfPageState() when $default != null:
return $default(_that.baseFilterOrder,_that.activeView,_that.sortMode,_that.selection,_that.cardStatesByKey);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<BookshelfFilter> baseFilterOrder,  BookshelfViewSelection activeView,  BookshelfSortMode sortMode,  BookshelfSelectionState selection,  Map<String, BookshelfBookCardState> cardStatesByKey)  $default,) {final _that = this;
switch (_that) {
case _BookshelfPageState():
return $default(_that.baseFilterOrder,_that.activeView,_that.sortMode,_that.selection,_that.cardStatesByKey);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<BookshelfFilter> baseFilterOrder,  BookshelfViewSelection activeView,  BookshelfSortMode sortMode,  BookshelfSelectionState selection,  Map<String, BookshelfBookCardState> cardStatesByKey)?  $default,) {final _that = this;
switch (_that) {
case _BookshelfPageState() when $default != null:
return $default(_that.baseFilterOrder,_that.activeView,_that.sortMode,_that.selection,_that.cardStatesByKey);case _:
  return null;

}
}

}

/// @nodoc


class _BookshelfPageState implements BookshelfPageState {
  const _BookshelfPageState({final  List<BookshelfFilter> baseFilterOrder = BookshelfPageState.defaultBaseFilters, this.activeView = const BookshelfViewSelection.base(BookshelfFilter.all), this.sortMode = BookshelfSortMode.defaultOrder, this.selection = const BookshelfSelectionState(), final  Map<String, BookshelfBookCardState> cardStatesByKey = const <String, BookshelfBookCardState>{}}): _baseFilterOrder = baseFilterOrder,_cardStatesByKey = cardStatesByKey;
  

 final  List<BookshelfFilter> _baseFilterOrder;
@override@JsonKey() List<BookshelfFilter> get baseFilterOrder {
  if (_baseFilterOrder is EqualUnmodifiableListView) return _baseFilterOrder;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_baseFilterOrder);
}

@override@JsonKey() final  BookshelfViewSelection activeView;
@override@JsonKey() final  BookshelfSortMode sortMode;
@override@JsonKey() final  BookshelfSelectionState selection;
 final  Map<String, BookshelfBookCardState> _cardStatesByKey;
@override@JsonKey() Map<String, BookshelfBookCardState> get cardStatesByKey {
  if (_cardStatesByKey is EqualUnmodifiableMapView) return _cardStatesByKey;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_cardStatesByKey);
}


/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookshelfPageStateCopyWith<_BookshelfPageState> get copyWith => __$BookshelfPageStateCopyWithImpl<_BookshelfPageState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookshelfPageState&&const DeepCollectionEquality().equals(other._baseFilterOrder, _baseFilterOrder)&&(identical(other.activeView, activeView) || other.activeView == activeView)&&(identical(other.sortMode, sortMode) || other.sortMode == sortMode)&&(identical(other.selection, selection) || other.selection == selection)&&const DeepCollectionEquality().equals(other._cardStatesByKey, _cardStatesByKey));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_baseFilterOrder),activeView,sortMode,selection,const DeepCollectionEquality().hash(_cardStatesByKey));

@override
String toString() {
  return 'BookshelfPageState(baseFilterOrder: $baseFilterOrder, activeView: $activeView, sortMode: $sortMode, selection: $selection, cardStatesByKey: $cardStatesByKey)';
}


}

/// @nodoc
abstract mixin class _$BookshelfPageStateCopyWith<$Res> implements $BookshelfPageStateCopyWith<$Res> {
  factory _$BookshelfPageStateCopyWith(_BookshelfPageState value, $Res Function(_BookshelfPageState) _then) = __$BookshelfPageStateCopyWithImpl;
@override @useResult
$Res call({
 List<BookshelfFilter> baseFilterOrder, BookshelfViewSelection activeView, BookshelfSortMode sortMode, BookshelfSelectionState selection, Map<String, BookshelfBookCardState> cardStatesByKey
});


@override $BookshelfViewSelectionCopyWith<$Res> get activeView;@override $BookshelfSelectionStateCopyWith<$Res> get selection;

}
/// @nodoc
class __$BookshelfPageStateCopyWithImpl<$Res>
    implements _$BookshelfPageStateCopyWith<$Res> {
  __$BookshelfPageStateCopyWithImpl(this._self, this._then);

  final _BookshelfPageState _self;
  final $Res Function(_BookshelfPageState) _then;

/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? baseFilterOrder = null,Object? activeView = null,Object? sortMode = null,Object? selection = null,Object? cardStatesByKey = null,}) {
  return _then(_BookshelfPageState(
baseFilterOrder: null == baseFilterOrder ? _self._baseFilterOrder : baseFilterOrder // ignore: cast_nullable_to_non_nullable
as List<BookshelfFilter>,activeView: null == activeView ? _self.activeView : activeView // ignore: cast_nullable_to_non_nullable
as BookshelfViewSelection,sortMode: null == sortMode ? _self.sortMode : sortMode // ignore: cast_nullable_to_non_nullable
as BookshelfSortMode,selection: null == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as BookshelfSelectionState,cardStatesByKey: null == cardStatesByKey ? _self._cardStatesByKey : cardStatesByKey // ignore: cast_nullable_to_non_nullable
as Map<String, BookshelfBookCardState>,
  ));
}

/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookshelfViewSelectionCopyWith<$Res> get activeView {
  
  return $BookshelfViewSelectionCopyWith<$Res>(_self.activeView, (value) {
    return _then(_self.copyWith(activeView: value));
  });
}/// Create a copy of BookshelfPageState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookshelfSelectionStateCopyWith<$Res> get selection {
  
  return $BookshelfSelectionStateCopyWith<$Res>(_self.selection, (value) {
    return _then(_self.copyWith(selection: value));
  });
}
}

// dart format on
