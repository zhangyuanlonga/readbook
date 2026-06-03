// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_pagination_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReaderPagedSlice _$ReaderPagedSliceFromJson(Map<String, dynamic> json) =>
    ReaderPagedSlice(
      paragraphIndex: (json['paragraphIndex'] as num?)?.toInt() ?? 0,
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$ReaderPagedSliceToJson(ReaderPagedSlice instance) =>
    <String, dynamic>{
      'paragraphIndex': instance.paragraphIndex,
      'start': instance.start,
      'end': instance.end,
      'height': instance.height,
    };
