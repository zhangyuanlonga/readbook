// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalBook _$LocalBookFromJson(Map<String, dynamic> json) => LocalBook(
  id: json['id'] as String,
  title: json['title'] as String,
  format: $enumDecode(_$LocalBookFormatEnumMap, json['format']),
  storagePath: json['storagePath'] as String,
  fileSize: (json['fileSize'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  sourcePath: json['sourcePath'] as String?,
  charset: json['charset'] as String?,
  author: json['author'] as String?,
  description: json['description'] as String?,
  coverPath: json['coverPath'] as String?,
  sourceFileSize: (json['sourceFileSize'] as num?)?.toInt(),
  sourceFileLastModifiedMs: (json['sourceFileLastModifiedMs'] as num?)?.toInt(),
  storageFileLastModifiedMs:
      (json['storageFileLastModifiedMs'] as num?)?.toInt(),
  indexStatus:
      $enumDecodeNullable(_$LocalBookIndexStatusEnumMap, json['indexStatus']) ??
      LocalBookIndexStatus.pending,
  chapterCount: (json['chapterCount'] as num?)?.toInt() ?? 0,
  lastError: json['lastError'] as String?,
  splitLongChapter: json['splitLongChapter'] as bool? ?? true,
);

Map<String, dynamic> _$LocalBookToJson(LocalBook instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'format': _$LocalBookFormatEnumMap[instance.format]!,
  'storagePath': instance.storagePath,
  'fileSize': instance.fileSize,
  'createdAt': instance.createdAt.toIso8601String(),
  'updatedAt': instance.updatedAt.toIso8601String(),
  'sourcePath': instance.sourcePath,
  'charset': instance.charset,
  'author': instance.author,
  'description': instance.description,
  'coverPath': instance.coverPath,
  'sourceFileSize': instance.sourceFileSize,
  'sourceFileLastModifiedMs': instance.sourceFileLastModifiedMs,
  'storageFileLastModifiedMs': instance.storageFileLastModifiedMs,
  'indexStatus': _$LocalBookIndexStatusEnumMap[instance.indexStatus]!,
  'chapterCount': instance.chapterCount,
  'lastError': instance.lastError,
  'splitLongChapter': instance.splitLongChapter,
};

const _$LocalBookFormatEnumMap = {
  LocalBookFormat.txt: 'txt',
  LocalBookFormat.epub: 'epub',
  LocalBookFormat.md: 'md',
  LocalBookFormat.html: 'html',
  LocalBookFormat.pdf: 'pdf',
  LocalBookFormat.mobi: 'mobi',
  LocalBookFormat.azw: 'azw',
  LocalBookFormat.azw3: 'azw3',
};

const _$LocalBookIndexStatusEnumMap = {
  LocalBookIndexStatus.pending: 'pending',
  LocalBookIndexStatus.indexing: 'indexing',
  LocalBookIndexStatus.ready: 'ready',
  LocalBookIndexStatus.stale: 'stale',
  LocalBookIndexStatus.failed: 'failed',
};
