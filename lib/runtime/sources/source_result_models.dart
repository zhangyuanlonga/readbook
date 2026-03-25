typedef RuntimeExtra = Map<String, dynamic>;

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.cover = '',
    this.intro = '',
    this.status = '',
    this.category = '',
    this.score = '',
    this.wordCount = '',
    this.updateTime = '',
    this.tags = const <String>[],
    this.latestChapter = '',
    this.detailUrl = '',
    this.sourceId = '',
    this.extra = const <String, dynamic>{},
    this.debug = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String author;
  final String cover;
  final String intro;
  final String status;
  final String category;
  final String score;
  final String wordCount;
  final String updateTime;
  final List<String> tags;
  final String latestChapter;
  final String detailUrl;
  final String sourceId;
  final RuntimeExtra extra;
  final RuntimeExtra debug;

  factory Book.fromMap(
    Map<String, dynamic> map, {
    String fallbackSourceId = '',
  }) {
    return Book(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      author: map['author']?.toString() ?? '',
      cover: map['cover']?.toString() ?? '',
      intro: map['intro']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      score: map['score']?.toString() ?? '',
      wordCount: map['wordCount']?.toString() ?? '',
      updateTime: map['updateTime']?.toString() ?? '',
      tags: (map['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      latestChapter: map['latestChapter']?.toString() ?? '',
      detailUrl: map['detailUrl']?.toString() ?? '',
      sourceId: map['sourceId']?.toString() ?? fallbackSourceId,
      extra: _toRuntimeExtra(map['extra']),
      debug: _toRuntimeExtra(map['debug']),
    );
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    String? cover,
    String? intro,
    String? status,
    String? category,
    String? score,
    String? wordCount,
    String? updateTime,
    List<String>? tags,
    String? latestChapter,
    String? detailUrl,
    String? sourceId,
    RuntimeExtra? extra,
    RuntimeExtra? debug,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      cover: cover ?? this.cover,
      intro: intro ?? this.intro,
      status: status ?? this.status,
      category: category ?? this.category,
      score: score ?? this.score,
      wordCount: wordCount ?? this.wordCount,
      updateTime: updateTime ?? this.updateTime,
      tags: tags ?? this.tags,
      latestChapter: latestChapter ?? this.latestChapter,
      detailUrl: detailUrl ?? this.detailUrl,
      sourceId: sourceId ?? this.sourceId,
      extra: extra ?? this.extra,
      debug: debug ?? this.debug,
    );
  }
}

class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.url,
    required this.index,
    this.vip = false,
    this.updateTime = '',
    this.sourceId = '',
    this.extra = const <String, dynamic>{},
    this.debug = const <String, dynamic>{},
  });

  final String id;
  final String title;
  final String url;
  final int index;
  final bool vip;
  final String updateTime;
  final String sourceId;
  final RuntimeExtra extra;
  final RuntimeExtra debug;

  factory Chapter.fromMap(
    Map<String, dynamic> map, {
    String fallbackSourceId = '',
  }) {
    return Chapter(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      url: map['url']?.toString() ?? '',
      index: _readInt(map['index'], fallback: 0),
      vip: map['vip'] is bool ? map['vip'] as bool : false,
      updateTime: map['updateTime']?.toString() ?? '',
      sourceId: map['sourceId']?.toString() ?? fallbackSourceId,
      extra: _toRuntimeExtra(map['extra']),
      debug: _toRuntimeExtra(map['debug']),
    );
  }

  Chapter copyWith({
    String? id,
    String? title,
    String? url,
    int? index,
    bool? vip,
    String? updateTime,
    String? sourceId,
    RuntimeExtra? extra,
    RuntimeExtra? debug,
  }) {
    return Chapter(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      index: index ?? this.index,
      vip: vip ?? this.vip,
      updateTime: updateTime ?? this.updateTime,
      sourceId: sourceId ?? this.sourceId,
      extra: extra ?? this.extra,
      debug: debug ?? this.debug,
    );
  }
}

class Content {
  const Content({
    required this.title,
    required this.content,
    this.nextUrl,
    this.images = const <String>[],
    this.sourceId = '',
    this.extra = const <String, dynamic>{},
    this.debug = const <String, dynamic>{},
  });

  final String title;
  final String content;
  final String? nextUrl;
  final List<String> images;
  final String sourceId;
  final RuntimeExtra extra;
  final RuntimeExtra debug;

  factory Content.fromMap(
    Map<String, dynamic> map, {
    String fallbackSourceId = '',
  }) {
    return Content(
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      nextUrl: map['nextUrl']?.toString(),
      images: (map['images'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
      sourceId: map['sourceId']?.toString() ?? fallbackSourceId,
      extra: _toRuntimeExtra(map['extra']),
      debug: _toRuntimeExtra(map['debug']),
    );
  }

  Content copyWith({
    String? title,
    String? content,
    Object? nextUrl = _stringSentinel,
    List<String>? images,
    String? sourceId,
    RuntimeExtra? extra,
    RuntimeExtra? debug,
  }) {
    return Content(
      title: title ?? this.title,
      content: content ?? this.content,
      nextUrl:
          identical(nextUrl, _stringSentinel)
              ? this.nextUrl
              : nextUrl as String?,
      images: images ?? this.images,
      sourceId: sourceId ?? this.sourceId,
      extra: extra ?? this.extra,
      debug: debug ?? this.debug,
    );
  }
}

const Object _stringSentinel = Object();

RuntimeExtra _toRuntimeExtra(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }
  return const <String, dynamic>{};
}

int _readInt(dynamic value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
