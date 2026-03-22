class LocalChapter {
  const LocalChapter({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.content,
    this.imageUrls = const <String>[],
    required this.createdAt,
    required this.updatedAt,
    this.startOffset,
    this.endOffset,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final String title;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? startOffset;
  final int? endOffset;

  LocalChapter copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? title,
    String? content,
    List<String>? imageUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? startOffset,
    bool clearStartOffset = false,
    int? endOffset,
    bool clearEndOffset = false,
  }) {
    return LocalChapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startOffset: clearStartOffset ? null : (startOffset ?? this.startOffset),
      endOffset: clearEndOffset ? null : (endOffset ?? this.endOffset),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterIndex': chapterIndex,
      'title': title,
      'content': content,
      'imageUrls': imageUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'startOffset': startOffset,
      'endOffset': endOffset,
    };
  }

  factory LocalChapter.fromJson(Map<String, dynamic> json) {
    return LocalChapter(
      id: _requiredString(json, 'id'),
      bookId: _requiredString(json, 'bookId'),
      chapterIndex: _requiredInt(json, 'chapterIndex'),
      title: _requiredString(json, 'title'),
      content: json['content']?.toString() ?? '',
      imageUrls: _optionalStringList(json['imageUrls']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      startOffset: _optionalInt(json['startOffset']),
      endOffset: _optionalInt(json['endOffset']),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = _optionalInt(json[key]);
    if (value == null) {
      throw FormatException('Missing required int field: $key');
    }
    return value;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
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

  static List<String> _optionalStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }
}
