class Book {
  const Book({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.detailUrl,
    this.author,
    this.intro,
    this.coverUrl,
    this.latestChapter,
  });

  final String id;
  final String sourceId;
  final String title;
  final String detailUrl;
  final String? author;
  final String? intro;
  final String? coverUrl;
  final String? latestChapter;

  Book copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? detailUrl,
    String? author,
    bool clearAuthor = false,
    String? intro,
    bool clearIntro = false,
    String? coverUrl,
    bool clearCoverUrl = false,
    String? latestChapter,
    bool clearLatestChapter = false,
  }) {
    return Book(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      detailUrl: detailUrl ?? this.detailUrl,
      author: clearAuthor ? null : (author ?? this.author),
      intro: clearIntro ? null : (intro ?? this.intro),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      latestChapter:
          clearLatestChapter ? null : (latestChapter ?? this.latestChapter),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'title': title,
      'detailUrl': detailUrl,
      'author': author,
      'intro': intro,
      'coverUrl': coverUrl,
      'latestChapter': latestChapter,
    };
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: _requiredString(json, 'id'),
      sourceId: _requiredString(json, 'sourceId'),
      title: _requiredString(json, 'title'),
      detailUrl: _requiredString(json, 'detailUrl'),
      author: _optionalString(json['author']),
      intro: _optionalString(json['intro']),
      coverUrl: _optionalString(json['coverUrl']),
      latestChapter: _optionalString(json['latestChapter']),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static String? _optionalString(Object? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.toString().trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
