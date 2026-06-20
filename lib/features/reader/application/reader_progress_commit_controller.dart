import '../../../domain/entities/reading_progress.dart';
import 'local/local_reader_identity.dart';
import 'reader_content_session.dart';
import 'reader_logical_position.dart';
import 'reader_surface_position_runtime.dart';
import 'reader_viewport_state.dart';

class ReaderProgressCommitInput {
  const ReaderProgressCommitInput({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.positionRatio,
    required this.viewportState,
    required this.contentMode,
    this.hybridSubMode,
    this.logicalPosition,
    this.audioPlaybackPosition = Duration.zero,
    this.audioPlaybackDuration = Duration.zero,
    this.audioPlaybackSpeed = 1.0,
    required this.updatedAt,
  });

  final String bookId;
  final String? sourceId;
  final String? detailUrl;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final int? chapterIndex;
  final double positionRatio;
  final ReaderViewportState viewportState;
  final ReaderContentMode contentMode;
  final ReaderHybridSubMode? hybridSubMode;
  final ReaderLogicalPosition? logicalPosition;
  final Duration audioPlaybackPosition;
  final Duration audioPlaybackDuration;
  final double audioPlaybackSpeed;
  final DateTime updatedAt;
}

class ReaderProgressCommitController {
  const ReaderProgressCommitController({
    this.surfacePositionRuntime = const ReaderSurfacePositionRuntime(),
  });

  final ReaderSurfacePositionRuntime surfacePositionRuntime;

  ReadingProgress? buildProgress(ReaderProgressCommitInput input) {
    final sourceId = input.sourceId;
    final detailUrl = input.detailUrl;
    final chapterUrl = input.chapterUrl;
    final chapterTitle = input.chapterTitle;
    final chapterIndex = input.chapterIndex;
    if (sourceId == null ||
        detailUrl == null ||
        chapterUrl == null ||
        chapterTitle == null ||
        chapterIndex == null) {
      return null;
    }

    final normalizedDetailUrl = normalizeLocalDetailUrlForProgress(
      sourceId: sourceId,
      bookId: input.bookId,
      detailUrl: detailUrl,
    );
    final normalizedChapterUrl = normalizeLocalChapterUrlForProgress(
      sourceId: sourceId,
      chapterId: input.chapterId,
      chapterUrl: chapterUrl,
    );
    final surfacePosition = surfacePositionRuntime.capture(
      viewportState: input.viewportState,
      contentMode: input.contentMode,
      chapterIndex: chapterIndex,
      hybridSubMode: input.hybridSubMode,
      logicalPosition: input.logicalPosition,
      audioPlaybackPosition: input.audioPlaybackPosition,
      audioPlaybackDuration: input.audioPlaybackDuration,
      audioPlaybackSpeed: input.audioPlaybackSpeed,
    );
    return ReadingProgress(
      bookId: input.bookId,
      sourceId: sourceId,
      detailUrl: normalizedDetailUrl,
      chapterId: input.chapterId,
      chapterUrl: normalizedChapterUrl,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      updatedAt: input.updatedAt,
      chapterPositionRatio: input.positionRatio,
      logicalPosition: input.logicalPosition?.copyWith(
        chapterPositionRatio: input.positionRatio,
        pageIndex: input.viewportState.pageIndex,
        totalPageCount: input.viewportState.pageCount,
        viewportMode: input.viewportState.kind.name,
        zoomScale: input.viewportState.zoomScale,
        panDx: input.viewportState.panDx,
        panDy: input.viewportState.panDy,
      ),
      positionSnapshot: surfacePositionRuntime.toSnapshot(surfacePosition),
    );
  }

  String normalizeLocalDetailUrlForProgress({
    required String sourceId,
    required String bookId,
    required String detailUrl,
  }) {
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return detailUrl;
    }
    final normalized = detailUrl.trim();
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    final normalizedBookId = bookId.trim();
    if (normalizedBookId.isEmpty) {
      return normalized;
    }
    return LocalReaderIdentity.buildBookDetailUrl(normalizedBookId);
  }

  String normalizeLocalChapterUrlForProgress({
    required String sourceId,
    required String chapterId,
    required String chapterUrl,
  }) {
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return chapterUrl;
    }
    final normalized = chapterUrl.trim();
    if (LocalReaderIdentity.isLocalSchemeUrl(normalized)) {
      return normalized;
    }
    final normalizedChapterId = chapterId.trim();
    if (_isPlaceholderChapterId(normalizedChapterId)) {
      return normalized;
    }
    return LocalReaderIdentity.buildChapterUrl(normalizedChapterId);
  }

  bool _isPlaceholderChapterId(String chapterId) {
    final normalized = chapterId.trim();
    return normalized.isEmpty ||
        normalized == 'bootstrap' ||
        normalized == 'unknown-chapter' ||
        normalized == 'unknown-local-chapter';
  }
}
