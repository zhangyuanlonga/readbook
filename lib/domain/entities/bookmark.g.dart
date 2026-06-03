// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookmark.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Map<String, dynamic> _$BookmarkToJson(Bookmark instance) => <String, dynamic>{
  'id': instance.id,
  'bookId': instance.bookId,
  'chapterId': instance.chapterId,
  'chapterIndex': instance.chapterIndex,
  'startOffset': instance.startOffset,
  'endOffset': instance.endOffset,
  'snippet': instance.snippet,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'isBold': instance.isBold,
  'isUnderline': instance.isUnderline,
  'isWavy': instance.isWavy,
  'color': instance.color,
  'note': instance.noteText,
};
