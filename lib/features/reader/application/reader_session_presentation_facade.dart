import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import 'content_provider.dart';
import 'reader_content_session.dart';
import 'reader_content_session_resolver.dart';
import 'reader_mode_capabilities.dart';
import 'reader_mode_model.dart';
import 'reader_reading_record_coordinator.dart';
import 'reader_session_state.dart';
import 'reader_viewport_state.dart';
import 'reader_viewport_state_resolver.dart';

/// 阅读器会话表现门面。
///
/// `ReaderPage` 仍然负责收集当前 widget / controller 状态，但会话构造、
/// mode capability 和 viewport state 的解析统一从这里进入，后续继续拆页
/// 面时可以把更多 seed 构造逻辑迁入 application 层。
class ReaderSessionPresentationFacade {
  const ReaderSessionPresentationFacade({
    this.contentSessionResolver = const ReaderContentSessionResolver(),
    this.modeCapabilitiesResolver = const ReaderModeCapabilitiesResolver(),
    this.viewportStateResolver = const ReaderViewportStateResolver(),
  });

  final ReaderContentSessionResolver contentSessionResolver;
  final ReaderModeCapabilitiesResolver modeCapabilitiesResolver;
  final ReaderViewportStateResolver viewportStateResolver;

  ReaderContentSession? resolveContentSession({
    required ReaderContentMode contentMode,
    required String bookId,
    required String? sourceId,
    required String? detailUrl,
    required String bookTitle,
    required String? bookAuthor,
    required String? bookCoverUrl,
    required String chapterId,
    required String? chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required String? resolvedContentType,
    required ReaderHybridSubMode? hybridSubMode,
    required String? sourceFilePath,
    required int? totalPageCount,
    required String? audioUrl,
    required String? audioManifestUrl,
    required Map<String, String> audioHeaders,
    required String? executionContext,
    required List<Chapter> chapters,
    required ReaderSessionState? sessionState,
    required ReadingProgress? bootstrapProgress,
    required ReaderReadingRecordSession? readingRecordSession,
  }) {
    return contentSessionResolver.resolve(
      contentMode: contentMode,
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookTitle: bookTitle,
      bookAuthor: bookAuthor,
      bookCoverUrl: bookCoverUrl,
      chapterId: chapterId,
      chapterUrl: chapterUrl,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      resolvedContentType: resolvedContentType,
      hybridSubMode: hybridSubMode,
      sourceFilePath: sourceFilePath,
      totalPageCount: totalPageCount,
      audioUrl: audioUrl,
      audioManifestUrl: audioManifestUrl,
      audioHeaders: audioHeaders,
      executionContext: executionContext,
      chapters: chapters,
      sessionState: sessionState,
      bootstrapProgress: bootstrapProgress,
      readingRecordSession: readingRecordSession,
    );
  }

  ReaderModeCapabilities resolveModeCapabilities({
    required ReaderContentMode contentMode,
    required ContentCapabilities contentCapabilities,
    required bool hasInlineImageParagraphs,
  }) {
    return modeCapabilitiesResolver.resolve(
      contentMode: contentMode,
      contentCapabilities: contentCapabilities,
      hasInlineImageParagraphs: hasInlineImageParagraphs,
    );
  }

  ReaderViewportState resolveViewportState({
    required ReaderContentMode contentMode,
    required ReaderModeModel mode,
    required double chapterPositionRatio,
    int? pageIndex,
    int? pageCount,
    double? scrollOffset,
    double? maxScrollExtent,
  }) {
    return viewportStateResolver.resolve(
      contentMode: contentMode,
      mode: mode,
      chapterPositionRatio: chapterPositionRatio,
      pageIndex: pageIndex,
      pageCount: pageCount,
      scrollOffset: scrollOffset,
      maxScrollExtent: maxScrollExtent,
    );
  }
}
