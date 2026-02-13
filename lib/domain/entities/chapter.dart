class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.chapterUrl,
    required this.index,
  });

  final String id;
  final String bookId;
  final String title;
  final String chapterUrl;
  final int index;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'title': title,
      'chapterUrl': chapterUrl,
      'index': index,
    };
  }

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: _requiredString(json, 'id'),
      bookId: _requiredString(json, 'bookId'),
      title: _requiredString(json, 'title'),
      chapterUrl: _requiredString(json, 'chapterUrl'),
      index: _requiredInt(json, 'index'),
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
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
    throw FormatException('Missing required int field: $key');
  }
}
