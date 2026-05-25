import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import 'reader_content_session.dart';
import 'reader_reading_record_coordinator.dart';
import 'reader_session_state.dart';

class ReaderContentSessionResolver {
  const ReaderContentSessionResolver();

  ReaderContentSession? resolve({
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
    required List<Chapter> chapters,
    required ReaderSessionState? sessionState,
    required ReadingProgress? bootstrapProgress,
    required ReaderReadingRecordSession? readingRecordSession,
  }) {
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = (sourceId ?? '').trim();
    final normalizedDetailUrl = (detailUrl ?? '').trim();
    final normalizedChapterId = chapterId.trim();

    if (normalizedBookId.isEmpty ||
        normalizedSourceId.isEmpty ||
        normalizedDetailUrl.isEmpty ||
        normalizedChapterId.isEmpty) {
      return null;
    }

    return ReaderContentSession(
      contentMode: contentMode,
      bookId: normalizedBookId,
      sourceId: normalizedSourceId,
      detailUrl: normalizedDetailUrl,
      bookTitle: bookTitle.trim(),
      bookAuthor: _normalizeOptional(bookAuthor),
      bookCoverUrl: _normalizeOptional(bookCoverUrl),
      chapterId: normalizedChapterId,
      chapterUrl: _normalizeOptional(chapterUrl),
      chapterTitle: _normalizeOptional(chapterTitle),
      chapterIndex: chapterIndex,
      resolvedContentType: _normalizeOptional(resolvedContentType),
      hybridSubMode: hybridSubMode,
      sourceFilePath: _normalizeOptional(sourceFilePath),
      totalPageCount: totalPageCount,
      audioUrl: _normalizeOptional(audioUrl),
      audioManifestUrl: _normalizeOptional(audioManifestUrl),
      audioHeaders: Map<String, String>.unmodifiable(audioHeaders),
      chapters: List<Chapter>.unmodifiable(chapters),
      sessionState: sessionState,
      bootstrapProgress: bootstrapProgress,
      readingRecordSession: readingRecordSession,
    );
  }

  String? _normalizeOptional(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
