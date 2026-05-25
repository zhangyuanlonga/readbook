import 'reader_logical_position.dart';

class ReaderPositionSnapshot {
  const ReaderPositionSnapshot({
    required this.viewportMode,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.maxScrollExtent,
    this.zoomScale,
    this.panDx,
    this.panDy,
    this.audioPositionMs,
    this.audioDurationMs,
    this.audioSpeed,
  });

  final String viewportMode;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? maxScrollExtent;
  final double? zoomScale;
  final double? panDx;
  final double? panDy;
  final int? audioPositionMs;
  final int? audioDurationMs;
  final double? audioSpeed;

  Map<String, dynamic> toJson() {
    return {
      'viewportMode': viewportMode,
      'pageIndex': pageIndex,
      'pageCount': pageCount,
      'scrollOffset': scrollOffset,
      'maxScrollExtent': maxScrollExtent,
      'zoomScale': zoomScale,
      'panDx': panDx,
      'panDy': panDy,
      'audioPositionMs': audioPositionMs,
      'audioDurationMs': audioDurationMs,
      'audioSpeed': audioSpeed,
    };
  }

  factory ReaderPositionSnapshot.fromJson(Map<String, dynamic> json) {
    final viewportMode = (json['viewportMode']?.toString().trim() ?? '');
    if (viewportMode.isEmpty) {
      throw const FormatException('Missing required field: viewportMode');
    }
    return ReaderPositionSnapshot(
      viewportMode: viewportMode,
      pageIndex: ReadingProgress._optionalInt(json['pageIndex']),
      pageCount: ReadingProgress._optionalInt(json['pageCount']),
      scrollOffset: ReadingProgress._asDouble(json['scrollOffset']),
      maxScrollExtent: ReadingProgress._asDouble(json['maxScrollExtent']),
      zoomScale: ReadingProgress._asDouble(json['zoomScale']),
      panDx: ReadingProgress._asDouble(json['panDx']),
      panDy: ReadingProgress._asDouble(json['panDy']),
      audioPositionMs: ReadingProgress._optionalInt(json['audioPositionMs']),
      audioDurationMs: ReadingProgress._optionalInt(json['audioDurationMs']),
      audioSpeed: ReadingProgress._asDouble(json['audioSpeed']),
    );
  }
}

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
    this.positionSnapshot,
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
  final ReaderPositionSnapshot? positionSnapshot;

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
      if (positionSnapshot != null)
        'positionSnapshot': positionSnapshot!.toJson(),
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
      chapterPositionRatio: _requiredDouble(
        json,
        'chapterPositionRatio',
      ).clamp(0.0, 1.0),
      logicalPosition: _optionalLogicalPosition(json['logicalPosition']),
      positionSnapshot: _optionalPositionSnapshot(json['positionSnapshot']),
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

  static double _requiredDouble(Map<String, dynamic> json, String key) {
    final value = _asDouble(json[key]);
    if (value == null) {
      throw FormatException('Missing required double field: $key');
    }
    return value;
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

  static ReaderPositionSnapshot? _optionalPositionSnapshot(Object? value) {
    if (value is! Map) {
      return null;
    }
    return ReaderPositionSnapshot.fromJson(
      value.map((key, nestedValue) => MapEntry(key.toString(), nestedValue)),
    );
  }
}
