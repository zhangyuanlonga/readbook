// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bottom_nav_icon_gallery.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BottomNavIconAssetRef _$BottomNavIconAssetRefFromJson(
  Map<String, dynamic> json,
) => BottomNavIconAssetRef(
  path: json['path'] as String,
  format: $enumDecode(_$BottomNavIconAssetFormatEnumMap, json['format']),
  isAsset: json['isAsset'] as bool,
);

Map<String, dynamic> _$BottomNavIconAssetRefToJson(
  BottomNavIconAssetRef instance,
) => <String, dynamic>{
  'path': instance.path,
  'format': _$BottomNavIconAssetFormatEnumMap[instance.format]!,
  'isAsset': instance.isAsset,
};

const _$BottomNavIconAssetFormatEnumMap = {
  BottomNavIconAssetFormat.svg: 'svg',
  BottomNavIconAssetFormat.png: 'png',
  BottomNavIconAssetFormat.gif: 'gif',
};

BottomNavIconSet _$BottomNavIconSetFromJson(Map<String, dynamic> json) =>
    BottomNavIconSet(
      lightUnselected:
          json['lightUnselected'] == null
              ? null
              : BottomNavIconAssetRef.fromJson(
                json['lightUnselected'] as Map<String, dynamic>,
              ),
      lightSelected:
          json['lightSelected'] == null
              ? null
              : BottomNavIconAssetRef.fromJson(
                json['lightSelected'] as Map<String, dynamic>,
              ),
      darkUnselected:
          json['darkUnselected'] == null
              ? null
              : BottomNavIconAssetRef.fromJson(
                json['darkUnselected'] as Map<String, dynamic>,
              ),
      darkSelected:
          json['darkSelected'] == null
              ? null
              : BottomNavIconAssetRef.fromJson(
                json['darkSelected'] as Map<String, dynamic>,
              ),
    );

Map<String, dynamic> _$BottomNavIconSetToJson(BottomNavIconSet instance) =>
    <String, dynamic>{
      'lightUnselected': instance.lightUnselected?.toJson(),
      'lightSelected': instance.lightSelected?.toJson(),
      'darkUnselected': instance.darkUnselected?.toJson(),
      'darkSelected': instance.darkSelected?.toJson(),
    };

BottomNavIconGallery _$BottomNavIconGalleryFromJson(
  Map<String, dynamic> json,
) => BottomNavIconGallery(
  id: json['id'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  isBuiltIn: json['isBuiltIn'] as bool,
  isEditable: json['isEditable'] as bool,
  isDeletable: json['isDeletable'] as bool,
  items: BottomNavIconGallery._itemsFromJson(json['items']),
);

Map<String, dynamic> _$BottomNavIconGalleryToJson(
  BottomNavIconGallery instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isBuiltIn': instance.isBuiltIn,
  'isEditable': instance.isEditable,
  'isDeletable': instance.isDeletable,
  'items': BottomNavIconGallery._itemsToJson(instance.items),
};
