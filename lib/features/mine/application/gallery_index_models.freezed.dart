// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gallery_index_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CoverGalleryIndexItem {

 String get id; String get name; DateTime get updatedAt; int get imageCount; String? get previewPath;
/// Create a copy of CoverGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoverGalleryIndexItemCopyWith<CoverGalleryIndexItem> get copyWith => _$CoverGalleryIndexItemCopyWithImpl<CoverGalleryIndexItem>(this as CoverGalleryIndexItem, _$identity);

  /// Serializes this CoverGalleryIndexItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoverGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.previewPath, previewPath) || other.previewPath == previewPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,imageCount,previewPath);

@override
String toString() {
  return 'CoverGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, imageCount: $imageCount, previewPath: $previewPath)';
}


}

/// @nodoc
abstract mixin class $CoverGalleryIndexItemCopyWith<$Res>  {
  factory $CoverGalleryIndexItemCopyWith(CoverGalleryIndexItem value, $Res Function(CoverGalleryIndexItem) _then) = _$CoverGalleryIndexItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime updatedAt, int imageCount, String? previewPath
});




}
/// @nodoc
class _$CoverGalleryIndexItemCopyWithImpl<$Res>
    implements $CoverGalleryIndexItemCopyWith<$Res> {
  _$CoverGalleryIndexItemCopyWithImpl(this._self, this._then);

  final CoverGalleryIndexItem _self;
  final $Res Function(CoverGalleryIndexItem) _then;

/// Create a copy of CoverGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? imageCount = null,Object? previewPath = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,previewPath: freezed == previewPath ? _self.previewPath : previewPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CoverGalleryIndexItem].
extension CoverGalleryIndexItemPatterns on CoverGalleryIndexItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoverGalleryIndexItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoverGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoverGalleryIndexItem value)  $default,){
final _that = this;
switch (_that) {
case _CoverGalleryIndexItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoverGalleryIndexItem value)?  $default,){
final _that = this;
switch (_that) {
case _CoverGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  int imageCount,  String? previewPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoverGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.previewPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  int imageCount,  String? previewPath)  $default,) {final _that = this;
switch (_that) {
case _CoverGalleryIndexItem():
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.previewPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime updatedAt,  int imageCount,  String? previewPath)?  $default,) {final _that = this;
switch (_that) {
case _CoverGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.previewPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CoverGalleryIndexItem implements CoverGalleryIndexItem {
  const _CoverGalleryIndexItem({required this.id, required this.name, required this.updatedAt, required this.imageCount, this.previewPath});
  factory _CoverGalleryIndexItem.fromJson(Map<String, dynamic> json) => _$CoverGalleryIndexItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime updatedAt;
@override final  int imageCount;
@override final  String? previewPath;

/// Create a copy of CoverGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoverGalleryIndexItemCopyWith<_CoverGalleryIndexItem> get copyWith => __$CoverGalleryIndexItemCopyWithImpl<_CoverGalleryIndexItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CoverGalleryIndexItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoverGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.previewPath, previewPath) || other.previewPath == previewPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,imageCount,previewPath);

@override
String toString() {
  return 'CoverGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, imageCount: $imageCount, previewPath: $previewPath)';
}


}

/// @nodoc
abstract mixin class _$CoverGalleryIndexItemCopyWith<$Res> implements $CoverGalleryIndexItemCopyWith<$Res> {
  factory _$CoverGalleryIndexItemCopyWith(_CoverGalleryIndexItem value, $Res Function(_CoverGalleryIndexItem) _then) = __$CoverGalleryIndexItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime updatedAt, int imageCount, String? previewPath
});




}
/// @nodoc
class __$CoverGalleryIndexItemCopyWithImpl<$Res>
    implements _$CoverGalleryIndexItemCopyWith<$Res> {
  __$CoverGalleryIndexItemCopyWithImpl(this._self, this._then);

  final _CoverGalleryIndexItem _self;
  final $Res Function(_CoverGalleryIndexItem) _then;

/// Create a copy of CoverGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? imageCount = null,Object? previewPath = freezed,}) {
  return _then(_CoverGalleryIndexItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,previewPath: freezed == previewPath ? _self.previewPath : previewPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$LaunchImageGalleryIndexItem {

 String get id; String get name; DateTime get updatedAt; int get imageCount; bool get isBuiltIn; bool get isEditable; bool get isDeletable; String? get previewPath;
/// Create a copy of LaunchImageGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LaunchImageGalleryIndexItemCopyWith<LaunchImageGalleryIndexItem> get copyWith => _$LaunchImageGalleryIndexItemCopyWithImpl<LaunchImageGalleryIndexItem>(this as LaunchImageGalleryIndexItem, _$identity);

  /// Serializes this LaunchImageGalleryIndexItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LaunchImageGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.isEditable, isEditable) || other.isEditable == isEditable)&&(identical(other.isDeletable, isDeletable) || other.isDeletable == isDeletable)&&(identical(other.previewPath, previewPath) || other.previewPath == previewPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,imageCount,isBuiltIn,isEditable,isDeletable,previewPath);

@override
String toString() {
  return 'LaunchImageGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, imageCount: $imageCount, isBuiltIn: $isBuiltIn, isEditable: $isEditable, isDeletable: $isDeletable, previewPath: $previewPath)';
}


}

/// @nodoc
abstract mixin class $LaunchImageGalleryIndexItemCopyWith<$Res>  {
  factory $LaunchImageGalleryIndexItemCopyWith(LaunchImageGalleryIndexItem value, $Res Function(LaunchImageGalleryIndexItem) _then) = _$LaunchImageGalleryIndexItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime updatedAt, int imageCount, bool isBuiltIn, bool isEditable, bool isDeletable, String? previewPath
});




}
/// @nodoc
class _$LaunchImageGalleryIndexItemCopyWithImpl<$Res>
    implements $LaunchImageGalleryIndexItemCopyWith<$Res> {
  _$LaunchImageGalleryIndexItemCopyWithImpl(this._self, this._then);

  final LaunchImageGalleryIndexItem _self;
  final $Res Function(LaunchImageGalleryIndexItem) _then;

/// Create a copy of LaunchImageGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? imageCount = null,Object? isBuiltIn = null,Object? isEditable = null,Object? isDeletable = null,Object? previewPath = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,isEditable: null == isEditable ? _self.isEditable : isEditable // ignore: cast_nullable_to_non_nullable
as bool,isDeletable: null == isDeletable ? _self.isDeletable : isDeletable // ignore: cast_nullable_to_non_nullable
as bool,previewPath: freezed == previewPath ? _self.previewPath : previewPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LaunchImageGalleryIndexItem].
extension LaunchImageGalleryIndexItemPatterns on LaunchImageGalleryIndexItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LaunchImageGalleryIndexItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LaunchImageGalleryIndexItem value)  $default,){
final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LaunchImageGalleryIndexItem value)?  $default,){
final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  int imageCount,  bool isBuiltIn,  bool isEditable,  bool isDeletable,  String? previewPath)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewPath);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  int imageCount,  bool isBuiltIn,  bool isEditable,  bool isDeletable,  String? previewPath)  $default,) {final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem():
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewPath);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime updatedAt,  int imageCount,  bool isBuiltIn,  bool isEditable,  bool isDeletable,  String? previewPath)?  $default,) {final _that = this;
switch (_that) {
case _LaunchImageGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.imageCount,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewPath);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LaunchImageGalleryIndexItem implements LaunchImageGalleryIndexItem {
  const _LaunchImageGalleryIndexItem({required this.id, required this.name, required this.updatedAt, required this.imageCount, required this.isBuiltIn, required this.isEditable, required this.isDeletable, this.previewPath});
  factory _LaunchImageGalleryIndexItem.fromJson(Map<String, dynamic> json) => _$LaunchImageGalleryIndexItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime updatedAt;
@override final  int imageCount;
@override final  bool isBuiltIn;
@override final  bool isEditable;
@override final  bool isDeletable;
@override final  String? previewPath;

/// Create a copy of LaunchImageGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LaunchImageGalleryIndexItemCopyWith<_LaunchImageGalleryIndexItem> get copyWith => __$LaunchImageGalleryIndexItemCopyWithImpl<_LaunchImageGalleryIndexItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LaunchImageGalleryIndexItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LaunchImageGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.imageCount, imageCount) || other.imageCount == imageCount)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.isEditable, isEditable) || other.isEditable == isEditable)&&(identical(other.isDeletable, isDeletable) || other.isDeletable == isDeletable)&&(identical(other.previewPath, previewPath) || other.previewPath == previewPath));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,imageCount,isBuiltIn,isEditable,isDeletable,previewPath);

@override
String toString() {
  return 'LaunchImageGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, imageCount: $imageCount, isBuiltIn: $isBuiltIn, isEditable: $isEditable, isDeletable: $isDeletable, previewPath: $previewPath)';
}


}

/// @nodoc
abstract mixin class _$LaunchImageGalleryIndexItemCopyWith<$Res> implements $LaunchImageGalleryIndexItemCopyWith<$Res> {
  factory _$LaunchImageGalleryIndexItemCopyWith(_LaunchImageGalleryIndexItem value, $Res Function(_LaunchImageGalleryIndexItem) _then) = __$LaunchImageGalleryIndexItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime updatedAt, int imageCount, bool isBuiltIn, bool isEditable, bool isDeletable, String? previewPath
});




}
/// @nodoc
class __$LaunchImageGalleryIndexItemCopyWithImpl<$Res>
    implements _$LaunchImageGalleryIndexItemCopyWith<$Res> {
  __$LaunchImageGalleryIndexItemCopyWithImpl(this._self, this._then);

  final _LaunchImageGalleryIndexItem _self;
  final $Res Function(_LaunchImageGalleryIndexItem) _then;

/// Create a copy of LaunchImageGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? imageCount = null,Object? isBuiltIn = null,Object? isEditable = null,Object? isDeletable = null,Object? previewPath = freezed,}) {
  return _then(_LaunchImageGalleryIndexItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,imageCount: null == imageCount ? _self.imageCount : imageCount // ignore: cast_nullable_to_non_nullable
as int,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,isEditable: null == isEditable ? _self.isEditable : isEditable // ignore: cast_nullable_to_non_nullable
as bool,isDeletable: null == isDeletable ? _self.isDeletable : isDeletable // ignore: cast_nullable_to_non_nullable
as bool,previewPath: freezed == previewPath ? _self.previewPath : previewPath // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$BottomNavIconGalleryIndexItem {

 String get id; String get name; DateTime get updatedAt; bool get isBuiltIn; bool get isEditable; bool get isDeletable;@JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson) Map<BottomNavIconGalleryTab, BottomNavIconSet> get previewItems;
/// Create a copy of BottomNavIconGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BottomNavIconGalleryIndexItemCopyWith<BottomNavIconGalleryIndexItem> get copyWith => _$BottomNavIconGalleryIndexItemCopyWithImpl<BottomNavIconGalleryIndexItem>(this as BottomNavIconGalleryIndexItem, _$identity);

  /// Serializes this BottomNavIconGalleryIndexItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BottomNavIconGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.isEditable, isEditable) || other.isEditable == isEditable)&&(identical(other.isDeletable, isDeletable) || other.isDeletable == isDeletable)&&const DeepCollectionEquality().equals(other.previewItems, previewItems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,isBuiltIn,isEditable,isDeletable,const DeepCollectionEquality().hash(previewItems));

@override
String toString() {
  return 'BottomNavIconGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, isBuiltIn: $isBuiltIn, isEditable: $isEditable, isDeletable: $isDeletable, previewItems: $previewItems)';
}


}

/// @nodoc
abstract mixin class $BottomNavIconGalleryIndexItemCopyWith<$Res>  {
  factory $BottomNavIconGalleryIndexItemCopyWith(BottomNavIconGalleryIndexItem value, $Res Function(BottomNavIconGalleryIndexItem) _then) = _$BottomNavIconGalleryIndexItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime updatedAt, bool isBuiltIn, bool isEditable, bool isDeletable,@JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson) Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems
});




}
/// @nodoc
class _$BottomNavIconGalleryIndexItemCopyWithImpl<$Res>
    implements $BottomNavIconGalleryIndexItemCopyWith<$Res> {
  _$BottomNavIconGalleryIndexItemCopyWithImpl(this._self, this._then);

  final BottomNavIconGalleryIndexItem _self;
  final $Res Function(BottomNavIconGalleryIndexItem) _then;

/// Create a copy of BottomNavIconGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? isBuiltIn = null,Object? isEditable = null,Object? isDeletable = null,Object? previewItems = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,isEditable: null == isEditable ? _self.isEditable : isEditable // ignore: cast_nullable_to_non_nullable
as bool,isDeletable: null == isDeletable ? _self.isDeletable : isDeletable // ignore: cast_nullable_to_non_nullable
as bool,previewItems: null == previewItems ? _self.previewItems : previewItems // ignore: cast_nullable_to_non_nullable
as Map<BottomNavIconGalleryTab, BottomNavIconSet>,
  ));
}

}


/// Adds pattern-matching-related methods to [BottomNavIconGalleryIndexItem].
extension BottomNavIconGalleryIndexItemPatterns on BottomNavIconGalleryIndexItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BottomNavIconGalleryIndexItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BottomNavIconGalleryIndexItem value)  $default,){
final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BottomNavIconGalleryIndexItem value)?  $default,){
final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  bool isBuiltIn,  bool isEditable,  bool isDeletable, @JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson)  Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewItems);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime updatedAt,  bool isBuiltIn,  bool isEditable,  bool isDeletable, @JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson)  Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems)  $default,) {final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem():
return $default(_that.id,_that.name,_that.updatedAt,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewItems);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime updatedAt,  bool isBuiltIn,  bool isEditable,  bool isDeletable, @JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson)  Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems)?  $default,) {final _that = this;
switch (_that) {
case _BottomNavIconGalleryIndexItem() when $default != null:
return $default(_that.id,_that.name,_that.updatedAt,_that.isBuiltIn,_that.isEditable,_that.isDeletable,_that.previewItems);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BottomNavIconGalleryIndexItem implements BottomNavIconGalleryIndexItem {
  const _BottomNavIconGalleryIndexItem({required this.id, required this.name, required this.updatedAt, required this.isBuiltIn, required this.isEditable, required this.isDeletable, @JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson) required final  Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems}): _previewItems = previewItems;
  factory _BottomNavIconGalleryIndexItem.fromJson(Map<String, dynamic> json) => _$BottomNavIconGalleryIndexItemFromJson(json);

@override final  String id;
@override final  String name;
@override final  DateTime updatedAt;
@override final  bool isBuiltIn;
@override final  bool isEditable;
@override final  bool isDeletable;
 final  Map<BottomNavIconGalleryTab, BottomNavIconSet> _previewItems;
@override@JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson) Map<BottomNavIconGalleryTab, BottomNavIconSet> get previewItems {
  if (_previewItems is EqualUnmodifiableMapView) return _previewItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_previewItems);
}


/// Create a copy of BottomNavIconGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BottomNavIconGalleryIndexItemCopyWith<_BottomNavIconGalleryIndexItem> get copyWith => __$BottomNavIconGalleryIndexItemCopyWithImpl<_BottomNavIconGalleryIndexItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BottomNavIconGalleryIndexItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BottomNavIconGalleryIndexItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.isBuiltIn, isBuiltIn) || other.isBuiltIn == isBuiltIn)&&(identical(other.isEditable, isEditable) || other.isEditable == isEditable)&&(identical(other.isDeletable, isDeletable) || other.isDeletable == isDeletable)&&const DeepCollectionEquality().equals(other._previewItems, _previewItems));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,updatedAt,isBuiltIn,isEditable,isDeletable,const DeepCollectionEquality().hash(_previewItems));

@override
String toString() {
  return 'BottomNavIconGalleryIndexItem(id: $id, name: $name, updatedAt: $updatedAt, isBuiltIn: $isBuiltIn, isEditable: $isEditable, isDeletable: $isDeletable, previewItems: $previewItems)';
}


}

/// @nodoc
abstract mixin class _$BottomNavIconGalleryIndexItemCopyWith<$Res> implements $BottomNavIconGalleryIndexItemCopyWith<$Res> {
  factory _$BottomNavIconGalleryIndexItemCopyWith(_BottomNavIconGalleryIndexItem value, $Res Function(_BottomNavIconGalleryIndexItem) _then) = __$BottomNavIconGalleryIndexItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime updatedAt, bool isBuiltIn, bool isEditable, bool isDeletable,@JsonKey(fromJson: _bottomNavPreviewItemsFromJson, toJson: _bottomNavPreviewItemsToJson) Map<BottomNavIconGalleryTab, BottomNavIconSet> previewItems
});




}
/// @nodoc
class __$BottomNavIconGalleryIndexItemCopyWithImpl<$Res>
    implements _$BottomNavIconGalleryIndexItemCopyWith<$Res> {
  __$BottomNavIconGalleryIndexItemCopyWithImpl(this._self, this._then);

  final _BottomNavIconGalleryIndexItem _self;
  final $Res Function(_BottomNavIconGalleryIndexItem) _then;

/// Create a copy of BottomNavIconGalleryIndexItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? updatedAt = null,Object? isBuiltIn = null,Object? isEditable = null,Object? isDeletable = null,Object? previewItems = null,}) {
  return _then(_BottomNavIconGalleryIndexItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,isBuiltIn: null == isBuiltIn ? _self.isBuiltIn : isBuiltIn // ignore: cast_nullable_to_non_nullable
as bool,isEditable: null == isEditable ? _self.isEditable : isEditable // ignore: cast_nullable_to_non_nullable
as bool,isDeletable: null == isDeletable ? _self.isDeletable : isDeletable // ignore: cast_nullable_to_non_nullable
as bool,previewItems: null == previewItems ? _self._previewItems : previewItems // ignore: cast_nullable_to_non_nullable
as Map<BottomNavIconGalleryTab, BottomNavIconSet>,
  ));
}


}

// dart format on
