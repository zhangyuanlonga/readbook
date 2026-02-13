class BookshelfBook {
  const BookshelfBook({
    required this.bookId,
    required this.sourceId,
    required this.title,
    required this.detailUrl,
    required this.addedAt,
    this.author,
    this.coverUrl,
  });

  final String bookId;
  final String sourceId;
  final String title;
  final String detailUrl;
  final DateTime addedAt;
  final String? author;
  final String? coverUrl;

  BookshelfBook copyWith({
    String? bookId,
    String? sourceId,
    String? title,
    String? detailUrl,
    DateTime? addedAt,
    String? author,
    bool clearAuthor = false,
    String? coverUrl,
    bool clearCoverUrl = false,
  }) {
    return BookshelfBook(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      detailUrl: detailUrl ?? this.detailUrl,
      addedAt: addedAt ?? this.addedAt,
      author: clearAuthor ? null : (author ?? this.author),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'sourceId': sourceId,
      'title': title,
      'detailUrl': detailUrl,
      'addedAt': addedAt.toIso8601String(),
      'author': author,
      'coverUrl': coverUrl,
    };
  }

  factory BookshelfBook.fromJson(Map<String, dynamic> json) {
    return BookshelfBook(
      bookId: _requiredString(json, 'bookId'),
      sourceId: _requiredString(json, 'sourceId'),
      title: _requiredString(json, 'title'),
      detailUrl: _requiredString(json, 'detailUrl'),
      addedAt: _requiredDateTime(json, 'addedAt'),
      author: _optionalString(json['author']),
      coverUrl: _optionalString(json['coverUrl']),
    );
  }

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
