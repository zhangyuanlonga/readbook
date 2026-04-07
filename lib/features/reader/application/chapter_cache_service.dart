import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../domain/entities/chapter.dart';
import '../../source/application/source_health_service.dart';
import '../../source/application/source_runtime_facade.dart';
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
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    AppLogger? logger,
    int? maxConcurrentLoads,
  }) : _database = database ?? AppDatabase.instance,
       _contentService = contentService ?? ChapterContentService(),
       _sourceRuntimeFacade = sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService = sourceHealthService ?? SourceHealthService.instance,
       _logger = logger ?? AppLogger.instance,
       _maxConcurrentLoads = _resolveMaxConcurrentLoads(maxConcurrentLoads);

  final AppDatabase _database;
  final ChapterContentService _contentService;
  final SourceRuntimeFacade? _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final AppLogger _logger;
  final int _maxConcurrentLoads;

  static int _resolveMaxConcurrentLoads(int? override) {
    final value =
        override ??
        switch (defaultTargetPlatform) {
          TargetPlatform.android => 4,
          TargetPlatform.iOS => 2,
          TargetPlatform.macOS => 2,
          TargetPlatform.windows => 3,
          TargetPlatform.linux => 3,
          _ => 2,
        };
    return value.clamp(1, 6);
  }

  Stream<ChapterCacheProgress> cacheRange({
    required String bookId,
    required String sourceId,
    required List<Chapter> chapters,
    required int startIndex,
    required int endIndex,
    ChapterCacheCancellationToken? cancellationToken,
    Duration perChapterTimeout = const Duration(seconds: 20),
  }) {
    final controller = StreamController<ChapterCacheProgress>();

    unawaited(() async {
      await _cacheRangeInternal(
        controller: controller,
        bookId: bookId,
        sourceId: sourceId,
        chapters: chapters,
        startIndex: startIndex,
        endIndex: endIndex,
        cancellationToken: cancellationToken,
        perChapterTimeout: perChapterTimeout,
      );
    }());

    return controller.stream;
  }

  Future<void> _cacheRangeInternal({
    required StreamController<ChapterCacheProgress> controller,
    required String bookId,
    required String sourceId,
    required List<Chapter> chapters,
    required int startIndex,
    required int endIndex,
    ChapterCacheCancellationToken? cancellationToken,
    required Duration perChapterTimeout,
  }) async {
    final normalizedBookId = bookId.trim();
    final normalizedSourceId = sourceId.trim();

    void emit(ChapterCacheProgress progress) {
      if (!controller.isClosed) {
        controller.add(progress);
      }
    }

    if (normalizedBookId.isEmpty || normalizedSourceId.isEmpty) {
      emit(const ChapterCacheProgress(
        done: 0,
        total: 0,
        failed: 0,
        cachedBefore: 0,
        isCancelled: false,
        isCompleted: true,
      ));
      await controller.close();
      return;
    }

    if (chapters.isEmpty) {
      emit(const ChapterCacheProgress(
        done: 0,
        total: 0,
        failed: 0,
        cachedBefore: 0,
        isCancelled: false,
        isCompleted: true,
      ));
      await controller.close();
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
    var nextCursor = 0;
    final resolvedParallelism = await _resolveParallelism(
      sourceId: normalizedSourceId,
      chapterCount: targetChapters.length,
    );

    emit(ChapterCacheProgress(
      done: done,
      total: targetChapters.length,
      failed: failed,
      cachedBefore: cachedBefore,
      isCancelled: cancellationToken?.isCancelled ?? false,
      isCompleted: false,
    ));

    Future<void> processChapter(Chapter chapter) async {
      final chapterUrl = chapter.chapterUrl.trim();
      final cacheKey = '$normalizedSourceId|$chapterUrl';

      if (chapterUrl.isEmpty) {
        done++;
        failed++;
        emit(
          ChapterCacheProgress(
            done: done,
            total: targetChapters.length,
            failed: failed,
            cachedBefore: cachedBefore,
            isCancelled: cancellationToken?.isCancelled ?? false,
            isCompleted: false,
            currentChapterTitle: chapter.title,
            currentChapterIndex: chapter.index,
          ),
        );
        return;
      }

      if (cachedKeys.contains(cacheKey)) {
        done++;
        emit(
          ChapterCacheProgress(
            done: done,
            total: targetChapters.length,
            failed: failed,
            cachedBefore: cachedBefore,
            isCancelled: cancellationToken?.isCancelled ?? false,
            isCompleted: false,
            currentChapterTitle: chapter.title,
            currentChapterIndex: chapter.index,
          ),
        );
        return;
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

      emit(
        ChapterCacheProgress(
          done: done,
          total: targetChapters.length,
          failed: failed,
          cachedBefore: cachedBefore,
          isCancelled: cancellationToken?.isCancelled ?? false,
          isCompleted: false,
          currentChapterTitle: chapter.title,
          currentChapterIndex: chapter.index,
        ),
      );
    }

    Chapter? takeNextChapter() {
      if (cancellationToken?.isCancelled ?? false) {
        return null;
      }
      if (nextCursor >= targetChapters.length) {
        return null;
      }
      final chapter = targetChapters[nextCursor];
      nextCursor += 1;
      return chapter;
    }

    Future<void> worker() async {
      while (true) {
        final chapter = takeNextChapter();
        if (chapter == null) {
          return;
        }
        await processChapter(chapter);
      }
    }

    final parallelism =
        resolvedParallelism < targetChapters.length
            ? resolvedParallelism
            : targetChapters.length;
    await Future.wait<void>(
      List<Future<void>>.generate(parallelism, (_) => worker()),
    );

    emit(ChapterCacheProgress(
      done: done,
      total: targetChapters.length,
      failed: failed,
      cachedBefore: cachedBefore,
      isCancelled: cancellationToken?.isCancelled ?? false,
      isCompleted: true,
    ));
    await controller.close();
  }

  Future<int> _resolveParallelism({
    required String sourceId,
    required int chapterCount,
  }) async {
    if (chapterCount <= 1) {
      return 1;
    }

    final facade = _sourceRuntimeFacade;
    final registered = facade?.registeredScriptSourceById(sourceId);
    final capabilities =
        registered?.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet() ??
        const <String>{};
    final snapshot = _sourceHealthService.snapshotFor(sourceId);

    final declaresBrowser =
        capabilities.contains('browser') ||
        capabilities.contains('webview') ||
        capabilities.contains('challenge');
    final declaresHeavy =
        capabilities.contains('js-heavy') ||
        capabilities.contains('script-heavy');
    final hasBrowserRisk = snapshot.browserRiskCount > 0;
    final hasRepeatedFailures = snapshot.totalFailures >= 2;

    final suggested = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 3
            : 6,
      TargetPlatform.iOS =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 2
            : 4,
      TargetPlatform.macOS =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 2
            : 4,
      TargetPlatform.windows =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 3
            : 5,
      TargetPlatform.linux =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 3
            : 5,
      _ =>
        declaresBrowser || hasBrowserRisk
            ? 1
            : declaresHeavy || hasRepeatedFailures
            ? 2
            : 3,
    };

    final resolved = suggested.clamp(1, _maxConcurrentLoads);
    _logger.info(
      'Resolved chapter cache parallelism',
      context: <String, Object?>{
        'sourceId': sourceId,
        'chapterCount': chapterCount,
        'parallelism': resolved,
        'declaresBrowser': declaresBrowser,
        'declaresHeavy': declaresHeavy,
        'browserRiskCount': snapshot.browserRiskCount,
        'totalFailures': snapshot.totalFailures,
      },
    );
    return resolved;
  }
}
