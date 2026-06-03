// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chapter.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Chapter _$ChapterFromJson(Map<String, dynamic> json) => Chapter(
  id: Chapter._requiredId(json['id']),
  bookId: Chapter._requiredBookId(json['bookId']),
  title: Chapter._requiredTitle(json['title']),
  chapterUrl: Chapter._stringAllowEmpty(json['chapterUrl']),
  index: Chapter._requiredIndex(json['index']),
  isVolume: json['isVolume'] as bool? ?? false,
  executionContext: Chapter._optionalString(json['executionContext']),
);

Map<String, dynamic> _$ChapterToJson(Chapter instance) => <String, dynamic>{
  'id': instance.id,
  'bookId': instance.bookId,
  'title': instance.title,
  'chapterUrl': instance.chapterUrl,
  'index': instance.index,
  'isVolume': instance.isVolume,
  'executionContext': instance.executionContext,
};
