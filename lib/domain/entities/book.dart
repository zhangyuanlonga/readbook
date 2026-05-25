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
    this.wordCount,
    this.category,
    this.tags = const <String>[],
    this.updateTime,
    this.executionContext,
  });

  final String id;
  final String sourceId;
  final String title;
  final String detailUrl;
  final String? author;
  final String? intro;
  final String? coverUrl;
  final String? latestChapter;
  final String? wordCount;
  final String? category;
  final List<String> tags;
  final String? updateTime;
  final String? executionContext;

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
    String? wordCount,
    bool clearWordCount = false,
    String? category,
    bool clearCategory = false,
    List<String>? tags,
    String? updateTime,
    bool clearUpdateTime = false,
    String? executionContext,
    bool clearExecutionContext = false,
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
      wordCount: clearWordCount ? null : (wordCount ?? this.wordCount),
      category: clearCategory ? null : (category ?? this.category),
      tags: tags ?? this.tags,
      updateTime: clearUpdateTime ? null : (updateTime ?? this.updateTime),
      executionContext:
          clearExecutionContext
              ? null
              : (executionContext ?? this.executionContext),
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
      'wordCount': wordCount,
      'category': category,
      'tags': tags,
      'updateTime': updateTime,
      'executionContext': executionContext,
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
      wordCount: _optionalString(json['wordCount']),
      category: _optionalString(json['category']),
      tags: _stringList(json['tags']),
      updateTime: _optionalString(json['updateTime']),
      executionContext: _optionalString(json['executionContext']),
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

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
