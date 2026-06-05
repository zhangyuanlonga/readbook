import 'package:json_annotation/json_annotation.dart';

part 'bookshelf_book.g.dart';

@JsonSerializable()
class BookshelfBook {
  const BookshelfBook({
    required this.bookId,
    required this.sourceId,
    required this.title,
    required this.detailUrl,
    required this.addedAt,
    this.author,
    this.category,
    this.coverUrl,
    this.latestChapter,
    this.inReadingQueue = false,
  });

  final String bookId;
  final String sourceId;
  final String title;
  final String detailUrl;
  final DateTime addedAt;
  final String? author;
  final String? category;
  final String? coverUrl;
  final String? latestChapter;
  final bool inReadingQueue;

  BookshelfBook copyWith({
    String? bookId,
    String? sourceId,
    String? title,
    String? detailUrl,
    DateTime? addedAt,
    String? author,
    bool clearAuthor = false,
    String? category,
    bool clearCategory = false,
    String? coverUrl,
    bool clearCoverUrl = false,
    String? latestChapter,
    bool clearLatestChapter = false,
    bool? inReadingQueue,
  }) {
    return BookshelfBook(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      detailUrl: detailUrl ?? this.detailUrl,
      addedAt: addedAt ?? this.addedAt,
      author: clearAuthor ? null : (author ?? this.author),
      category: clearCategory ? null : (category ?? this.category),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      latestChapter:
          clearLatestChapter ? null : (latestChapter ?? this.latestChapter),
      inReadingQueue: inReadingQueue ?? this.inReadingQueue,
    );
  }

  Map<String, dynamic> toJson() => _$BookshelfBookToJson(this);

  factory BookshelfBook.fromJson(Map<String, dynamic> json) =>
      _$BookshelfBookFromJson(_normalizeBookshelfBookJson(json));

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString();
    if (raw == null || raw.trim().isEmpty) {
      throw FormatException('Missing required DateTime field: $key');
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid DateTime field: $key');
    }

    return parsed;
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    return text;
  }
}

Map<String, dynamic> _normalizeBookshelfBookJson(Map<String, dynamic> json) {
  return <String, dynamic>{
    'bookId': BookshelfBook._requiredString(json, 'bookId'),
    'sourceId': BookshelfBook._requiredString(json, 'sourceId'),
    'title': BookshelfBook._requiredString(json, 'title'),
    'detailUrl': BookshelfBook._requiredString(json, 'detailUrl'),
    'addedAt':
        BookshelfBook._requiredDateTime(json, 'addedAt').toIso8601String(),
    'author': BookshelfBook._optionalString(json['author']),
    'category': BookshelfBook._optionalString(json['category']),
    'coverUrl': BookshelfBook._optionalString(json['coverUrl']),
    'latestChapter': BookshelfBook._optionalString(json['latestChapter']),
    'inReadingQueue':
        json['inReadingQueue'] == true ||
        json['inReadingQueue']?.toString().toLowerCase() == 'true',
  };
}
