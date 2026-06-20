import '../../../domain/entities/reading_progress.dart';
import 'reader_content_session.dart';
import 'reader_logical_position.dart';
import 'reader_surface_position.dart';
import 'reader_viewport_state.dart';

class ReaderSurfacePositionRuntime {
  const ReaderSurfacePositionRuntime({
    this.mapper = const ReaderSurfacePositionMapper(),
  });

  final ReaderSurfacePositionMapper mapper;

  ReaderSurfacePosition capture({
    required ReaderViewportState viewportState,
    required ReaderContentMode contentMode,
    required int chapterIndex,
    ReaderHybridSubMode? hybridSubMode,
    ReaderLogicalPosition? logicalPosition,
    Duration audioPlaybackPosition = Duration.zero,
    Duration audioPlaybackDuration = Duration.zero,
    double audioPlaybackSpeed = 1.0,
  }) {
    final ratio = viewportState.chapterPositionRatio.clamp(0.0, 1.0);
    if (contentMode == ReaderContentMode.audio) {
      return ReaderSurfacePosition.audio(
        chapterIndex: chapterIndex,
        positionMs:
            viewportState.audioPositionMs ??
            audioPlaybackPosition.inMilliseconds,
        durationMs:
            viewportState.audioDurationMs ??
            audioPlaybackDuration.inMilliseconds,
        speed: viewportState.audioSpeed ?? audioPlaybackSpeed,
        progressRatio: ratio,
      );
    }
    return switch (viewportState.kind) {
      ReaderViewportStateKind.textPaged ||
      ReaderViewportStateKind.textScroll => ReaderSurfacePosition.text(
        chapterIndex: chapterIndex,
        pageIndex: viewportState.pageIndex,
        pageCount: viewportState.pageCount,
        scrollOffset: viewportState.scrollOffset,
        maxScrollExtent: viewportState.maxScrollExtent,
        progressRatio: ratio,
      ),
      ReaderViewportStateKind.mangaPaged ||
      ReaderViewportStateKind.mangaContinuous => ReaderSurfacePosition.image(
        chapterIndex: chapterIndex,
        imageIndex: viewportState.pageIndex,
        imageCount: viewportState.pageCount,
        scrollOffset: viewportState.scrollOffset,
        maxScrollExtent: viewportState.maxScrollExtent,
        progressRatio: ratio,
      ),
      ReaderViewportStateKind.hybridPaged =>
        _isDocumentSurface(hybridSubMode)
            ? ReaderSurfacePosition.document(
              chapterIndex: chapterIndex,
              pageIndex: viewportState.pageIndex,
              pageCount: viewportState.pageCount,
              zoomScale: viewportState.zoomScale ?? logicalPosition?.zoomScale,
              panDx: viewportState.panDx ?? logicalPosition?.panDx,
              panDy: viewportState.panDy ?? logicalPosition?.panDy,
              pageScrollOffset: viewportState.scrollOffset,
              progressRatio: ratio,
            )
            : ReaderSurfacePosition.image(
              chapterIndex: chapterIndex,
              imageIndex: viewportState.pageIndex,
              imageCount: viewportState.pageCount,
              scrollOffset: viewportState.scrollOffset,
              maxScrollExtent: viewportState.maxScrollExtent,
              progressRatio: ratio,
            ),
      ReaderViewportStateKind.audio => ReaderSurfacePosition.audio(
        chapterIndex: chapterIndex,
        positionMs:
            viewportState.audioPositionMs ??
            audioPlaybackPosition.inMilliseconds,
        durationMs:
            viewportState.audioDurationMs ??
            audioPlaybackDuration.inMilliseconds,
        speed: viewportState.audioSpeed ?? audioPlaybackSpeed,
        progressRatio: ratio,
      ),
    };
  }

  ReaderSurfaceRestorePlan? restoreFromProgress(ReadingProgress? progress) {
    if (progress == null) {
      return null;
    }
    return restoreFromSnapshot(
      snapshot: progress.positionSnapshot,
      chapterIndex: progress.chapterIndex,
      chapterPositionRatio: progress.chapterPositionRatio,
    );
  }

  ReaderSurfaceRestorePlan restoreFromSnapshot({
    required ReaderPositionSnapshot? snapshot,
    required int chapterIndex,
    required double chapterPositionRatio,
  }) {
    return ReaderSurfaceRestorePlan(
      position: mapper.fromSnapshot(
        snapshot: snapshot,
        chapterIndex: chapterIndex,
        chapterPositionRatio: chapterPositionRatio,
      ),
    );
  }

  ReaderPositionSnapshot toSnapshot(ReaderSurfacePosition position) {
    return mapper.toSnapshot(position);
  }

  ReaderSurfaceDiagnostics diagnostics(ReaderSurfacePosition position) {
    return ReaderSurfaceDiagnostics(position: position);
  }

  bool _isDocumentSurface(ReaderHybridSubMode? hybridSubMode) {
    return switch (hybridSubMode) {
      ReaderHybridSubMode.pictureBook => false,
      ReaderHybridSubMode.pdf ||
      ReaderHybridSubMode.epubFixed ||
      ReaderHybridSubMode.documentImage ||
      null => true,
    };
  }
}

class ReaderSurfaceRestorePlan {
  const ReaderSurfaceRestorePlan({required this.position});

  final ReaderSurfacePosition position;

  ReaderSurfaceKind get kind => position.kind;
  double get progressRatio => position.progressRatio;

  int? get pageIndex {
    return switch (position.kind) {
      ReaderSurfaceKind.text => position.pageIndex,
      ReaderSurfaceKind.image => position.imageIndex,
      ReaderSurfaceKind.document => position.documentPageIndex,
      ReaderSurfaceKind.audio => null,
    };
  }

  int? get pageCount {
    return switch (position.kind) {
      ReaderSurfaceKind.text => position.pageCount,
      ReaderSurfaceKind.image => position.imageCount,
      ReaderSurfaceKind.document => position.documentPageCount,
      ReaderSurfaceKind.audio => null,
    };
  }

  Duration? get audioPosition {
    final value = position.audioPositionMs;
    return value == null ? null : Duration(milliseconds: value);
  }

  Duration? get audioDuration {
    final value = position.audioDurationMs;
    return value == null ? null : Duration(milliseconds: value);
  }
}

class ReaderSurfaceDiagnostics {
  const ReaderSurfaceDiagnostics({required this.position});

  final ReaderSurfacePosition position;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'surfaceKind': position.kind.name,
      'chapterIndex': position.chapterIndex,
      'progressRatio': position.progressRatio,
      if (position.pageIndex != null) 'textPageIndex': position.pageIndex,
      if (position.pageCount != null) 'textPageCount': position.pageCount,
      if (position.imageIndex != null) 'imageIndex': position.imageIndex,
      if (position.imageCount != null) 'imageCount': position.imageCount,
      if (position.documentPageIndex != null)
        'documentPageIndex': position.documentPageIndex,
      if (position.documentPageCount != null)
        'documentPageCount': position.documentPageCount,
      if (position.zoomScale != null) 'zoomScale': position.zoomScale,
      if (position.panDx != null) 'panDx': position.panDx,
      if (position.panDy != null) 'panDy': position.panDy,
      if (position.audioPositionMs != null)
        'audioPositionMs': position.audioPositionMs,
      if (position.audioDurationMs != null)
        'audioDurationMs': position.audioDurationMs,
      if (position.audioSpeed != null) 'audioSpeed': position.audioSpeed,
    };
  }
}
