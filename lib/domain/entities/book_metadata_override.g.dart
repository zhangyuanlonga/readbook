// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_metadata_override.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookMetadataOverride _$BookMetadataOverrideFromJson(
  Map<String, dynamic> json,
) => BookMetadataOverride(
  targetKey: json['targetKey'] as String,
  bookId: json['bookId'] as String?,
  sourceId: json['sourceId'] as String?,
  detailUrl: json['detailUrl'] as String?,
  title: json['title'] as String?,
  author: json['author'] as String?,
  intro: json['intro'] as String?,
  coverPath: json['coverPath'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$BookMetadataOverrideToJson(
  BookMetadataOverride instance,
) => <String, dynamic>{
  'targetKey': instance.targetKey,
  'bookId': instance.bookId,
  'sourceId': instance.sourceId,
  'detailUrl': instance.detailUrl,
  'title': instance.title,
  'author': instance.author,
  'intro': instance.intro,
  'coverPath': instance.coverPath,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
};
