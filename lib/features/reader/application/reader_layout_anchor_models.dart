import '../domain/entities/reader_layout_models.dart';

enum ReaderLayoutAnchorKind {
  selection,
  annotation,
  bookmark,
  search,
  readAloud,
  progress,
}

class ReaderLayoutAnchoredRange {
  const ReaderLayoutAnchoredRange({
    required this.kind,
    required this.range,
    this.selectedText = '',
    this.rects = const <ReaderLayoutRect>[],
    this.layoutSignature,
    this.sourceId,
    this.payload = const <String, Object?>{},
  });

  final ReaderLayoutAnchorKind kind;
  final ReaderLayoutRange range;
  final String selectedText;
  final List<ReaderLayoutRect> rects;
  final String? layoutSignature;
  final String? sourceId;
  final Map<String, Object?> payload;

  int get startOffset => range.start.chapterOffset;
  int get endOffset => range.end.chapterOffset;
  bool get isCollapsed => range.isCollapsed;
  bool get spansMultiplePages => range.spansMultiplePages;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 'reader_layout_anchor_v1',
      'kind': kind.name,
      'start': _positionToJson(range.start),
      'end': _positionToJson(range.end),
      'selectedText': selectedText,
      if (layoutSignature != null) 'layoutSignature': layoutSignature,
      if (sourceId != null) 'sourceId': sourceId,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }

  static ReaderLayoutAnchoredRange? fromJson(Map<String, Object?> json) {
    if (json['version'] != 'reader_layout_anchor_v1') {
      return null;
    }
    final kind = _parseKind(json['kind']);
    final start = _positionFromJson(json['start']);
    final end = _positionFromJson(json['end']);
    if (kind == null || start == null || end == null) {
      return null;
    }
    final normalized =
        ReaderLayoutPosition.compare(start, end) <= 0
            ? (start: start, end: end)
            : (start: end, end: start);
    return ReaderLayoutAnchoredRange(
      kind: kind,
      range: ReaderLayoutRange(start: normalized.start, end: normalized.end),
      selectedText: json['selectedText']?.toString() ?? '',
      layoutSignature: json['layoutSignature']?.toString(),
      sourceId: json['sourceId']?.toString(),
      payload:
          json['payload'] is Map
              ? (json['payload'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              )
              : const <String, Object?>{},
    );
  }

  static ReaderLayoutAnchorKind? _parseKind(Object? value) {
    final name = value?.toString();
    for (final kind in ReaderLayoutAnchorKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    return null;
  }

  static Map<String, Object?> _positionToJson(ReaderLayoutPosition position) {
    return <String, Object?>{
      'pageIndex': position.pageIndex,
      'lineIndex': position.lineIndex,
      'columnIndex': position.columnIndex,
      'chapterOffset': position.chapterOffset,
      'affinity': position.affinity.name,
    };
  }

  static ReaderLayoutPosition? _positionFromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final pageIndex = _asInt(value['pageIndex']);
    final lineIndex = _asInt(value['lineIndex']);
    final columnIndex = _asInt(value['columnIndex']);
    final chapterOffset = _asInt(value['chapterOffset']);
    if (pageIndex == null ||
        lineIndex == null ||
        columnIndex == null ||
        chapterOffset == null) {
      return null;
    }
    return ReaderLayoutPosition(
      pageIndex: pageIndex,
      lineIndex: lineIndex,
      columnIndex: columnIndex,
      chapterOffset: chapterOffset,
      affinity: _parseAffinity(value['affinity']),
    );
  }

  static ReaderLayoutPositionAffinity _parseAffinity(Object? value) {
    final name = value?.toString();
    for (final affinity in ReaderLayoutPositionAffinity.values) {
      if (affinity.name == name) {
        return affinity;
      }
    }
    return ReaderLayoutPositionAffinity.downstream;
  }

  static int? _asInt(Object? value) {
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
}

class ReaderLayoutAnchoredPosition {
  const ReaderLayoutAnchoredPosition({
    required this.kind,
    required this.position,
    required this.chapterProgressRatio,
    this.layoutSignature,
    this.sourceId,
    this.totalPageCount,
  });

  final ReaderLayoutAnchorKind kind;
  final ReaderLayoutPosition position;
  final double chapterProgressRatio;
  final String? layoutSignature;
  final String? sourceId;
  final int? totalPageCount;

  int get chapterOffset => position.chapterOffset;
  int get pageIndex => position.pageIndex;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': 'reader_layout_position_anchor_v1',
      'kind': kind.name,
      'position': ReaderLayoutAnchoredRange._positionToJson(position),
      'chapterProgressRatio': chapterProgressRatio.clamp(0.0, 1.0),
      if (layoutSignature != null) 'layoutSignature': layoutSignature,
      if (sourceId != null) 'sourceId': sourceId,
      if (totalPageCount != null) 'totalPageCount': totalPageCount,
    };
  }
}

class ReaderLayoutRangeSegment {
  const ReaderLayoutRangeSegment({
    required this.pageIndex,
    required this.range,
    this.rects = const <ReaderLayoutRect>[],
    this.selectedText = '',
  });

  final int pageIndex;
  final ReaderLayoutRange range;
  final List<ReaderLayoutRect> rects;
  final String selectedText;
}

class ReaderLayoutProgressSnapshot {
  const ReaderLayoutProgressSnapshot({
    required this.chapterOffset,
    required this.chapterPositionRatio,
    required this.pageIndex,
    required this.totalPageCount,
  });

  final int chapterOffset;
  final double chapterPositionRatio;
  final int pageIndex;
  final int totalPageCount;
}
