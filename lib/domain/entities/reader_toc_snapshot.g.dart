// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_toc_snapshot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReaderTocSnapshot _$ReaderTocSnapshotFromJson(Map<String, dynamic> json) =>
    ReaderTocSnapshot(
      bookId: ReaderTocSnapshot._requiredBookId(json['bookId']),
      sourceId: ReaderTocSnapshot._requiredSourceId(json['sourceId']),
      detailUrl: ReaderTocSnapshot._requiredDetailUrl(json['detailUrl']),
      title: ReaderTocSnapshot._requiredTitle(json['title']),
      author: ReaderTocSnapshot._optionalString(json['author']),
      coverUrl: ReaderTocSnapshot._optionalString(json['coverUrl']),
      chapters: ReaderTocSnapshot._chaptersFromJson(json['chapters']),
      updatedAt: ReaderTocSnapshot._requiredDateTimeFromJson(json['updatedAt']),
    );

Map<String, dynamic> _$ReaderTocSnapshotToJson(ReaderTocSnapshot instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'sourceId': instance.sourceId,
      'detailUrl': instance.detailUrl,
      'title': instance.title,
      'author': instance.author,
      'coverUrl': instance.coverUrl,
      'chapters': instance.chapters.map((e) => e.toJson()).toList(),
      'updatedAt': ReaderTocSnapshot._dateTimeToJson(instance.updatedAt),
    };
