import 'dart:async';

import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/chapter.dart';
import 'chapter_content_service.dart';

class ChapterCacheCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class ChapterCacheProgress {
  const ChapterCacheProgress({
    required this.done,
    required this.total,
    required this.failed,
    required this.cachedBefore,
    required this.isCancelled,
    required this.isCompleted,
    this.currentChapterTitle,
    this.currentChapterIndex,
  });

  final int done;
  final int total;
  final int failed;
  final int cachedBefore;
  final bool isCancelled;
  final bool isCompleted;
  final String? currentChapterTitle;
  final int? currentChapterIndex;

  int get success => done - failed;
}

class ChapterCacheService {
  ChapterCacheService({
    AppDatabase? database,
    ChapterContentService? contentService,
    AppLogger? logger,
  }) : _database = database ?? AppDatabase.instance,
       _contentService = contentService ?? ChapterContentService(),
       _logger = logger ?? AppLogger.instance;

  final AppDatabase _database;
  final ChapterContentService _contentService;
  final AppLogger _logger;

  Stream<ChapterCacheProgress> cacheRange({
    required String bookId,
    required String sourceId,
    required List<Chapter> chapters,
    required int startIndex,
    required int endIndex,
    ChapterCacheCancellationToken? cancellationToken,
    Duration perChapterTimeout = const Duration(seconds: 20),
  }) async* {
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = sourceId.trim();

    if (normalizedBookId.isEmpty || normalizedSourceId.isEmpty) {
      yield const ChapterCacheProgress(
        done: 0,
        total: 0,
        failed: 0,
        cachedBefore: 0,
        isCancelled: false,
        isCompleted: true,
      );
      return;
    }

    if (chapters.isEmpty) {
      yield const ChapterCacheProgress(
        done: 0,
        total: 0,
        failed: 0,
        cachedBefore: 0,
        isCancelled: false,
        isCompleted: true,
      );
      return;
    }

    final start = startIndex.clamp(0, chapters.length - 1);
    final end = endIndex.clamp(0, chapters.length - 1);
    final rangeStart = start <= end ? start : end;
    final rangeEnd = start <= end ? end : start;

    final targetChapters = chapters.sublist(rangeStart, rangeEnd + 1);

    Set<String> cachedKeys = <String>{};
    try {
      cachedKeys = await _database.getCachedChapterCacheKeysForBook(
        normalizedBookId,
      );
    } catch (error) {
      _logger.warn(
        'Chapter cache prefetch failed',
        context: {'bookId': normalizedBookId, 'error': error.toString()},
      );
    }

    final cachedBefore = cachedKeys.length;

    var done = 0;
    var failed = 0;

    yield ChapterCacheProgress(
      done: done,
      total: targetChapters.length,
      failed: failed,
      cachedBefore: cachedBefore,
      isCancelled: cancellationToken?.isCancelled ?? false,
      isCompleted: false,
    );

    for (final chapter in targetChapters) {
      if (cancellationToken?.isCancelled ?? false) {
        yield ChapterCacheProgress(
          done: done,
          total: targetChapters.length,
          failed: failed,
          cachedBefore: cachedBefore,
          isCancelled: true,
          isCompleted: false,
          currentChapterTitle: chapter.title,
          currentChapterIndex: chapter.index,
        );
        return;
      }

      final chapterUrl = chapter.chapterUrl.trim();
      final cacheKey = '$normalizedSourceId|$chapterUrl';

      if (chapterUrl.isEmpty) {
        done++;
        failed++;
        yield ChapterCacheProgress(
          done: done,
          total: targetChapters.length,
          failed: failed,
          cachedBefore: cachedBefore,
          isCancelled: false,
          isCompleted: false,
          currentChapterTitle: chapter.title,
          currentChapterIndex: chapter.index,
        );
        continue;
      }

      if (cachedKeys.contains(cacheKey)) {
        done++;
        yield ChapterCacheProgress(
          done: done,
          total: targetChapters.length,
          failed: failed,
          cachedBefore: cachedBefore,
          isCancelled: false,
          isCompleted: false,
          currentChapterTitle: chapter.title,
          currentChapterIndex: chapter.index,
        );
        await Future<void>.delayed(const Duration(milliseconds: 1));
        continue;
      }

      try {
        await _contentService
            .load(
              sourceId: normalizedSourceId,
              chapterUrl: chapterUrl,
              bookId: normalizedBookId,
              chapterIndex: chapter.index,
              chapterTitle: chapter.title,
            )
            .timeout(perChapterTimeout);

        cachedKeys.add(cacheKey);
      } catch (error) {
        failed++;
        _logger.warn(
          'Chapter cache failed',
          context: {
            'bookId': normalizedBookId,
            'sourceId': normalizedSourceId,
            'chapterIndex': chapter.index,
            'chapterUrl': chapterUrl,
            'error': error.toString(),
          },
        );
      } finally {
        done++;
      }

      yield ChapterCacheProgress(
        done: done,
        total: targetChapters.length,
        failed: failed,
        cachedBefore: cachedBefore,
        isCancelled: false,
        isCompleted: false,
        currentChapterTitle: chapter.title,
        currentChapterIndex: chapter.index,
      );

      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    yield ChapterCacheProgress(
      done: done,
      total: targetChapters.length,
      failed: failed,
      cachedBefore: cachedBefore,
      isCancelled: false,
      isCompleted: true,
    );
  }
}
