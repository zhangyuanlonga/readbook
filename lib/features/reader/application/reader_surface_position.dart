import '../../../domain/entities/reading_progress.dart';

enum ReaderSurfaceKind { text, image, document, audio }

class ReaderSurfacePosition {
  const ReaderSurfacePosition._({
    required this.kind,
    required this.chapterIndex,
    required this.progressRatio,
    this.chapterOffset,
    this.pageIndex,
    this.pageCount,
    this.scrollOffset,
    this.maxScrollExtent,
    this.imageIndex,
    this.imageCount,
    this.documentPageIndex,
    this.documentPageCount,
    this.zoomScale,
    this.panDx,
    this.panDy,
    this.pageScrollOffset,
    this.audioPositionMs,
    this.audioDurationMs,
    this.audioSpeed,
  });

  factory ReaderSurfacePosition.text({
    required int chapterIndex,
    int? chapterOffset,
    int? pageIndex,
    int? pageCount,
    double? scrollOffset,
    double? maxScrollExtent,
    double progressRatio = 0,
  }) {
    return ReaderSurfacePosition._(
      kind: ReaderSurfaceKind.text,
      chapterIndex: chapterIndex,
      chapterOffset: chapterOffset,
      pageIndex: pageIndex,
      pageCount: pageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      progressRatio: _clampRatio(progressRatio),
    );
  }

  factory ReaderSurfacePosition.image({
    required int chapterIndex,
    int? imageIndex,
    int? imageCount,
    double? scrollOffset,
    double? maxScrollExtent,
    double progressRatio = 0,
  }) {
    return ReaderSurfacePosition._(
      kind: ReaderSurfaceKind.image,
      chapterIndex: chapterIndex,
      imageIndex: imageIndex,
      imageCount: imageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      progressRatio: _clampRatio(progressRatio),
    );
  }

  factory ReaderSurfacePosition.document({
    required int chapterIndex,
    int? pageIndex,
    int? pageCount,
    double? zoomScale,
    double? panDx,
    double? panDy,
    double? pageScrollOffset,
    double progressRatio = 0,
  }) {
    return ReaderSurfacePosition._(
      kind: ReaderSurfaceKind.document,
      chapterIndex: chapterIndex,
      documentPageIndex: pageIndex,
      documentPageCount: pageCount,
      zoomScale: zoomScale,
      panDx: panDx,
      panDy: panDy,
      pageScrollOffset: pageScrollOffset,
      progressRatio: _clampRatio(progressRatio),
    );
  }

  factory ReaderSurfacePosition.audio({
    required int chapterIndex,
    int? positionMs,
    int? durationMs,
    double? speed,
    double progressRatio = 0,
  }) {
    return ReaderSurfacePosition._(
      kind: ReaderSurfaceKind.audio,
      chapterIndex: chapterIndex,
      audioPositionMs: positionMs,
      audioDurationMs: durationMs,
      audioSpeed: speed,
      progressRatio: _clampRatio(progressRatio),
    );
  }

  final ReaderSurfaceKind kind;
  final int chapterIndex;
  final int? chapterOffset;
  final int? pageIndex;
  final int? pageCount;
  final double? scrollOffset;
  final double? maxScrollExtent;
  final double progressRatio;
  final int? imageIndex;
  final int? imageCount;
  final int? documentPageIndex;
  final int? documentPageCount;
  final double? zoomScale;
  final double? panDx;
  final double? panDy;
  final double? pageScrollOffset;
  final int? audioPositionMs;
  final int? audioDurationMs;
  final double? audioSpeed;

  bool get isText => kind == ReaderSurfaceKind.text;
  bool get isImage => kind == ReaderSurfaceKind.image;
  bool get isDocument => kind == ReaderSurfaceKind.document;
  bool get isAudio => kind == ReaderSurfaceKind.audio;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind.name,
      'chapterIndex': chapterIndex,
      'progressRatio': progressRatio,
      if (chapterOffset != null) 'chapterOffset': chapterOffset,
      if (pageIndex != null) 'pageIndex': pageIndex,
      if (pageCount != null) 'pageCount': pageCount,
      if (scrollOffset != null) 'scrollOffset': scrollOffset,
      if (maxScrollExtent != null) 'maxScrollExtent': maxScrollExtent,
      if (imageIndex != null) 'imageIndex': imageIndex,
      if (imageCount != null) 'imageCount': imageCount,
      if (documentPageIndex != null) 'documentPageIndex': documentPageIndex,
      if (documentPageCount != null) 'documentPageCount': documentPageCount,
      if (zoomScale != null) 'zoomScale': zoomScale,
      if (panDx != null) 'panDx': panDx,
      if (panDy != null) 'panDy': panDy,
      if (pageScrollOffset != null) 'pageScrollOffset': pageScrollOffset,
      if (audioPositionMs != null) 'audioPositionMs': audioPositionMs,
      if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
      if (audioSpeed != null) 'audioSpeed': audioSpeed,
    };
  }

  factory ReaderSurfacePosition.fromJson(Map<String, Object?> json) {
    final kind = _parseKind(json['kind']);
    final chapterIndex = _asInt(json['chapterIndex']) ?? 0;
    final progressRatio = _asDouble(json['progressRatio']) ?? 0;

    return switch (kind) {
      ReaderSurfaceKind.image => ReaderSurfacePosition.image(
        chapterIndex: chapterIndex,
        imageIndex: _asInt(json['imageIndex']) ?? _asInt(json['pageIndex']),
        imageCount: _asInt(json['imageCount']) ?? _asInt(json['pageCount']),
        scrollOffset: _asDouble(json['scrollOffset']),
        maxScrollExtent: _asDouble(json['maxScrollExtent']),
        progressRatio: progressRatio,
      ),
      ReaderSurfaceKind.document => ReaderSurfacePosition.document(
        chapterIndex: chapterIndex,
        pageIndex:
            _asInt(json['documentPageIndex']) ?? _asInt(json['pageIndex']),
        pageCount:
            _asInt(json['documentPageCount']) ?? _asInt(json['pageCount']),
        zoomScale: _asDouble(json['zoomScale']),
        panDx: _asDouble(json['panDx']),
        panDy: _asDouble(json['panDy']),
        pageScrollOffset:
            _asDouble(json['pageScrollOffset']) ??
            _asDouble(json['scrollOffset']),
        progressRatio: progressRatio,
      ),
      ReaderSurfaceKind.audio => ReaderSurfacePosition.audio(
        chapterIndex: chapterIndex,
        positionMs:
            _asInt(json['audioPositionMs']) ?? _asInt(json['positionMs']),
        durationMs:
            _asInt(json['audioDurationMs']) ?? _asInt(json['durationMs']),
        speed: _asDouble(json['audioSpeed']) ?? _asDouble(json['speed']),
        progressRatio: progressRatio,
      ),
      ReaderSurfaceKind.text => ReaderSurfacePosition.text(
        chapterIndex: chapterIndex,
        chapterOffset: _asInt(json['chapterOffset']),
        pageIndex: _asInt(json['pageIndex']),
        pageCount: _asInt(json['pageCount']),
        scrollOffset: _asDouble(json['scrollOffset']),
        maxScrollExtent: _asDouble(json['maxScrollExtent']),
        progressRatio: progressRatio,
      ),
    };
  }
}

class ReaderSurfacePositionMapper {
  const ReaderSurfacePositionMapper();

  ReaderSurfacePosition fromSnapshot({
    required ReaderPositionSnapshot? snapshot,
    required int chapterIndex,
    required double chapterPositionRatio,
  }) {
    final viewportMode = snapshot?.viewportMode.trim();
    return switch (viewportMode) {
      'imagePaged' || 'imageScroll' => ReaderSurfacePosition.image(
        chapterIndex: chapterIndex,
        imageIndex: snapshot?.pageIndex,
        imageCount: snapshot?.pageCount,
        scrollOffset: snapshot?.scrollOffset,
        maxScrollExtent: snapshot?.maxScrollExtent,
        progressRatio: chapterPositionRatio,
      ),
      'hybridPaged' => ReaderSurfacePosition.document(
        chapterIndex: chapterIndex,
        pageIndex: snapshot?.pageIndex,
        pageCount: snapshot?.pageCount,
        zoomScale: snapshot?.zoomScale,
        panDx: snapshot?.panDx,
        panDy: snapshot?.panDy,
        pageScrollOffset: snapshot?.scrollOffset,
        progressRatio: chapterPositionRatio,
      ),
      'audio' => ReaderSurfacePosition.audio(
        chapterIndex: chapterIndex,
        positionMs: snapshot?.audioPositionMs,
        durationMs: snapshot?.audioDurationMs,
        speed: snapshot?.audioSpeed,
        progressRatio: chapterPositionRatio,
      ),
      _ => ReaderSurfacePosition.text(
        chapterIndex: chapterIndex,
        pageIndex: snapshot?.pageIndex,
        pageCount: snapshot?.pageCount,
        scrollOffset: snapshot?.scrollOffset,
        maxScrollExtent: snapshot?.maxScrollExtent,
        progressRatio: chapterPositionRatio,
      ),
    };
  }

  ReaderPositionSnapshot toSnapshot(ReaderSurfacePosition position) {
    return switch (position.kind) {
      ReaderSurfaceKind.image => ReaderPositionSnapshot(
        viewportMode: _imageViewportMode(position),
        pageIndex: position.imageIndex,
        pageCount: position.imageCount,
        scrollOffset: position.scrollOffset,
        maxScrollExtent: position.maxScrollExtent,
      ),
      ReaderSurfaceKind.document => ReaderPositionSnapshot(
        viewportMode: 'hybridPaged',
        pageIndex: position.documentPageIndex,
        pageCount: position.documentPageCount,
        scrollOffset: position.pageScrollOffset,
        zoomScale: position.zoomScale,
        panDx: position.panDx,
        panDy: position.panDy,
      ),
      ReaderSurfaceKind.audio => ReaderPositionSnapshot(
        viewportMode: 'audio',
        audioPositionMs: position.audioPositionMs,
        audioDurationMs: position.audioDurationMs,
        audioSpeed: position.audioSpeed,
      ),
      ReaderSurfaceKind.text => ReaderPositionSnapshot(
        viewportMode: _textViewportMode(position),
        pageIndex: position.pageIndex,
        pageCount: position.pageCount,
        scrollOffset: position.scrollOffset,
        maxScrollExtent: position.maxScrollExtent,
      ),
    };
  }

  String _textViewportMode(ReaderSurfacePosition position) {
    if (position.pageIndex == null && position.scrollOffset != null) {
      return 'textScroll';
    }
    return 'textPaged';
  }

  String _imageViewportMode(ReaderSurfacePosition position) {
    if (position.imageIndex == null && position.scrollOffset != null) {
      return 'imageScroll';
    }
    return 'imagePaged';
  }
}

ReaderSurfaceKind _parseKind(Object? value) {
  final name = value?.toString().trim();
  for (final kind in ReaderSurfaceKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return ReaderSurfaceKind.text;
}

int? _asInt(Object? value) {
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

double? _asDouble(Object? value) {
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

double _clampRatio(double value) => value.clamp(0.0, 1.0);
