import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/reading_progress.dart';
import 'reader_reading_record_coordinator.dart';
import 'reader_session_state.dart';

enum ReaderContentMode { text, comic, audio }

class ReaderContentSession {
  const ReaderContentSession({
    required this.contentMode,
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.bookCoverUrl,
    required this.chapterId,
    this.chapterUrl,
    this.chapterTitle,
    this.chapterIndex,
    this.resolvedContentType,
    this.audioUrl,
    this.audioManifestUrl,
    this.audioHeaders = const <String, String>{},
    this.chapters = const <Chapter>[],
    this.sessionState,
    this.bootstrapProgress,
    this.readingRecordSession,
  });

  final ReaderContentMode contentMode;
  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? bookCoverUrl;
  final String chapterId;
  final String? chapterUrl;
  final String? chapterTitle;
  final int? chapterIndex;
  final String? resolvedContentType;
  final String? audioUrl;
  final String? audioManifestUrl;
  final Map<String, String> audioHeaders;
  final List<Chapter> chapters;
  final ReaderSessionState? sessionState;
  final ReadingProgress? bootstrapProgress;
  final ReaderReadingRecordSession? readingRecordSession;

  ReaderContentSession copyWith({
    ReaderContentMode? contentMode,
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    Object? bookAuthor = _sentinel,
    Object? bookCoverUrl = _sentinel,
    String? chapterId,
    Object? chapterUrl = _sentinel,
    Object? chapterTitle = _sentinel,
    Object? chapterIndex = _sentinel,
    Object? resolvedContentType = _sentinel,
    Object? audioUrl = _sentinel,
    Object? audioManifestUrl = _sentinel,
    Map<String, String>? audioHeaders,
    List<Chapter>? chapters,
    Object? sessionState = _sentinel,
    Object? bootstrapProgress = _sentinel,
    Object? readingRecordSession = _sentinel,
  }) {
    return ReaderContentSession(
      contentMode: contentMode ?? this.contentMode,
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor:
          identical(bookAuthor, _sentinel) ? this.bookAuthor : bookAuthor as String?,
      bookCoverUrl:
          identical(bookCoverUrl, _sentinel)
              ? this.bookCoverUrl
              : bookCoverUrl as String?,
      chapterId: chapterId ?? this.chapterId,
      chapterUrl:
          identical(chapterUrl, _sentinel) ? this.chapterUrl : chapterUrl as String?,
      chapterTitle:
          identical(chapterTitle, _sentinel)
              ? this.chapterTitle
              : chapterTitle as String?,
      chapterIndex:
          identical(chapterIndex, _sentinel) ? this.chapterIndex : chapterIndex as int?,
      resolvedContentType:
          identical(resolvedContentType, _sentinel)
              ? this.resolvedContentType
              : resolvedContentType as String?,
      audioUrl:
          identical(audioUrl, _sentinel) ? this.audioUrl : audioUrl as String?,
      audioManifestUrl:
          identical(audioManifestUrl, _sentinel)
              ? this.audioManifestUrl
              : audioManifestUrl as String?,
      audioHeaders: audioHeaders ?? this.audioHeaders,
      chapters: chapters ?? this.chapters,
      sessionState:
          identical(sessionState, _sentinel)
              ? this.sessionState
              : sessionState as ReaderSessionState?,
      bootstrapProgress:
          identical(bootstrapProgress, _sentinel)
              ? this.bootstrapProgress
              : bootstrapProgress as ReadingProgress?,
      readingRecordSession:
          identical(readingRecordSession, _sentinel)
              ? this.readingRecordSession
              : readingRecordSession as ReaderReadingRecordSession?,
    );
  }
}

const Object _sentinel = Object();
