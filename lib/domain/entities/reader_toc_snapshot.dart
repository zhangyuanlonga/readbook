import 'package:json_annotation/json_annotation.dart';

import 'chapter.dart';

part 'reader_toc_snapshot.g.dart';

@JsonSerializable(explicitToJson: true)
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

  @JsonKey(fromJson: _requiredBookId)
  final String bookId;
  @JsonKey(fromJson: _requiredSourceId)
  final String sourceId;
  @JsonKey(fromJson: _requiredDetailUrl)
  final String detailUrl;
  @JsonKey(fromJson: _requiredTitle)
  final String title;
  @JsonKey(fromJson: _optionalString)
  final String? author;
  @JsonKey(fromJson: _optionalString)
  final String? coverUrl;
  @JsonKey(fromJson: _chaptersFromJson)
  final List<Chapter> chapters;
  @JsonKey(fromJson: _requiredDateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => _$ReaderTocSnapshotToJson(this);

  factory ReaderTocSnapshot.fromJson(Map<String, dynamic> json) =>
      _$ReaderTocSnapshotFromJson(json);

  static String _requiredBookId(Object? value) =>
      _requiredString(value, 'bookId');

  static String _requiredSourceId(Object? value) =>
      _requiredString(value, 'sourceId');

  static String _requiredDetailUrl(Object? value) =>
      _requiredString(value, 'detailUrl');

  static String _requiredTitle(Object? value) =>
      _requiredString(value, 'title');

  static String _requiredString(Object? value, String key) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return normalized;
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

  static DateTime _requiredDateTimeFromJson(Object? value) {
    final raw = value?.toString().trim() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Missing required datetime field: updatedAt');
    }
    return parsed;
  }

  static List<Chapter> _chaptersFromJson(Object? value) {
    if (value is! List) {
      return const <Chapter>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) =>
              Chapter.fromJson(item.map((key, val) => MapEntry(key.toString(), val))),
        )
        .toList(growable: false);
  }

  static String _dateTimeToJson(DateTime value) => value.toIso8601String();
}
