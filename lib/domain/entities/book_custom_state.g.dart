// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_custom_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookCustomState _$BookCustomStateFromJson(Map<String, dynamic> json) =>
    BookCustomState(
      bookId: json['bookId'] as String,
      sourceId: json['sourceId'] as String,
      detailUrl: json['detailUrl'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      customVariableJson: json['customVariableJson'] as String?,
    );

Map<String, dynamic> _$BookCustomStateToJson(BookCustomState instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'sourceId': instance.sourceId,
      'detailUrl': instance.detailUrl,
      'customVariableJson': instance.customVariableJson,
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
