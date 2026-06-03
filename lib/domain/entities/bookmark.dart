import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

part 'bookmark.g.dart';

class BookmarkSnippetContent {
  const BookmarkSnippetContent({required this.quote, this.note});

  static const String _payloadPrefix = 'selune:bookmark:v1:';

  final String quote;
  final String? note;

  bool get hasNote => note?.trim().isNotEmpty == true;

  static BookmarkSnippetContent decode(String rawSnippet) {
    final normalized = rawSnippet.trim();
    if (normalized.isEmpty) {
      return const BookmarkSnippetContent(quote: '');
    }
    if (!normalized.startsWith(_payloadPrefix)) {
      return BookmarkSnippetContent(quote: normalized);
    }

    try {
      final rawPayload = normalized.substring(_payloadPrefix.length);
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) {
        return BookmarkSnippetContent(quote: normalized);
      }
      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final quote = (payload['quote'] ?? '').toString().trim();
      final note = (payload['note'] ?? '').toString().trim();
      if (quote.isEmpty) {
        return BookmarkSnippetContent(quote: normalized);
      }
      return BookmarkSnippetContent(
        quote: quote,
        note: note.isEmpty ? null : note,
      );
    } catch (_) {
      return BookmarkSnippetContent(quote: normalized);
    }
  }

  static String encode({required String quote, String? note}) {
    final normalizedQuote = quote.trim();
    final normalizedNote = note?.trim() ?? '';
    if (normalizedNote.isEmpty) {
      return normalizedQuote;
    }
    return '$_payloadPrefix${jsonEncode(<String, String>{'quote': normalizedQuote, 'note': normalizedNote})}';
  }
}

@JsonSerializable(createFactory: false)
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
    required this.snippet,
    required this.createdAt,
    required this.updatedAt,
    this.isBold = false,
    this.isUnderline = false,
    this.isWavy = false,
    this.color,
    String? note,
  }) : noteText = note;

  final String id;
  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;
  final String snippet;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isBold;
  final bool isUnderline;
  final bool isWavy;
  final String? color;
  @JsonKey(name: 'note')
  final String? noteText;

  @JsonKey(includeFromJson: false, includeToJson: false)
  BookmarkSnippetContent get content {
    final decoded = BookmarkSnippetContent.decode(snippet);
    final explicitNote = noteText?.trim();
    return BookmarkSnippetContent(
      quote: decoded.quote,
      note: explicitNote?.isNotEmpty == true ? explicitNote : decoded.note,
    );
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  String get displaySnippet => content.quote;

  @JsonKey(includeFromJson: false, includeToJson: false)
  String? get note => content.note;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool get hasNote => content.hasNote;

  static String buildSnippetPayload({required String quote, String? note}) {
    return BookmarkSnippetContent.encode(quote: quote, note: note);
  }

  Bookmark copyWith({
    String? id,
    String? bookId,
    String? chapterId,
    int? chapterIndex,
    int? startOffset,
    int? endOffset,
    String? snippet,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBold,
    bool? isUnderline,
    bool? isWavy,
    String? color,
    String? note,
    bool clearColor = false,
    bool clearNote = false,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      snippet: snippet ?? this.snippet,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBold: isBold ?? this.isBold,
      isUnderline: isUnderline ?? this.isUnderline,
      isWavy: isWavy ?? this.isWavy,
      color: clearColor ? null : (color ?? this.color),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() {
    final json = _$BookmarkToJson(this);
    json['note'] = note;
    return json;
  }

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: _requiredString(json, 'id'),
      bookId: _requiredString(json, 'bookId'),
      chapterId: _requiredString(json, 'chapterId'),
      chapterIndex: _requiredInt(json, 'chapterIndex'),
      startOffset: _requiredInt(json, 'startOffset'),
      endOffset: _requiredInt(json, 'endOffset'),
      snippet: _requiredString(json, 'snippet'),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      isBold: _optionalBool(json['isBold']) ?? false,
      isUnderline: _optionalBool(json['isUnderline']) ?? false,
      isWavy: _optionalBool(json['isWavy']) ?? false,
      color: _optionalString(json['color']),
      note: _optionalString(json['note']),
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

  static bool? _optionalBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == '1' || normalized == 'true') {
        return true;
      }
      if (normalized == '0' || normalized == 'false') {
        return false;
      }
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
}
