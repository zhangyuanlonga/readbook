import 'chapter.dart';

class ReaderTocSnapshot {
  const ReaderTocSnapshot({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.title,
    this.author,
    this.coverUrl,
    required this.chapters,
    required this.updatedAt,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String title;
  final String? author;
  final String? coverUrl;
  final List<Chapter> chapters;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'sourceId': sourceId,
      'detailUrl': detailUrl,
      'title': title,
      'author': author,
      'coverUrl': coverUrl,
      'chapters': chapters.map((item) => item.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ReaderTocSnapshot.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'];
    final chapters =
        chaptersJson is List
            ? chaptersJson
                .whereType<Map>()
                .map(
                  (item) => Chapter.fromJson(
                    item.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                )
                .toList(growable: false)
            : const <Chapter>[];

    return ReaderTocSnapshot(
      bookId: _requiredString(json, 'bookId'),
      sourceId: _requiredString(json, 'sourceId'),
      detailUrl: _requiredString(json, 'detailUrl'),
      title: _requiredString(json, 'title'),
      author: _optionalString(json['author']),
      coverUrl: _optionalString(json['coverUrl']),
      chapters: chapters,
      updatedAt: _requiredDateTime(json, 'updatedAt'),
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

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Missing required datetime field: $key');
    }
    return parsed;
  }
}
