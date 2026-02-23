import 'dart:collection';
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/source_repository_impl.dart';
import '../../../domain/entities/source_definition.dart';
import '../../../domain/repositories/source_repository.dart';
import '../../book/application/book_detail_service.dart';
import '../../reader/application/chapter_content_service.dart';
import '../../search/application/search_service.dart';

enum SourceDiagnosticMode { probe, searchOnly, fullChainQuick }

enum SourceDiagnosticStage { search, detail, toc, content }

class SourceDiagnosticStageResult {
  const SourceDiagnosticStageResult({
    required this.stage,
    required this.success,
    required this.durationMs,
    this.code,
    this.message,
    this.requestUrl,
    this.extra = const {},
  });

  final SourceDiagnosticStage stage;
  final bool success;
  final int durationMs;
  final ErrorCode? code;
  final String? message;
  final String? requestUrl;
  final Map<String, Object?> extra;

  Map<String, dynamic> toJson() {
    return {
      'stage': stage.name,
      'success': success,
      'durationMs': durationMs,
      'code': code?.name,
      'message': message,
      'requestUrl': requestUrl,
      'extra': extra,
    };
  }
}

class SourceDiagnosticReport {
  const SourceDiagnosticReport({
    required this.sourceId,
    required this.sourceName,
    required this.mode,
    required this.keyword,
    required this.startedAt,
    required this.finishedAt,
    required this.stages,
    this.sampleBookTitle,
    this.sampleDetailUrl,
    this.sampleChapterTitle,
    this.sampleChapterUrl,
    this.sourceRaw,
  });

  final String sourceId;
  final String sourceName;
  final SourceDiagnosticMode mode;
  final String keyword;
  final DateTime startedAt;
  final DateTime finishedAt;
  final List<SourceDiagnosticStageResult> stages;
  final String? sampleBookTitle;
  final String? sampleDetailUrl;
  final String? sampleChapterTitle;
  final String? sampleChapterUrl;
  final Map<String, dynamic>? sourceRaw;

  bool get isSuccess =>
      stages.isNotEmpty && stages.every((item) => item.success);

  List<SourceDiagnosticStageResult> get failedStages =>
      stages.where((item) => !item.success).toList(growable: false);

  Map<String, dynamic> toJson() {
    return {
      'sourceId': sourceId,
      'sourceName': sourceName,
      'mode': mode.name,
      'keyword': keyword,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'isSuccess': isSuccess,
      'sample': {
        'bookTitle': sampleBookTitle,
        'detailUrl': sampleDetailUrl,
        'chapterTitle': sampleChapterTitle,
        'chapterUrl': sampleChapterUrl,
      },
      'stages': stages.map((item) => item.toJson()).toList(growable: false),
      'sourceRaw': sourceRaw,
    };
  }
}

class SourceBatchDiagnosticProgress {
  const SourceBatchDiagnosticProgress({
    required this.total,
    required this.processed,
    required this.successCount,
    required this.failedCount,
    this.currentSourceId,
    this.currentSourceName,
    this.latestReport,
  });

  final int total;
  final int processed;
  final int successCount;
  final int failedCount;
  final String? currentSourceId;
  final String? currentSourceName;
  final SourceDiagnosticReport? latestReport;
}

typedef SourceBatchDiagnosticProgressCallback =
    void Function(SourceBatchDiagnosticProgress progress);

class SourceBatchDiagnosticToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class SourceDiagnosticsService {
  SourceDiagnosticsService({
    SourceRepository? sourceRepository,
    SearchService? searchService,
    BookDetailService? bookDetailService,
    ChapterContentService? chapterContentService,
  }) : _sourceRepository =
           sourceRepository ?? SourceRepositoryImpl(AppDatabase.instance),
       _searchService =
           searchService ?? SearchService(sourceRepository: sourceRepository),
       _bookDetailService =
           bookDetailService ??
           BookDetailService(sourceRepository: sourceRepository),
       _chapterContentService =
           chapterContentService ??
           ChapterContentService(sourceRepository: sourceRepository);

  final SourceRepository _sourceRepository;
  final SearchService _searchService;
  final BookDetailService _bookDetailService;
  final ChapterContentService _chapterContentService;

  Future<List<SourceDefinition>> loadEnabledSources({
    List<String>? sourceIds,
  }) async {
    final all = await _sourceRepository.getAll();
    final enabled = all.where((item) => item.enabled);

    final idSet =
        sourceIds
            ?.map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();

    if (idSet == null || idSet.isEmpty) {
      return enabled.toList(growable: false);
    }

    return enabled
        .where((item) => idSet.contains(item.id))
        .toList(growable: false);
  }

  Future<SourceDiagnosticReport> diagnoseSource({
    required SourceDefinition source,
    required String keyword,
    SourceDiagnosticMode mode = SourceDiagnosticMode.fullChainQuick,
  }) async {
    final startedAt = DateTime.now();
    final normalizedKeyword = keyword.trim();
    final stages = <SourceDiagnosticStageResult>[];

    if (mode == SourceDiagnosticMode.probe) {
      stages.add(await _probeStage(source: source, keyword: normalizedKeyword));
      return SourceDiagnosticReport(
        sourceId: source.id,
        sourceName: source.name,
        mode: mode,
        keyword: normalizedKeyword,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        stages: List.unmodifiable(stages),
        sourceRaw: source.originalSource,
      );
    }

    String? sampleBookTitle;
    String? sampleDetailUrl;
    String? sampleChapterTitle;
    String? sampleChapterUrl;

    final searchStarted = DateTime.now();
    try {
      final report = await _searchService.search(
        keyword: normalizedKeyword,
        sourceIds: [source.id],
        pageSize: 5,
      );

      if (report.failures.isNotEmpty) {
        final failure = report.failures.first;
        stages.add(
          SourceDiagnosticStageResult(
            stage: SourceDiagnosticStage.search,
            success: false,
            durationMs: DateTime.now().difference(searchStarted).inMilliseconds,
            code: failure.code,
            message: failure.debugMessage ?? failure.message,
            requestUrl: failure.requestUrl,
          ),
        );
      } else if (report.books.isEmpty) {
        stages.add(
          SourceDiagnosticStageResult(
            stage: SourceDiagnosticStage.search,
            success: false,
            durationMs: DateTime.now().difference(searchStarted).inMilliseconds,
            code: ErrorCode.ruleMatchEmpty,
            message: '搜索无结果，无法继续后续阶段诊断。',
          ),
        );
      } else {
        final book = report.books.first;
        sampleBookTitle = book.title;
        sampleDetailUrl = book.detailUrl;
        stages.add(
          SourceDiagnosticStageResult(
            stage: SourceDiagnosticStage.search,
            success: true,
            durationMs: DateTime.now().difference(searchStarted).inMilliseconds,
            requestUrl: book.detailUrl,
            extra: {'matchedBookCount': report.books.length},
          ),
        );

        if (mode == SourceDiagnosticMode.searchOnly) {
          return SourceDiagnosticReport(
            sourceId: source.id,
            sourceName: source.name,
            mode: mode,
            keyword: normalizedKeyword,
            startedAt: startedAt,
            finishedAt: DateTime.now(),
            stages: List.unmodifiable(stages),
            sampleBookTitle: sampleBookTitle,
            sampleDetailUrl: sampleDetailUrl,
            sourceRaw: source.originalSource,
          );
        }

        final detailStarted = DateTime.now();
        try {
          final detailResult = await _bookDetailService.load(
            sourceId: source.id,
            bookId: book.id,
            detailUrl: book.detailUrl,
            fallbackTitle: book.title,
            forceRefresh: true,
          );

          stages.add(
            SourceDiagnosticStageResult(
              stage: SourceDiagnosticStage.detail,
              success: true,
              durationMs:
                  DateTime.now().difference(detailStarted).inMilliseconds,
              requestUrl: book.detailUrl,
              extra: {'resolvedTitle': detailResult.detail.title},
            ),
          );

          if (detailResult.tocError != null) {
            final error = detailResult.tocError!;
            stages.add(
              SourceDiagnosticStageResult(
                stage: SourceDiagnosticStage.toc,
                success: false,
                durationMs:
                    DateTime.now().difference(detailStarted).inMilliseconds,
                code: error.code,
                message: error.briefMessage,
                requestUrl: error.requestUrl ?? detailResult.detail.tocUrl,
              ),
            );
          } else if (detailResult.chapters.isEmpty) {
            stages.add(
              SourceDiagnosticStageResult(
                stage: SourceDiagnosticStage.toc,
                success: false,
                durationMs:
                    DateTime.now().difference(detailStarted).inMilliseconds,
                code: ErrorCode.ruleMatchEmpty,
                message: '目录为空，无法继续正文诊断。',
                requestUrl: detailResult.detail.tocUrl,
              ),
            );
          } else {
            final chapter = detailResult.chapters.first;
            sampleChapterTitle = chapter.title;
            sampleChapterUrl = chapter.chapterUrl;

            stages.add(
              SourceDiagnosticStageResult(
                stage: SourceDiagnosticStage.toc,
                success: true,
                durationMs:
                    DateTime.now().difference(detailStarted).inMilliseconds,
                requestUrl: detailResult.detail.tocUrl,
                extra: {
                  'chapterCount': detailResult.chapters.length,
                  'firstChapterTitle': chapter.title,
                },
              ),
            );

            final contentStarted = DateTime.now();
            try {
              final contentResult = await _chapterContentService.load(
                sourceId: source.id,
                chapterUrl: chapter.chapterUrl,
                bookId: book.id,
                chapterIndex: chapter.index,
                chapterTitle: chapter.title,
              );

              final hasPayload =
                  contentResult.content.trim().isNotEmpty ||
                  contentResult.imageUrls.isNotEmpty;
              stages.add(
                SourceDiagnosticStageResult(
                  stage: SourceDiagnosticStage.content,
                  success: hasPayload,
                  durationMs:
                      DateTime.now().difference(contentStarted).inMilliseconds,
                  requestUrl: chapter.chapterUrl,
                  code: hasPayload ? null : ErrorCode.ruleMatchEmpty,
                  message: hasPayload ? null : '正文为空或未解析到图片内容。',
                  extra: {
                    'fromCache': contentResult.fromCache,
                    'isImageContent': contentResult.isImageContent,
                    'imageCount': contentResult.imageUrls.length,
                    'contentLength': contentResult.content.length,
                  },
                ),
              );
            } on AppException catch (error) {
              stages.add(
                SourceDiagnosticStageResult(
                  stage: SourceDiagnosticStage.content,
                  success: false,
                  durationMs:
                      DateTime.now().difference(contentStarted).inMilliseconds,
                  code: error.code,
                  message: error.briefMessage,
                  requestUrl: error.requestUrl ?? chapter.chapterUrl,
                ),
              );
            } catch (error) {
              stages.add(
                SourceDiagnosticStageResult(
                  stage: SourceDiagnosticStage.content,
                  success: false,
                  durationMs:
                      DateTime.now().difference(contentStarted).inMilliseconds,
                  code: ErrorCode.unknown,
                  message: error.toString(),
                  requestUrl: chapter.chapterUrl,
                ),
              );
            }
          }
        } on AppException catch (error) {
          stages.add(
            SourceDiagnosticStageResult(
              stage: _mapStage(error.stage),
              success: false,
              durationMs:
                  DateTime.now().difference(detailStarted).inMilliseconds,
              code: error.code,
              message: error.briefMessage,
              requestUrl: error.requestUrl ?? book.detailUrl,
            ),
          );
        } catch (error) {
          stages.add(
            SourceDiagnosticStageResult(
              stage: SourceDiagnosticStage.detail,
              success: false,
              durationMs:
                  DateTime.now().difference(detailStarted).inMilliseconds,
              code: ErrorCode.unknown,
              message: error.toString(),
              requestUrl: book.detailUrl,
            ),
          );
        }
      }
    } on AppException catch (error) {
      stages.add(
        SourceDiagnosticStageResult(
          stage: SourceDiagnosticStage.search,
          success: false,
          durationMs: DateTime.now().difference(searchStarted).inMilliseconds,
          code: error.code,
          message: error.briefMessage,
          requestUrl: error.requestUrl,
        ),
      );
    } catch (error) {
      stages.add(
        SourceDiagnosticStageResult(
          stage: SourceDiagnosticStage.search,
          success: false,
          durationMs: DateTime.now().difference(searchStarted).inMilliseconds,
          code: ErrorCode.unknown,
          message: error.toString(),
        ),
      );
    }

    return SourceDiagnosticReport(
      sourceId: source.id,
      sourceName: source.name,
      mode: mode,
      keyword: normalizedKeyword,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
      stages: List.unmodifiable(stages),
      sampleBookTitle: sampleBookTitle,
      sampleDetailUrl: sampleDetailUrl,
      sampleChapterTitle: sampleChapterTitle,
      sampleChapterUrl: sampleChapterUrl,
      sourceRaw: source.originalSource,
    );
  }

  Future<List<SourceDiagnosticReport>> diagnoseBatch({
    required List<SourceDefinition> sources,
    required String keyword,
    SourceDiagnosticMode mode = SourceDiagnosticMode.fullChainQuick,
    int concurrency = 2,
    SourceBatchDiagnosticToken? cancellationToken,
    SourceBatchDiagnosticProgressCallback? onProgress,
  }) async {
    final normalizedKeyword = keyword.trim();
    final queue = Queue<SourceDefinition>.from(sources);
    final reports = <SourceDiagnosticReport>[];

    final total = sources.length;
    var processed = 0;
    var successCount = 0;
    var failedCount = 0;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (cancellationToken?.isCancelled ?? false) {
          return;
        }

        final source = queue.removeFirst();
        final report = await diagnoseSource(
          source: source,
          keyword: normalizedKeyword,
          mode: mode,
        );
        reports.add(report);
        processed += 1;
        if (report.isSuccess) {
          successCount += 1;
        } else {
          failedCount += 1;
        }

        if (onProgress != null) {
          onProgress(
            SourceBatchDiagnosticProgress(
              total: total,
              processed: processed,
              successCount: successCount,
              failedCount: failedCount,
              currentSourceId: source.id,
              currentSourceName: source.name,
              latestReport: report,
            ),
          );
        }
      }
    }

    final workerCount = min(max(1, concurrency), max(1, queue.length));
    await Future.wait(List.generate(workerCount, (_) => worker()));

    return List.unmodifiable(reports);
  }

  Future<SourceDiagnosticStageResult> _probeStage({
    required SourceDefinition source,
    required String keyword,
  }) async {
    final started = DateTime.now();
    try {
      final report = await _searchService.testSingleSource(
        source: source,
        keyword: keyword,
        validateRules: false,
        skipInit: true,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 6),
      );

      if (report.isSuccess) {
        return SourceDiagnosticStageResult(
          stage: SourceDiagnosticStage.search,
          success: true,
          durationMs: DateTime.now().difference(started).inMilliseconds,
          requestUrl: report.requestUrl,
          extra: {'probeOnly': report.probeOnly},
        );
      }

      final error = report.error!;
      return SourceDiagnosticStageResult(
        stage: SourceDiagnosticStage.search,
        success: false,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        code: error.code,
        message: error.briefMessage,
        requestUrl: report.requestUrl,
        extra: {'probeOnly': report.probeOnly},
      );
    } on AppException catch (error) {
      return SourceDiagnosticStageResult(
        stage: SourceDiagnosticStage.search,
        success: false,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        code: error.code,
        message: error.briefMessage,
        requestUrl: error.requestUrl,
      );
    } catch (error) {
      return SourceDiagnosticStageResult(
        stage: SourceDiagnosticStage.search,
        success: false,
        durationMs: DateTime.now().difference(started).inMilliseconds,
        code: ErrorCode.unknown,
        message: error.toString(),
      );
    }
  }

  SourceDiagnosticStage _mapStage(ErrorStage stage) {
    return switch (stage) {
      ErrorStage.search => SourceDiagnosticStage.search,
      ErrorStage.detail => SourceDiagnosticStage.detail,
      ErrorStage.toc => SourceDiagnosticStage.toc,
      ErrorStage.content => SourceDiagnosticStage.content,
      ErrorStage.source ||
      ErrorStage.reader ||
      ErrorStage.unknown => SourceDiagnosticStage.detail,
    };
  }
}
