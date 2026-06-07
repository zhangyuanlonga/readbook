// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gallery_index_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CoverGalleryIndexItem _$CoverGalleryIndexItemFromJson(
  Map<String, dynamic> json,
) => _CoverGalleryIndexItem(
  id: json['id'] as String,
  name: json['name'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  imageCount: (json['imageCount'] as num).toInt(),
  previewPath: json['previewPath'] as String?,
);

Map<String, dynamic> _$CoverGalleryIndexItemToJson(
  _CoverGalleryIndexItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'imageCount': instance.imageCount,
  'previewPath': instance.previewPath,
};

_LaunchImageGalleryIndexItem _$LaunchImageGalleryIndexItemFromJson(
  Map<String, dynamic> json,
) => _LaunchImageGalleryIndexItem(
  id: json['id'] as String,
  name: json['name'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  imageCount: (json['imageCount'] as num).toInt(),
  isBuiltIn: json['isBuiltIn'] as bool,
  isEditable: json['isEditable'] as bool,
  isDeletable: json['isDeletable'] as bool,
  previewPath: json['previewPath'] as String?,
);

Map<String, dynamic> _$LaunchImageGalleryIndexItemToJson(
  _LaunchImageGalleryIndexItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'imageCount': instance.imageCount,
  'isBuiltIn': instance.isBuiltIn,
  'isEditable': instance.isEditable,
  'isDeletable': instance.isDeletable,
  'previewPath': instance.previewPath,
};

_BottomNavIconGalleryIndexItem _$BottomNavIconGalleryIndexItemFromJson(
  Map<String, dynamic> json,
) => _BottomNavIconGalleryIndexItem(
  id: json['id'] as String,
  name: json['name'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isBuiltIn: json['isBuiltIn'] as bool,
  isEditable: json['isEditable'] as bool,
  isDeletable: json['isDeletable'] as bool,
  previewItems: _bottomNavPreviewItemsFromJson(json['previewItems']),
);

Map<String, dynamic> _$BottomNavIconGalleryIndexItemToJson(
  _BottomNavIconGalleryIndexItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isBuiltIn': instance.isBuiltIn,
  'isEditable': instance.isEditable,
  'isDeletable': instance.isDeletable,
  'previewItems': _bottomNavPreviewItemsToJson(instance.previewItems),
};
