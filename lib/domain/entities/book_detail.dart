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
  });

  final String id;
  final String sourceId;
  final String title;
  final String detailUrl;
  final String? author;
  final String? intro;
  final String? coverUrl;
  final String? tocUrl;

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
