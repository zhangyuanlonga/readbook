import 'package:json_annotation/json_annotation.dart';

part 'book.g.dart';

@JsonSerializable()
class Book {
  const Book({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.detailUrl,
    this.tocUrl,
    this.author,
    this.intro,
    this.coverUrl,
    this.latestChapter,
    this.wordCount,
    this.category,
    this.tags = const <String>[],
    this.updateTime,
    this.infoHtml,
    this.tocHtml,
    this.executionContext,
  });

  final String id;
  final String sourceId;
  final String title;
  final String detailUrl;
  final String? tocUrl;
  final String? author;
  final String? intro;
  final String? coverUrl;
  final String? latestChapter;
  final String? wordCount;
  final String? category;
  final List<String> tags;
  final String? updateTime;
  final String? infoHtml;
  final String? tocHtml;
  final String? executionContext;

  Book copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? detailUrl,
    Object? tocUrl = _sentinel,
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
    Object? infoHtml = _sentinel,
    Object? tocHtml = _sentinel,
    String? executionContext,
    bool clearExecutionContext = false,
  }) {
    return Book(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      detailUrl: detailUrl ?? this.detailUrl,
      tocUrl: identical(tocUrl, _sentinel) ? this.tocUrl : tocUrl as String?,
      author: clearAuthor ? null : (author ?? this.author),
      intro: clearIntro ? null : (intro ?? this.intro),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      latestChapter:
          clearLatestChapter ? null : (latestChapter ?? this.latestChapter),
      wordCount: clearWordCount ? null : (wordCount ?? this.wordCount),
      category: clearCategory ? null : (category ?? this.category),
      tags: tags ?? this.tags,
      updateTime: clearUpdateTime ? null : (updateTime ?? this.updateTime),
      infoHtml:
          identical(infoHtml, _sentinel) ? this.infoHtml : infoHtml as String?,
      tocHtml:
          identical(tocHtml, _sentinel) ? this.tocHtml : tocHtml as String?,
      executionContext:
          clearExecutionContext
              ? null
              : (executionContext ?? this.executionContext),
    );
  }

  Map<String, dynamic> toJson() {
    return _$BookToJson(this);
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    return _$BookFromJson(_normalizeBookJson(json));
  }

  static const Object _sentinel = Object();

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

Map<String, dynamic> _normalizeBookJson(Map<String, dynamic> json) {
  return <String, dynamic>{
    'id': Book._requiredString(json, 'id'),
    'sourceId': Book._requiredString(json, 'sourceId'),
    'title': Book._requiredString(json, 'title'),
    'detailUrl': Book._requiredString(json, 'detailUrl'),
    'tocUrl': Book._optionalString(json['tocUrl']),
    'author': Book._optionalString(json['author']),
    'intro': Book._optionalString(json['intro']),
    'coverUrl': Book._optionalString(json['coverUrl']),
    'latestChapter': Book._optionalString(json['latestChapter']),
    'wordCount': Book._optionalString(json['wordCount']),
    'category': Book._optionalString(json['category']),
    'tags': Book._stringList(json['tags']),
    'updateTime': Book._optionalString(json['updateTime']),
    'infoHtml': Book._optionalString(json['infoHtml']),
    'tocHtml': Book._optionalString(json['tocHtml']),
    'executionContext': Book._optionalString(json['executionContext']),
  };
}
