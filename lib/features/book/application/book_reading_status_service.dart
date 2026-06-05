import 'dart:math' as math;

import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/bookshelf_book.dart';
import '../../../domain/entities/chapter.dart';
import '../../../domain/entities/local_book.dart';
import '../../../domain/entities/reading_progress.dart';
import '../../../domain/repositories/local_book_repository.dart';
import '../../reader/application/local/local_reader_identity.dart';
import '../../reader/application/reader_preferences_service.dart';
import 'book_detail_service.dart';

/// 书籍阅读状态的统一业务枚举。
///
/// 当前项目没有单独的“阅读状态表”，未读/阅读中/已读完都由
/// [ReadingProgress] 推导或写入：无进度即未读，有进度即阅读中，
/// 进度到末尾即已读完。书架、详情页和后续书籍编辑器都应复用这里，
/// 避免同一状态在不同端出现不同判断。
enum BookReadingStatus { unread, reading, finished }

extension BookReadingStatusLabel on BookReadingStatus {
  String get label {
    return switch (this) {
      BookReadingStatus.unread => '未读',
      BookReadingStatus.reading => '阅读中',
      BookReadingStatus.finished => '已读完',
    };
  }
}

class BookReadingStatusMarkResult {
  const BookReadingStatusMarkResult({
    required this.status,
    required this.progress,
    this.cachedChapterCount,
  });

  final BookReadingStatus status;
  final ReadingProgress? progress;

  /// 远程书在标记状态时可能顺手拉取目录，这里把章节数带回给书架缓存。
  final int? cachedChapterCount;
}

class _BookProgressAnchor {
  const _BookProgressAnchor({
    required this.chapterId,
    required this.chapterUrl,
    required this.chapterTitle,
    required this.chapterIndex,
    this.chapterCount,
  });

  final String chapterId;
  final String chapterUrl;
  final String chapterTitle;
  final int chapterIndex;
  final int? chapterCount;
}

class BookReadingStatusService {
  const BookReadingStatusService({
    required ReaderPreferencesService readerPreferencesService,
    BookDetailService? bookDetailService,
    LocalBookRepository? localBookRepository,
    Duration remoteCatalogLoadTimeout = const Duration(seconds: 8),
  }) : _readerPreferencesService = readerPreferencesService,
       _bookDetailService = bookDetailService,
       _localBookRepository = localBookRepository,
       _remoteCatalogLoadTimeout = remoteCatalogLoadTimeout;

  final ReaderPreferencesService _readerPreferencesService;
  final BookDetailService? _bookDetailService;
  final LocalBookRepository? _localBookRepository;
  final Duration _remoteCatalogLoadTimeout;

  BookReadingStatus resolveStatus({
    required ReadingProgress? progress,
    double? progressValue,
    bool hasProgressDisplay = false,
  }) {
    final normalizedProgressValue = progressValue?.clamp(0.0, 1.0);
    if ((normalizedProgressValue ?? 0) >= 0.999 ||
        (progress?.chapterPositionRatio ?? 0) >= 0.999) {
      return BookReadingStatus.finished;
    }

    final hasDisplayProgress =
        hasProgressDisplay &&
        normalizedProgressValue != null &&
        normalizedProgressValue > 0;
    final hasStoredProgress =
        progress != null &&
        (progress.chapterIndex > 0 || progress.chapterPositionRatio > 0);
    if (hasDisplayProgress || hasStoredProgress) {
      return BookReadingStatus.reading;
    }
    return BookReadingStatus.unread;
  }

  Future<BookReadingStatusMarkResult?> markBookshelfBookStatus({
    required BookshelfBook book,
    required BookReadingStatus status,
    ReadingProgress? existingProgress,
    LocalBook? localBook,
    int? cachedChapterCount,
  }) {
    return markStatus(
      bookId: book.bookId,
      sourceId: book.sourceId,
      detailUrl: book.detailUrl,
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
      status: status,
      existingProgress: existingProgress,
      localBook: localBook,
      cachedChapterCount: cachedChapterCount,
    );
  }

  Future<BookReadingStatusMarkResult?> markBookDetailStatus({
    required BookDetail detail,
    required List<Chapter> chapters,
    required bool chaptersComplete,
    required BookReadingStatus status,
    ReadingProgress? existingProgress,
    LocalBook? localBook,
  }) {
    return markStatus(
      bookId: detail.id,
      sourceId: detail.sourceId,
      detailUrl: detail.detailUrl,
      fallbackTitle: detail.title,
      fallbackAuthor: detail.author,
      status: status,
      chapters: chapters,
      chaptersComplete: chaptersComplete,
      existingProgress: existingProgress,
      localBook: localBook,
      cachedChapterCount: detail.totalChapterNum,
    );
  }

  Future<BookReadingStatusMarkResult?> markStatus({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required BookReadingStatus status,
    String? fallbackTitle,
    String? fallbackAuthor,
    List<Chapter> chapters = const <Chapter>[],
    bool chaptersComplete = true,
    ReadingProgress? existingProgress,
    LocalBook? localBook,
    int? cachedChapterCount,
  }) async {
    // “未读”本质上是清除阅读进度，不能额外保留一个独立状态，
    // 否则阅读器恢复、书架筛选和详情展示会出现三套状态来源。
    if (status == BookReadingStatus.unread) {
      await _readerPreferencesService.deleteProgress(bookId);
      return BookReadingStatusMarkResult(status: status, progress: null);
    }

    final progress = await buildMarkedProgress(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      status: status,
      chapters: chapters,
      chaptersComplete: chaptersComplete,
      existingProgress: existingProgress,
      localBook: localBook,
      cachedChapterCount: cachedChapterCount,
    );
    if (progress == null) {
      return null;
    }

    await _readerPreferencesService.saveProgress(progress.progress);
    return BookReadingStatusMarkResult(
      status: status,
      progress: progress.progress,
      cachedChapterCount: progress.cachedChapterCount,
    );
  }

  Future<({ReadingProgress progress, int? cachedChapterCount})?>
  buildMarkedProgress({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required BookReadingStatus status,
    String? fallbackTitle,
    String? fallbackAuthor,
    List<Chapter> chapters = const <Chapter>[],
    bool chaptersComplete = true,
    ReadingProgress? existingProgress,
    LocalBook? localBook,
    int? cachedChapterCount,
  }) async {
    // 标记阅读中/已读完时必须写入一个可恢复的章节锚点。
    // 优先使用现有进度或已加载目录；目录不完整时再拉完整目录，
    // 保证详情页和书架页保存出的进度都能被阅读器直接打开。
    final targetIndex = _resolveMarkedTargetIndex(
      status: status,
      existingProgress: existingProgress,
      chapters: chapters,
      chaptersComplete: chaptersComplete,
      localBook: localBook,
      cachedChapterCount: cachedChapterCount,
    );
    final anchor = await _resolveProgressAnchor(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      targetIndex: targetIndex,
      preferLast: status == BookReadingStatus.finished,
      chapters: chapters,
      chaptersComplete: chaptersComplete,
      existingProgress: existingProgress,
      localBook: localBook,
    );
    if (anchor == null) {
      return null;
    }

    final ratio = switch (status) {
      BookReadingStatus.finished => 1.0,
      BookReadingStatus.reading => _readingMarkProgressRatio(existingProgress),
      BookReadingStatus.unread => 0.0,
    };
    return (
      progress: ReadingProgress(
        bookId: bookId,
        sourceId: sourceId,
        detailUrl: detailUrl,
        chapterId: anchor.chapterId,
        chapterUrl: anchor.chapterUrl,
        chapterTitle: anchor.chapterTitle,
        chapterIndex: anchor.chapterIndex,
        updatedAt: DateTime.now(),
        chapterPositionRatio: ratio,
      ),
      cachedChapterCount: anchor.chapterCount,
    );
  }

  int _resolveMarkedTargetIndex({
    required BookReadingStatus status,
    required ReadingProgress? existingProgress,
    required List<Chapter> chapters,
    required bool chaptersComplete,
    required LocalBook? localBook,
    required int? cachedChapterCount,
  }) {
    if (status == BookReadingStatus.reading) {
      final existingIndex = existingProgress?.chapterIndex;
      return existingIndex != null && existingIndex > 0 ? existingIndex : 0;
    }

    final readableChapters = _readableChapters(chapters);
    if (chaptersComplete && readableChapters.isNotEmpty) {
      return readableChapters.last.index;
    }

    final knownChapterCount = cachedChapterCount ?? localBook?.chapterCount;
    if (knownChapterCount != null && knownChapterCount > 0) {
      return knownChapterCount - 1;
    }
    return existingProgress?.chapterIndex ?? 0;
  }

  double _readingMarkProgressRatio(ReadingProgress? existingProgress) {
    final ratio = existingProgress?.chapterPositionRatio.clamp(0.0, 0.98);
    if (ratio != null && ratio > 0) {
      return ratio;
    }
    return 0.001;
  }

  Future<_BookProgressAnchor?> _resolveProgressAnchor({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String? fallbackTitle,
    required String? fallbackAuthor,
    required int targetIndex,
    required bool preferLast,
    required List<Chapter> chapters,
    required bool chaptersComplete,
    required ReadingProgress? existingProgress,
    required LocalBook? localBook,
  }) async {
    // 锚点选择顺序要保持稳定：现有进度、本地图书索引、当前目录、
    // 远程完整目录、最后兜底现有进度。这样既减少网络请求，也避免
    // 桌面/Web/移动端在相同书籍上写出不同章节位置。
    final normalizedTargetIndex = math.max(0, targetIndex);
    if (existingProgress != null &&
        !preferLast &&
        existingProgress.chapterIndex == normalizedTargetIndex &&
        existingProgress.chapterId.trim().isNotEmpty &&
        existingProgress.chapterUrl.trim().isNotEmpty) {
      return _BookProgressAnchor(
        chapterId: existingProgress.chapterId,
        chapterUrl: existingProgress.chapterUrl,
        chapterTitle: existingProgress.chapterTitle,
        chapterIndex: existingProgress.chapterIndex,
      );
    }

    final localAnchor = await _resolveLocalProgressAnchor(
      bookId: bookId,
      sourceId: sourceId,
      targetIndex: normalizedTargetIndex,
      preferLast: preferLast,
      localBook: localBook,
    );
    if (localAnchor != null) {
      return localAnchor;
    }

    final chapterAnchor = _resolveChapterProgressAnchor(
      chapters: chapters,
      targetIndex: normalizedTargetIndex,
      preferLast: preferLast,
      chaptersComplete: chaptersComplete,
    );
    if (chapterAnchor != null) {
      return chapterAnchor;
    }

    final remoteAnchor = await _resolveRemoteProgressAnchor(
      bookId: bookId,
      sourceId: sourceId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      targetIndex: normalizedTargetIndex,
      preferLast: preferLast,
    );
    if (remoteAnchor != null) {
      return remoteAnchor;
    }

    if (existingProgress != null &&
        existingProgress.chapterId.trim().isNotEmpty &&
        existingProgress.chapterUrl.trim().isNotEmpty) {
      return _BookProgressAnchor(
        chapterId: existingProgress.chapterId,
        chapterUrl: existingProgress.chapterUrl,
        chapterTitle: existingProgress.chapterTitle,
        chapterIndex: existingProgress.chapterIndex,
      );
    }
    return null;
  }

  Future<_BookProgressAnchor?> _resolveLocalProgressAnchor({
    required String bookId,
    required String sourceId,
    required int targetIndex,
    required bool preferLast,
    required LocalBook? localBook,
  }) async {
    if (!LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return null;
    }

    final repository = _localBookRepository;
    if (repository == null) {
      return null;
    }
    final resolvedLocalBook =
        localBook ?? await repository.getBookById(bookId.trim());
    final chapterCount = resolvedLocalBook?.chapterCount ?? 0;
    final index =
        preferLast && chapterCount > 0 ? chapterCount - 1 : targetIndex;
    final chapter = await repository.getChapterMetaByIndex(
      bookId.trim(),
      index,
    );
    if (chapter == null) {
      return null;
    }
    return _BookProgressAnchor(
      chapterId: chapter.id,
      chapterUrl: chapter.sourceRef ?? chapter.id,
      chapterTitle: chapter.title,
      chapterIndex: chapter.chapterIndex,
      chapterCount: chapterCount > 0 ? chapterCount : null,
    );
  }

  _BookProgressAnchor? _resolveChapterProgressAnchor({
    required List<Chapter> chapters,
    required int targetIndex,
    required bool preferLast,
    required bool chaptersComplete,
  }) {
    final readableChapters = _readableChapters(chapters);
    if (readableChapters.isEmpty) {
      return null;
    }
    if (preferLast && !chaptersComplete) {
      return null;
    }

    final chapter =
        preferLast
            ? readableChapters.last
            : readableChapters.firstWhere(
              (item) => item.index == targetIndex,
              orElse: () => readableChapters.first,
            );
    return _BookProgressAnchor(
      chapterId: chapter.id,
      chapterUrl: chapter.chapterUrl,
      chapterTitle: chapter.title,
      chapterIndex: chapter.index,
      chapterCount: readableChapters.length,
    );
  }

  Future<_BookProgressAnchor?> _resolveRemoteProgressAnchor({
    required String bookId,
    required String sourceId,
    required String detailUrl,
    required String? fallbackTitle,
    required String? fallbackAuthor,
    required int targetIndex,
    required bool preferLast,
  }) async {
    final detailService = _bookDetailService;
    if (detailService == null ||
        LocalReaderIdentity.isLocalSourceId(sourceId)) {
      return null;
    }

    try {
      final result = await detailService
          .load(
            sourceId: sourceId,
            bookId: bookId,
            detailUrl: detailUrl,
            fallbackTitle: fallbackTitle,
            fallbackAuthor: fallbackAuthor,
            includeCatalog: true,
          )
          .timeout(_remoteCatalogLoadTimeout);
      final anchor = _resolveChapterProgressAnchor(
        chapters: result.chapters,
        targetIndex: targetIndex,
        preferLast: preferLast,
        chaptersComplete: result.catalogComplete,
      );
      if (anchor == null) {
        return null;
      }
      return _BookProgressAnchor(
        chapterId: anchor.chapterId,
        chapterUrl: anchor.chapterUrl,
        chapterTitle: anchor.chapterTitle,
        chapterIndex: anchor.chapterIndex,
        chapterCount: result.detail.totalChapterNum ?? result.chapters.length,
      );
    } catch (_) {
      return null;
    }
  }

  List<Chapter> _readableChapters(List<Chapter> chapters) {
    return chapters
        .where((chapter) => !chapter.isVolume)
        .toList(growable: false);
  }
}
