import 'package:json_annotation/json_annotation.dart';

part 'book_detail.g.dart';

@JsonSerializable()
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

  @JsonKey(fromJson: _requiredDetailId)
  final String id;
  @JsonKey(fromJson: _requiredSourceId)
  final String sourceId;
  @JsonKey(fromJson: _requiredTitle)
  final String title;
  @JsonKey(fromJson: _requiredDetailUrl)
  final String detailUrl;
  @JsonKey(fromJson: _optionalString)
  final String? author;
  @JsonKey(fromJson: _optionalString)
  final String? intro;
  @JsonKey(fromJson: _optionalString)
  final String? coverUrl;
  @JsonKey(fromJson: _optionalString)
  final String? tocUrl;
  @JsonKey(fromJson: _optionalString)
  final String? latestChapterTitle;
  @JsonKey(fromJson: _optionalInt)
  final int? totalChapterNum;
  @JsonKey(fromJson: _optionalString)
  final String? wordCount;
  @JsonKey(fromJson: _optionalString)
  final String? category;
  @JsonKey(fromJson: _stringList)
  final List<String> tags;
  @JsonKey(fromJson: _optionalString)
  final String? updateTime;
  @JsonKey(fromJson: _optionalString)
  final String? executionContext;

  Map<String, dynamic> toJson() => _$BookDetailToJson(this);

  factory BookDetail.fromJson(Map<String, dynamic> json) =>
      _$BookDetailFromJson(json);

  static String _requiredDetailId(Object? value) => _requiredString(value, 'id');

  static String _requiredSourceId(Object? value) =>
      _requiredString(value, 'sourceId');

  static String _requiredTitle(Object? value) =>
      _requiredString(value, 'title');

  static String _requiredDetailUrl(Object? value) =>
      _requiredString(value, 'detailUrl');

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

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString().trim() ?? '');
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
