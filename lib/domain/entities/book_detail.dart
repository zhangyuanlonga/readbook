class BookDetail {
  const BookDetail({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.detailUrl,
    this.author,
    this.intro,
    this.coverUrl,
    this.tocUrl,
    this.latestChapterTitle,
    this.totalChapterNum,
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
  final String? tocUrl;
  final String? latestChapterTitle;
  final int? totalChapterNum;
  final String? wordCount;
  final String? category;
  final List<String> tags;
  final String? updateTime;
  final String? executionContext;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceId': sourceId,
      'title': title,
      'detailUrl': detailUrl,
      'author': author,
      'intro': intro,
      'coverUrl': coverUrl,
      'tocUrl': tocUrl,
      'latestChapterTitle': latestChapterTitle,
      'totalChapterNum': totalChapterNum,
      'wordCount': wordCount,
      'category': category,
      'tags': tags,
      'updateTime': updateTime,
      'executionContext': executionContext,
    };
  }

  factory BookDetail.fromJson(Map<String, dynamic> json) {
    return BookDetail(
      id: _requiredString(json, 'id'),
      sourceId: _requiredString(json, 'sourceId'),
      title: _requiredString(json, 'title'),
      detailUrl: _requiredString(json, 'detailUrl'),
      author: _optionalString(json['author']),
      intro: _optionalString(json['intro']),
      coverUrl: _optionalString(json['coverUrl']),
      tocUrl: _optionalString(json['tocUrl']),
      latestChapterTitle: _optionalString(json['latestChapterTitle']),
      totalChapterNum: _optionalInt(json['totalChapterNum']),
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

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
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
