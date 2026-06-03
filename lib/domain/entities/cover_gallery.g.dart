// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cover_gallery.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CoverGallery _$CoverGalleryFromJson(Map<String, dynamic> json) => CoverGallery(
  id: json['id'] as String,
  name: json['name'] as String,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  imagePaths:
      (json['imagePaths'] as List<dynamic>).map((e) => e as String).toList(),
);

Map<String, dynamic> _$CoverGalleryToJson(CoverGallery instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'imagePaths': instance.imagePaths,
    };
