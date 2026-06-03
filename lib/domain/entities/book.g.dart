// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Book _$BookFromJson(Map<String, dynamic> json) => Book(
  id: json['id'] as String,
  sourceId: json['sourceId'] as String,
  title: json['title'] as String,
  detailUrl: json['detailUrl'] as String,
  tocUrl: json['tocUrl'] as String?,
  author: json['author'] as String?,
  intro: json['intro'] as String?,
  coverUrl: json['coverUrl'] as String?,
  latestChapter: json['latestChapter'] as String?,
  wordCount: json['wordCount'] as String?,
  category: json['category'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  updateTime: json['updateTime'] as String?,
  infoHtml: json['infoHtml'] as String?,
  tocHtml: json['tocHtml'] as String?,
  executionContext: json['executionContext'] as String?,
);

Map<String, dynamic> _$BookToJson(Book instance) => <String, dynamic>{
  'id': instance.id,
  'sourceId': instance.sourceId,
  'title': instance.title,
  'detailUrl': instance.detailUrl,
  'tocUrl': instance.tocUrl,
  'author': instance.author,
  'intro': instance.intro,
  'coverUrl': instance.coverUrl,
  'latestChapter': instance.latestChapter,
  'wordCount': instance.wordCount,
  'category': instance.category,
  'tags': instance.tags,
  'updateTime': instance.updateTime,
  'infoHtml': instance.infoHtml,
  'tocHtml': instance.tocHtml,
  'executionContext': instance.executionContext,
};
