// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_logical_position.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReaderLogicalPosition _$ReaderLogicalPositionFromJson(
  Map<String, dynamic> json,
) => ReaderLogicalPosition(
  chapterIndex: (json['chapterIndex'] as num).toInt(),
  blockIndex: (json['blockIndex'] as num).toInt(),
  offsetInBlock: (json['offsetInBlock'] as num).toInt(),
  chapterPositionRatio: (json['chapterPositionRatio'] as num).toDouble(),
  pageIndex: (json['pageIndex'] as num?)?.toInt(),
  totalPageCount: (json['totalPageCount'] as num?)?.toInt(),
  viewportMode: json['viewportMode'] as String?,
  zoomScale: (json['zoomScale'] as num?)?.toDouble(),
  panDx: (json['panDx'] as num?)?.toDouble(),
  panDy: (json['panDy'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ReaderLogicalPositionToJson(
  ReaderLogicalPosition instance,
) => <String, dynamic>{
  'chapterIndex': instance.chapterIndex,
  'blockIndex': instance.blockIndex,
  'offsetInBlock': instance.offsetInBlock,
  'chapterPositionRatio': instance.chapterPositionRatio,
  'pageIndex': instance.pageIndex,
  'totalPageCount': instance.totalPageCount,
  'viewportMode': instance.viewportMode,
  'zoomScale': instance.zoomScale,
  'panDx': instance.panDx,
  'panDy': instance.panDy,
};
