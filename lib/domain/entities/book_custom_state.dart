import 'package:json_annotation/json_annotation.dart';

part 'book_custom_state.g.dart';

@JsonSerializable()
class BookCustomState {
  const BookCustomState({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.updatedAt,
    this.customVariableJson,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String? customVariableJson;
  final DateTime updatedAt;

  String get storageKey {
    final normalizedDetailUrl = _normalize(detailUrl);
    if (normalizedDetailUrl != null) {
      return '${sourceId.trim()}::$normalizedDetailUrl';
    }
    return '${sourceId.trim()}::${bookId.trim()}';
  }

  bool get isEmpty => _normalize(customVariableJson) == null;

  BookCustomState copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? customVariableJson,
    bool clearCustomVariableJson = false,
    DateTime? updatedAt,
  }) {
    return BookCustomState(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      customVariableJson:
          clearCustomVariableJson
              ? null
              : (customVariableJson ?? this.customVariableJson),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => _$BookCustomStateToJson(this);

  factory BookCustomState.fromJson(Map<String, dynamic> json) =>
      _$BookCustomStateFromJson(_normalizeBookCustomStateJson(json));

  static String _requiredString(Map<String, dynamic> json, String key) {
    final normalized = _normalize(json[key]?.toString());
    if (normalized == null) {
      throw FormatException('Missing required field: $key');
    }
    return normalized;
  }

  static String? _optionalString(Object? value) {
    return _normalize(value?.toString());
  }

  static String? _normalize(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
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

Map<String, dynamic> _normalizeBookCustomStateJson(Map<String, dynamic> json) {
  return <String, dynamic>{
    'bookId': BookCustomState._requiredString(json, 'bookId'),
    'sourceId': BookCustomState._requiredString(json, 'sourceId'),
    'detailUrl': json['detailUrl']?.toString() ?? '',
    'customVariableJson': BookCustomState._optionalString(
      json['customVariableJson'],
    ),
    'updatedAt': BookCustomState._requiredDateTime(json, 'updatedAt')
        .toIso8601String(),
  };
}
