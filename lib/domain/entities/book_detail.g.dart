// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookDetail _$BookDetailFromJson(Map<String, dynamic> json) => BookDetail(
  id: BookDetail._requiredDetailId(json['id']),
  sourceId: BookDetail._requiredSourceId(json['sourceId']),
  title: BookDetail._requiredTitle(json['title']),
  detailUrl: BookDetail._requiredDetailUrl(json['detailUrl']),
  author: BookDetail._optionalString(json['author']),
  intro: BookDetail._optionalString(json['intro']),
  coverUrl: BookDetail._optionalString(json['coverUrl']),
  tocUrl: BookDetail._optionalString(json['tocUrl']),
  latestChapterTitle: BookDetail._optionalString(json['latestChapterTitle']),
  totalChapterNum: BookDetail._optionalInt(json['totalChapterNum']),
  wordCount: BookDetail._optionalString(json['wordCount']),
  category: BookDetail._optionalString(json['category']),
  tags:
      json['tags'] == null
          ? const <String>[]
          : BookDetail._stringList(json['tags']),
  updateTime: BookDetail._optionalString(json['updateTime']),
  executionContext: BookDetail._optionalString(json['executionContext']),
);

Map<String, dynamic> _$BookDetailToJson(BookDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sourceId': instance.sourceId,
      'title': instance.title,
      'detailUrl': instance.detailUrl,
      'author': instance.author,
      'intro': instance.intro,
      'coverUrl': instance.coverUrl,
      'tocUrl': instance.tocUrl,
      'latestChapterTitle': instance.latestChapterTitle,
      'totalChapterNum': instance.totalChapterNum,
      'wordCount': instance.wordCount,
      'category': instance.category,
      'tags': instance.tags,
      'updateTime': instance.updateTime,
      'executionContext': instance.executionContext,
    };
