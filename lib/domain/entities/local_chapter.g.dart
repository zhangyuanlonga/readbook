// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalChapter _$LocalChapterFromJson(Map<String, dynamic> json) => LocalChapter(
  id: json['id'] as String,
  bookId: json['bookId'] as String,
  chapterIndex: (json['chapterIndex'] as num).toInt(),
  title: json['title'] as String,
  content: json['content'] as String,
  imageUrls:
      (json['imageUrls'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  sourceRef: json['sourceRef'] as String?,
  contentType: json['contentType'] as String?,
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  startOffset: (json['startOffset'] as num?)?.toInt(),
  endOffset: (json['endOffset'] as num?)?.toInt(),
  document:
      json['document'] == null
          ? null
          : ReaderDocument.fromJson(json['document'] as Map<String, dynamic>),
);

Map<String, dynamic> _$LocalChapterToJson(LocalChapter instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookId': instance.bookId,
      'chapterIndex': instance.chapterIndex,
      'title': instance.title,
      'content': instance.content,
      'imageUrls': instance.imageUrls,
      'sourceRef': instance.sourceRef,
      'contentType': instance.contentType,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'startOffset': instance.startOffset,
      'endOffset': instance.endOffset,
      'document': instance.document?.toJson(),
    };
