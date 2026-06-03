import 'package:freezed_annotation/freezed_annotation.dart';

import 'reader_logical_position.dart';
import '../../../domain/entities/reading_progress.dart';

part 'reader_session_state.freezed.dart';

enum TextReaderRendererKind { scroll, paged }

@freezed
abstract class ReaderSessionGenerationState
    with _$ReaderSessionGenerationState {
  const factory ReaderSessionGenerationState({
    @Default(0) int chapterContentGeneration,
    @Default(0) int preloadGeneration,
    @Default(0) int paginationGeneration,
  }) = _ReaderSessionGenerationState;
}

@freezed
abstract class ReaderVisiblePosition with _$ReaderVisiblePosition {
  const factory ReaderVisiblePosition({
    int? pageIndex,
    int? pageCount,
    double? scrollOffset,
    double? maxScrollExtent,
  }) = _ReaderVisiblePosition;
}

@freezed
abstract class ReaderViewportSession with _$ReaderViewportSession {
  const ReaderViewportSession._();

  const factory ReaderViewportSession({
    required String viewportMode,
    int? pageIndex,
    int? pageCount,
    double? scrollOffset,
    double? maxScrollExtent,
    double? zoomScale,
    double? panDx,
    double? panDy,
    int? audioPositionMs,
    int? audioDurationMs,
    double? audioSpeed,
  }) = _ReaderViewportSession;

  ReaderPositionSnapshot toPositionSnapshot() {
    return ReaderPositionSnapshot(
      viewportMode: viewportMode,
      pageIndex: pageIndex,
      pageCount: pageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
      zoomScale: zoomScale,
      panDx: panDx,
      panDy: panDy,
      audioPositionMs: audioPositionMs,
      audioDurationMs: audioDurationMs,
      audioSpeed: audioSpeed,
    );
  }
}

@freezed
abstract class ReaderSessionState with _$ReaderSessionState {
  const factory ReaderSessionState({
    required int currentChapterIndex,
    required String currentChapterId,
    required String currentChapterUrl,
    required String currentChapterTitle,
    required ReaderLogicalPosition logicalPosition,
    required ReaderVisiblePosition visiblePosition,
    required ReaderViewportSession viewportSession,
    required TextReaderRendererKind rendererKind,
    required bool isAutoReading,
    required bool isChapterTransitioning,
  }) = _ReaderSessionState;
}
