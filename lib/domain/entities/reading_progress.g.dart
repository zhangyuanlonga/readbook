// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReaderPositionSnapshot _$ReaderPositionSnapshotFromJson(
  Map<String, dynamic> json,
) => ReaderPositionSnapshot(
  viewportMode: json['viewportMode'] as String,
  pageIndex: (json['pageIndex'] as num?)?.toInt(),
  pageCount: (json['pageCount'] as num?)?.toInt(),
  scrollOffset: (json['scrollOffset'] as num?)?.toDouble(),
  maxScrollExtent: (json['maxScrollExtent'] as num?)?.toDouble(),
  zoomScale: (json['zoomScale'] as num?)?.toDouble(),
  panDx: (json['panDx'] as num?)?.toDouble(),
  panDy: (json['panDy'] as num?)?.toDouble(),
  audioPositionMs: (json['audioPositionMs'] as num?)?.toInt(),
  audioDurationMs: (json['audioDurationMs'] as num?)?.toInt(),
  audioSpeed: (json['audioSpeed'] as num?)?.toDouble(),
);

Map<String, dynamic> _$ReaderPositionSnapshotToJson(
  ReaderPositionSnapshot instance,
) => <String, dynamic>{
  'viewportMode': instance.viewportMode,
  'pageIndex': instance.pageIndex,
  'pageCount': instance.pageCount,
  'scrollOffset': instance.scrollOffset,
  'maxScrollExtent': instance.maxScrollExtent,
  'zoomScale': instance.zoomScale,
  'panDx': instance.panDx,
  'panDy': instance.panDy,
  'audioPositionMs': instance.audioPositionMs,
  'audioDurationMs': instance.audioDurationMs,
  'audioSpeed': instance.audioSpeed,
};

ReadingProgress _$ReadingProgressFromJson(Map<String, dynamic> json) =>
    ReadingProgress(
      bookId: json['bookId'] as String,
      sourceId: json['sourceId'] as String,
      detailUrl: json['detailUrl'] as String,
      chapterId: json['chapterId'] as String,
      chapterUrl: json['chapterUrl'] as String,
      chapterTitle: json['chapterTitle'] as String,
      chapterIndex: (json['chapterIndex'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      chapterPositionRatio:
          (json['chapterPositionRatio'] as num?)?.toDouble() ?? 0,
      logicalPosition:
          json['logicalPosition'] == null
              ? null
              : ReaderLogicalPosition.fromJson(
                json['logicalPosition'] as Map<String, dynamic>,
              ),
      positionSnapshot:
          json['positionSnapshot'] == null
              ? null
              : ReaderPositionSnapshot.fromJson(
                json['positionSnapshot'] as Map<String, dynamic>,
              ),
    );

Map<String, dynamic> _$ReadingProgressToJson(ReadingProgress instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'sourceId': instance.sourceId,
      'detailUrl': instance.detailUrl,
      'chapterId': instance.chapterId,
      'chapterUrl': instance.chapterUrl,
      'chapterTitle': instance.chapterTitle,
      'chapterIndex': instance.chapterIndex,
      'updatedAt': instance.updatedAt.toIso8601String(),
      'chapterPositionRatio': instance.chapterPositionRatio,
      'logicalPosition': instance.logicalPosition?.toJson(),
      'positionSnapshot': instance.positionSnapshot?.toJson(),
    };
