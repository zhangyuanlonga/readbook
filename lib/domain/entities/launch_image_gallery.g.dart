// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'launch_image_gallery.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LaunchImageGallery _$LaunchImageGalleryFromJson(Map<String, dynamic> json) =>
    LaunchImageGallery(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      imagePaths:
          (json['imagePaths'] as List<dynamic>)
              .map((e) => e as String)
              .toList(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isEditable: json['isEditable'] as bool? ?? true,
      isDeletable: json['isDeletable'] as bool? ?? true,
    );

Map<String, dynamic> _$LaunchImageGalleryToJson(LaunchImageGallery instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'imagePaths': instance.imagePaths,
      'isBuiltIn': instance.isBuiltIn,
      'isEditable': instance.isEditable,
      'isDeletable': instance.isDeletable,
    };
