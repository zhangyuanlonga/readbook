// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookshelfBook _$BookshelfBookFromJson(Map<String, dynamic> json) =>
    BookshelfBook(
      bookId: json['bookId'] as String,
      sourceId: json['sourceId'] as String,
      title: json['title'] as String,
      detailUrl: json['detailUrl'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
      author: json['author'] as String?,
      category: json['category'] as String?,
      coverUrl: json['coverUrl'] as String?,
      latestChapter: json['latestChapter'] as String?,
      inReadingQueue: json['inReadingQueue'] as bool? ?? false,
    );

Map<String, dynamic> _$BookshelfBookToJson(BookshelfBook instance) =>
    <String, dynamic>{
      'bookId': instance.bookId,
      'sourceId': instance.sourceId,
      'title': instance.title,
      'detailUrl': instance.detailUrl,
      'addedAt': instance.addedAt.toIso8601String(),
      'author': instance.author,
      'category': instance.category,
      'coverUrl': instance.coverUrl,
      'latestChapter': instance.latestChapter,
      'inReadingQueue': instance.inReadingQueue,
    };
