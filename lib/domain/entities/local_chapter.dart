import 'package:json_annotation/json_annotation.dart';

import 'reader_document.dart';

part 'local_chapter.g.dart';

@JsonSerializable(explicitToJson: true)
class LocalChapter {
  const LocalChapter({
    required this.id,
    required this.bookId,
    required this.chapterIndex,
    required this.title,
    required this.content,
    this.imageUrls = const <String>[],
    this.sourceRef,
    this.contentType,
    required this.createdAt,
    required this.updatedAt,
    this.startOffset,
    this.endOffset,
    this.document,
  });

  final String id;
  final String bookId;
  final int chapterIndex;
  final String title;
  final String content;
  final List<String> imageUrls;
  final String? sourceRef;
  final String? contentType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? startOffset;
  final int? endOffset;
  final ReaderDocument? document;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasStoredTextContent => content.trim().isNotEmpty;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasImageContent => imageUrls.isNotEmpty;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasStructuredContent =>
      document != null && document!.blocks.isNotEmpty;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasReadablePayload =>
      hasStoredTextContent || hasImageContent || hasStructuredContent;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasOffsetRange {
    final start = startOffset;
    final end = endOffset;
    return start != null && end != null && end > start;
  }

  LocalChapter copyWith({
    String? id,
    String? bookId,
    int? chapterIndex,
    String? title,
    String? content,
    List<String>? imageUrls,
    String? sourceRef,
    bool clearSourceRef = false,
    String? contentType,
    bool clearContentType = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? startOffset,
    bool clearStartOffset = false,
    int? endOffset,
    bool clearEndOffset = false,
    ReaderDocument? document,
    bool clearDocument = false,
  }) {
    return LocalChapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      sourceRef: clearSourceRef ? null : (sourceRef ?? this.sourceRef),
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startOffset: clearStartOffset ? null : (startOffset ?? this.startOffset),
      endOffset: clearEndOffset ? null : (endOffset ?? this.endOffset),
      document: clearDocument ? null : (document ?? this.document),
    );
  }

  Map<String, dynamic> toJson() {
    return _$LocalChapterToJson(this);
  }

  factory LocalChapter.fromJson(Map<String, dynamic> json) {
    return _$LocalChapterFromJson(_normalizeLocalChapterJson(json));
  }

  static ReaderDocument? _optionalDocument(Object? value) {
    if (value is Map) {
      return ReaderDocument.fromJson(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return null;
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Missing required field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = _optionalInt(json[key]);
    if (value == null) {
      throw FormatException('Missing required int field: $key');
    }
    return value;
  }

  static int? _optionalInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final raw = json[key]?.toString();
    if (raw == null || raw.trim().isEmpty) {
      throw FormatException('Missing required DateTime field: $key');
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      throw FormatException('Invalid DateTime field: $key');
    }
    return parsed;
  }

  static List<String> _optionalStringList(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static String? _optionalString(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}

Map<String, dynamic> _normalizeLocalChapterJson(Map<String, dynamic> json) {
  return <String, dynamic>{
    'id': LocalChapter._requiredString(json, 'id'),
    'bookId': LocalChapter._requiredString(json, 'bookId'),
    'chapterIndex': LocalChapter._requiredInt(json, 'chapterIndex'),
    'title': LocalChapter._requiredString(json, 'title'),
    'content': json['content']?.toString() ?? '',
    'imageUrls': LocalChapter._optionalStringList(json['imageUrls']),
    'sourceRef': LocalChapter._optionalString(json['sourceRef']),
    'contentType': LocalChapter._optionalString(json['contentType']),
    'createdAt':
        LocalChapter._requiredDateTime(json, 'createdAt').toIso8601String(),
    'updatedAt':
        LocalChapter._requiredDateTime(json, 'updatedAt').toIso8601String(),
    'startOffset': LocalChapter._optionalInt(json['startOffset']),
    'endOffset': LocalChapter._optionalInt(json['endOffset']),
    'document': LocalChapter._optionalDocument(json['document'])?.toJson(),
  };
}
