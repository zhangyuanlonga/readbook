import 'reading_record_metrics.dart';
import 'reading_record_service.dart';

class ReaderReadingRecordSession {
  const ReaderReadingRecordSession({
    required this.bookId,
    required this.sourceId,
    required this.detailUrl,
    required this.bookTitle,
    this.bookAuthor,
    this.coverUrl,
    required this.chapterId,
    this.chapterTitle,
    this.chapterIndex,
    required this.chapterUrl,
    required this.startAt,
    required this.startPositionRatio,
    required this.furthestPositionRatio,
  });

  final String bookId;
  final String sourceId;
  final String detailUrl;
  final String bookTitle;
  final String? bookAuthor;
  final String? coverUrl;
  final String chapterId;
  final String? chapterTitle;
  final int? chapterIndex;
  final String chapterUrl;
  final DateTime startAt;
  final double startPositionRatio;
  final double furthestPositionRatio;

  ReaderReadingRecordSession copyWith({
    String? bookId,
    String? sourceId,
    String? detailUrl,
    String? bookTitle,
    String? bookAuthor,
    String? coverUrl,
    String? chapterId,
    String? chapterTitle,
    int? chapterIndex,
    String? chapterUrl,
    DateTime? startAt,
    double? startPositionRatio,
    double? furthestPositionRatio,
  }) {
    return ReaderReadingRecordSession(
      bookId: bookId ?? this.bookId,
      sourceId: sourceId ?? this.sourceId,
      detailUrl: detailUrl ?? this.detailUrl,
      bookTitle: bookTitle ?? this.bookTitle,
      bookAuthor: bookAuthor ?? this.bookAuthor,
      coverUrl: coverUrl ?? this.coverUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      startAt: startAt ?? this.startAt,
      startPositionRatio: startPositionRatio ?? this.startPositionRatio,
      furthestPositionRatio:
          furthestPositionRatio ?? this.furthestPositionRatio,
    );
  }
}

class ReaderReadingRecordSessionStartResult {
  const ReaderReadingRecordSessionStartResult({
    required this.session,
    this.cancelAutoCommitTimer = false,
    this.scheduleAutoCommitTimer = false,
  });

  final ReaderReadingRecordSession? session;
  final bool cancelAutoCommitTimer;
  final bool scheduleAutoCommitTimer;
}

class ReaderReadingRecordCoordinator {
  const ReaderReadingRecordCoordinator();

  bool canTrackSession({
    required bool readingRecordEnabled,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasVisibleReaderContent,
    required String? sourceId,
    required String? detailUrl,
    required String bookTitle,
  }) {
    final normalizedSourceId = (sourceId ?? '').trim();
    final normalizedDetailUrl = (detailUrl ?? '').trim();
    final normalizedTitle = bookTitle.trim();

    if (!readingRecordEnabled) {
      return false;
    }
    if (isBootstrapping || isLoadingContent || hasError) {
      return false;
    }
    if (!hasVisibleReaderContent) {
      return false;
    }
    return normalizedSourceId.isNotEmpty &&
        normalizedDetailUrl.isNotEmpty &&
        normalizedTitle.isNotEmpty;
  }

  ReaderReadingRecordSessionStartResult startOrUpdateSession({
    required bool readingRecordEnabled,
    required bool isBootstrapping,
    required bool isLoadingContent,
    required bool hasError,
    required bool hasVisibleReaderContent,
    required String? sourceId,
    required String? detailUrl,
    required String bookTitle,
    required String currentBookId,
    required String chapterId,
    required String? chapterUrl,
    required String? chapterTitle,
    required int? chapterIndex,
    required String? bookAuthor,
    required String? coverUrl,
    required double initialRatio,
    required DateTime now,
    ReaderReadingRecordSession? existingSession,
  }) {
    if (!canTrackSession(
      readingRecordEnabled: readingRecordEnabled,
      isBootstrapping: isBootstrapping,
      isLoadingContent: isLoadingContent,
      hasError: hasError,
      hasVisibleReaderContent: hasVisibleReaderContent,
      sourceId: sourceId,
      detailUrl: detailUrl,
      bookTitle: bookTitle,
    )) {
      return const ReaderReadingRecordSessionStartResult(
        session: null,
        cancelAutoCommitTimer: true,
      );
    }

    final normalizedChapterUrl = (chapterUrl ?? '').trim();
    if (existingSession != null &&
        existingSession.bookId == currentBookId &&
        existingSession.chapterId == chapterId &&
        existingSession.chapterUrl == normalizedChapterUrl) {
      return ReaderReadingRecordSessionStartResult(
        session: syncProgress(session: existingSession, ratio: initialRatio),
        scheduleAutoCommitTimer: true,
      );
    }

    final startRatio = initialRatio.clamp(0.0, 1.0).toDouble();
    final nextSession = ReaderReadingRecordSession(
      bookId: currentBookId,
      sourceId: sourceId!.trim(),
      detailUrl: detailUrl!.trim(),
      bookTitle: bookTitle.trim(),
      bookAuthor: _normalizeOptionalText(bookAuthor),
      coverUrl: _normalizeOptionalText(coverUrl),
      chapterId: chapterId.trim(),
      chapterTitle: _normalizeOptionalText(chapterTitle),
      chapterIndex: chapterIndex,
      chapterUrl: normalizedChapterUrl,
      startAt: now,
      startPositionRatio: startRatio,
      furthestPositionRatio: startRatio,
    );
    return ReaderReadingRecordSessionStartResult(
      session: nextSession,
      scheduleAutoCommitTimer: true,
    );
  }

  ReaderReadingRecordSession syncProgress({
    required ReaderReadingRecordSession session,
    required double ratio,
  }) {
    final currentRatio = ratio.clamp(0.0, 1.0).toDouble();
    if (currentRatio <= session.furthestPositionRatio) {
      return session;
    }
    return session.copyWith(furthestPositionRatio: currentRatio);
  }

  ReadingRecordCommitInput? buildCommitInput({
    required bool readingRecordEnabled,
    required ReaderReadingRecordSession? session,
    required DateTime endAt,
    required double endRatio,
    required int chapterLength,
    required bool isMangaChapter,
  }) {
    if (!readingRecordEnabled || session == null) {
      return null;
    }

    final clampedEndRatio = endRatio.clamp(0.0, 1.0).toDouble();
    final readChars = estimateSessionReadChars(
      chapterLength: chapterLength,
      startRatio: session.startPositionRatio,
      endRatio: clampedEndRatio,
      furthestRatio: session.furthestPositionRatio,
      countAsText: !isMangaChapter,
    );

    return ReadingRecordCommitInput(
      bookId: session.bookId,
      sourceId: session.sourceId,
      detailUrl: session.detailUrl,
      bookTitle: session.bookTitle,
      bookAuthor: session.bookAuthor,
      coverUrl: session.coverUrl,
      chapterId: session.chapterId,
      chapterTitle: session.chapterTitle,
      chapterIndex: session.chapterIndex,
      chapterUrl: session.chapterUrl,
      startAt: session.startAt,
      endAt: endAt,
      readChars: readChars,
      startPositionRatio: session.startPositionRatio,
      endPositionRatio: clampedEndRatio,
    );
  }

  String? _normalizeOptionalText(String? value) {
    final normalized = (value ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
