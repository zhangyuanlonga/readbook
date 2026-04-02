import 'reader_logical_position.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.updatedAt,
    this.chapterPositionRatio = 0,
    this.logicalPosition,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final int chapterIndex;
  final DateTime updatedAt;
  final double chapterPositionRatio;
  final ReaderLogicalPosition? logicalPosition;

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'sourceId': sourceId,
      'detailUrl': detailUrl,
      'chapterId': chapterId,
      'chapterUrl': chapterUrl,
      'chapterTitle': chapterTitle,
      'chapterIndex': chapterIndex,
      'updatedAt': updatedAt.toIso8601String(),
      'chapterPositionRatio': chapterPositionRatio,
      if (logicalPosition != null) 'logicalPosition': logicalPosition!.toJson(),
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      bookId: _requiredString(json, 'bookId'),
      sourceId: _requiredString(json, 'sourceId'),
      detailUrl: _requiredString(json, 'detailUrl'),
      chapterId: _requiredString(json, 'chapterId'),
      chapterUrl: _requiredString(json, 'chapterUrl'),
      chapterTitle: _requiredString(json, 'chapterTitle'),
      chapterIndex: _requiredInt(json, 'chapterIndex'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      chapterPositionRatio: (_asDouble(json['chapterPositionRatio']) ?? 0)
          .clamp(0.0, 1.0),
      logicalPosition: _optionalLogicalPosition(json['logicalPosition']),
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

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
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

  static ReaderLogicalPosition? _optionalLogicalPosition(Object? value) {
    if (value is! Map) {
      return null;
    }
    return ReaderLogicalPosition.fromJson(
      value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue)),
    );
  }
}
