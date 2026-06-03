import 'package:json_annotation/json_annotation.dart';

part 'chapter.g.dart';

@JsonSerializable()
class Chapter {
  const Chapter({
    required this.id,
    required this.bookId,
    required this.title,
    required this.chapterUrl,
    required this.index,
    this.isVolume = false,
    this.executionContext,
  });

  @JsonKey(fromJson: _requiredId)
  final String id;
  @JsonKey(fromJson: _requiredBookId)
  final String bookId;
  @JsonKey(fromJson: _requiredTitle)
  final String title;
  @JsonKey(fromJson: _stringAllowEmpty)
  final String chapterUrl;
  @JsonKey(fromJson: _requiredIndex)
  final int index;
  final bool isVolume;
  @JsonKey(fromJson: _optionalString)
  final String? executionContext;

  Map<String, dynamic> toJson() => _$ChapterToJson(this);

  factory Chapter.fromJson(Map<String, dynamic> json) => _$ChapterFromJson(json);

  static String _requiredId(Object? value) => _requiredString(value, 'id');

  static String _requiredBookId(Object? value) =>
      _requiredString(value, 'bookId');

  static String _requiredTitle(Object? value) =>
      _requiredString(value, 'title');

  static int _requiredIndex(Object? value) => _requiredInt(value, 'index');

  static String _requiredString(Object? value, String key) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return normalized;
  }

  static int _requiredInt(Object? value, String key) {
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

  static String _stringAllowEmpty(Object? value) {
    return value?.toString().trim() ?? '';
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
