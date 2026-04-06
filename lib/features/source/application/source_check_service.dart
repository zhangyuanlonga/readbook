import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../domain/entities/source_health.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'source_health_auto_disable_service.dart';
import 'source_health_reason_classifier.dart';
import 'source_health_service.dart';
import 'source_health_snapshot_resolver.dart';
import 'source_runtime_diagnostic_execution_container.dart';
import 'source_runtime_facade.dart';

enum SourceCheckLevel { searchOnly, searchAndDetail, fullReadPath }

enum SourceCheckStatus { healthy, warning, failed, skipped }

enum SourceCheckStep { none, search, detail, chapters, content }

class SourceCheckResult {
  const SourceCheckResult({
    required this.sourceId,
    required this.sourceName,
    required this.usedKeyword,
    required this.status,
    required this.checkedLevel,
    required this.duration,
    required this.stepReached,
    required this.message,
    required this.needsBrowser,
    required this.canAutoDisable,
    required this.canBatchDelete,
  });

  final String sourceId;
  final String sourceName;
  final String usedKeyword;
  final SourceCheckStatus status;
  final SourceCheckLevel checkedLevel;
  final Duration duration;
  final SourceCheckStep stepReached;
  final String message;
  final bool needsBrowser;
  final bool canAutoDisable;
  final bool canBatchDelete;
}

typedef SourceBatchCheckProgressCallback =
    void Function(SourceCheckResult result, int completedCount, int totalCount);

class SourceCheckService {
  SourceCheckService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    SourceHealthReasonClassifier? reasonClassifier,
    SourceHealthAutoDisableService? autoDisableService,
    AppLogger? logger,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _reasonClassifier =
           reasonClassifier ?? const SourceHealthReasonClassifier(),
       _autoDisableService =
           autoDisableService ?? SourceHealthAutoDisableService.instance,
       _logger = logger ?? AppLogger.instance;

  final SourceRuntimeFacade _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final SourceHealthReasonClassifier _reasonClassifier;
  final SourceHealthAutoDisableService _autoDisableService;
  final AppLogger _logger;
  static const String defaultCheckKeyword = '凡人修仙传';

  static SourceHealthStep _healthStepForCheckStep(SourceCheckStep step) {
    return switch (step) {
      SourceCheckStep.none => SourceHealthStep.search,
      SourceCheckStep.search => SourceHealthStep.search,
      SourceCheckStep.detail => SourceHealthStep.detail,
      SourceCheckStep.chapters => SourceHealthStep.chapters,
      SourceCheckStep.content => SourceHealthStep.content,
    };
  }

  Future<SourceCheckResult> checkSource({
    required String sourceId,
    required String keyword,
    SourceCheckLevel level = SourceCheckLevel.searchOnly,
    bool allowInteractiveChallenge = false,
    bool skipCooldown = false,
  }) async {
    final startedAt = DateTime.now();
    final registered = await _sourceRuntimeFacade
        .ensureRegisteredScriptSourceById(sourceId);
    if (registered == null) {
      return _failureResult(
        sourceId: sourceId,
        sourceName: sourceId,
        usedKeyword: _resolveCheckKeyword(
          keyword,
          manifestKeyword: null,
        ),
        checkedLevel: level,
        stepReached: SourceCheckStep.none,
        message: '书源不存在或已禁用。',
        failureKind: SourceHealthFailureKind.disabled,
        startedAt: startedAt,
      );
    }

    final sourceName = registered.runtime.name;
    final needsBrowser = _looksLikeBrowserCapable(registered);
    final snapshot = _sourceHealthService.snapshotFor(sourceId);
    final effectiveKeyword = _resolveCheckKeyword(
      keyword,
      manifestKeyword: registered.definition.manifest.checkKeyword,
    );

    if (skipCooldown && snapshot.coolingDown) {
      return _skippedResult(
        sourceId: sourceId,
        sourceName: sourceName,
        usedKeyword: effectiveKeyword,
        checkedLevel: level,
        startedAt: startedAt,
        message: '源处于冷却中，已跳过本次检测。',
        stepReached: SourceCheckStep.none,
        needsBrowser: needsBrowser,
      );
    }

    var attemptedStep = SourceCheckStep.search;
    SourceRuntimeDiagnosticExecutionContainer? diagnosticContainer;

    try {
      diagnosticContainer = await _sourceRuntimeFacade
          .createDiagnosticExecutionContainerById(sourceId);
      _logStepStarted(
        sourceId: sourceId,
        sourceName: sourceName,
        level: level,
        step: SourceCheckStep.search,
        keyword: effectiveKeyword,
      );
      final books =
          diagnosticContainer != null
              ? await diagnosticContainer.search(effectiveKeyword)
              : await _sourceRuntimeFacade.search(
                sourceId: sourceId,
                keyword: effectiveKeyword,
                allowInteractiveChallenge: allowInteractiveChallenge,
              );
      _sourceHealthService.markSearchSuccess(
        sourceId: sourceId,
        latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
      );
      if (needsBrowser) {
        _sourceHealthService.markBrowserRiskObserved(sourceId: sourceId);
      }
      if (books.isEmpty) {
        _recordStepFailure(
          sourceId: sourceId,
          stepReached: SourceCheckStep.search,
          message: '搜索无结果。',
          failureKind: SourceHealthFailureKind.emptyResult,
        );
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
          usedKeyword: effectiveKeyword,
          checkedLevel: level,
          stepReached: SourceCheckStep.search,
          message: '搜索无结果。',
          failureKind: SourceHealthFailureKind.emptyResult,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
        await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
        return result;
      }

      runtime_models.Book workingBook = books.first;
      var stepReached = SourceCheckStep.search;

      if (level == SourceCheckLevel.searchOnly) {
        return _successResult(
          sourceId: sourceId,
          sourceName: sourceName,
          usedKeyword: effectiveKeyword,
          checkedLevel: level,
          stepReached: stepReached,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
      }

      attemptedStep = SourceCheckStep.detail;
      _logStepStarted(
        sourceId: sourceId,
        sourceName: sourceName,
        level: level,
        step: SourceCheckStep.detail,
        keyword: effectiveKeyword,
      );
      workingBook =
          diagnosticContainer != null
              ? await diagnosticContainer.detail(workingBook)
              : await _sourceRuntimeFacade.detail(
                sourceId: sourceId,
                book: workingBook,
              );
      _sourceHealthService.markDetailSuccess(sourceId: sourceId);
      stepReached = SourceCheckStep.detail;

      if (level == SourceCheckLevel.searchAndDetail) {
        return _successResult(
          sourceId: sourceId,
          sourceName: sourceName,
          usedKeyword: effectiveKeyword,
          checkedLevel: level,
          stepReached: stepReached,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
      }

      attemptedStep = SourceCheckStep.chapters;
      _logStepStarted(
        sourceId: sourceId,
        sourceName: sourceName,
        level: level,
        step: SourceCheckStep.chapters,
        keyword: effectiveKeyword,
      );
      final chapters =
          diagnosticContainer != null
              ? await diagnosticContainer.chapters(workingBook)
              : await _sourceRuntimeFacade.chapters(
                sourceId: sourceId,
                book: workingBook,
              );
      _sourceHealthService.markChaptersSuccess(sourceId: sourceId);
      stepReached = SourceCheckStep.chapters;
      final contentChapter = chapters.firstWhere(
        (chapter) => !chapter.isVolume,
        orElse:
            () => const runtime_models.Chapter(title: '', url: '', index: 0),
      );
      if (contentChapter.url.trim().isEmpty) {
        _recordStepFailure(
          sourceId: sourceId,
          stepReached: stepReached,
          message: '目录无可读章节。',
          failureKind: SourceHealthFailureKind.emptyResult,
        );
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
          usedKeyword: effectiveKeyword,
          checkedLevel: level,
          stepReached: stepReached,
          message: '目录无可读章节。',
          failureKind: SourceHealthFailureKind.emptyResult,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
        await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
        return result;
      }

      attemptedStep = SourceCheckStep.content;
      _logStepStarted(
        sourceId: sourceId,
        sourceName: sourceName,
        level: level,
        step: SourceCheckStep.content,
        keyword: effectiveKeyword,
      );
      final content =
          diagnosticContainer != null
              ? await diagnosticContainer.content(workingBook, contentChapter)
              : await _sourceRuntimeFacade.content(
                sourceId: sourceId,
                book: workingBook,
                chapter: contentChapter,
              );
      stepReached = SourceCheckStep.content;
      if (content.content.trim().isEmpty && content.images.isEmpty) {
        _recordStepFailure(
          sourceId: sourceId,
          stepReached: stepReached,
          message: '正文为空。',
          failureKind: SourceHealthFailureKind.emptyResult,
        );
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
          usedKeyword: effectiveKeyword,
          checkedLevel: level,
          stepReached: stepReached,
          message: '正文为空。',
          failureKind: SourceHealthFailureKind.emptyResult,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
        await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
        return result;
      }

      _sourceHealthService.markContentSuccess(sourceId: sourceId);

      return _successResult(
        sourceId: sourceId,
        sourceName: sourceName,
        usedKeyword: effectiveKeyword,
        checkedLevel: level,
        stepReached: stepReached,
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
    } on AppException catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stepReached: attemptedStep,
        message: error.briefMessage,
        failureKind: _reasonClassifier.classify(appException: error),
        error: error,
      );
      final result = _failureResult(
        sourceId: sourceId,
        sourceName: sourceName,
        usedKeyword: effectiveKeyword,
        checkedLevel: level,
        stepReached: attemptedStep,
        message: error.briefMessage,
        failureKind: _reasonClassifier.classify(appException: error),
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
      await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
      return result;
    } catch (error) {
      _recordStepFailure(
        sourceId: sourceId,
        stepReached: attemptedStep,
        message: error.toString(),
        failureKind: _reasonClassifier.classify(error: error),
        error: error,
      );
      final result = _failureResult(
        sourceId: sourceId,
        sourceName: sourceName,
        usedKeyword: effectiveKeyword,
        checkedLevel: level,
        stepReached: attemptedStep,
        message: error.toString(),
        failureKind: _reasonClassifier.classify(error: error),
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
      await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
      return result;
    } finally {
      diagnosticContainer?.dispose();
    }
  }

  Future<List<SourceCheckResult>> checkSources({
    required Iterable<String> sourceIds,
    required String keyword,
    SourceCheckLevel level = SourceCheckLevel.searchOnly,
    bool allowInteractiveChallenge = false,
    bool skipCooldown = false,
    SourceBatchCheckProgressCallback? onProgress,
  }) async {
    final results = <SourceCheckResult>[];
    final sourceIdList = sourceIds.toList(growable: false);
    final totalCount = sourceIdList.length;
    for (final sourceId in sourceIdList) {
      final result = await checkSource(
        sourceId: sourceId,
        keyword: keyword,
        level: level,
        allowInteractiveChallenge: allowInteractiveChallenge,
        skipCooldown: skipCooldown,
      );
      results.add(result);
      onProgress?.call(result, results.length, totalCount);
    }
    return results;
  }

  SourceCheckResult _successResult({
    required String sourceId,
    required String sourceName,
    required String usedKeyword,
    required SourceCheckLevel checkedLevel,
    required SourceCheckStep stepReached,
    required DateTime startedAt,
    required bool needsBrowser,
  }) {
    final status =
        needsBrowser ? SourceCheckStatus.warning : SourceCheckStatus.healthy;
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
      usedKeyword: usedKeyword,
      status: status,
      checkedLevel: checkedLevel,
      duration: DateTime.now().difference(startedAt),
      stepReached: stepReached,
      message: needsBrowser ? '可用，但存在 browser/challenge 风险。' : '检测通过。',
      needsBrowser: needsBrowser,
      canAutoDisable: false,
      canBatchDelete: false,
    );
  }

  SourceCheckResult _failureResult({
    required String sourceId,
    required String sourceName,
    required String usedKeyword,
    required SourceCheckLevel checkedLevel,
    required SourceCheckStep stepReached,
    required String message,
    required SourceHealthFailureKind failureKind,
    required DateTime startedAt,
    bool needsBrowser = false,
  }) {
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
      usedKeyword: usedKeyword,
      status: SourceCheckStatus.failed,
      checkedLevel: checkedLevel,
      duration: DateTime.now().difference(startedAt),
      stepReached: stepReached,
      message: message,
      needsBrowser: needsBrowser,
      canAutoDisable: true,
      canBatchDelete: true,
    );
  }

  void _recordStepFailure({
    required String sourceId,
    required SourceCheckStep stepReached,
    required String message,
    required SourceHealthFailureKind failureKind,
    Object? error,
  }) {
    final markCooldown =
        failureKind == SourceHealthFailureKind.browserChallenge ||
        failureKind == SourceHealthFailureKind.timeout;
    final step = _healthStepForCheckStep(stepReached);
    switch (step) {
      case SourceHealthStep.search:
        _sourceHealthService.markSearchFailure(
          sourceId: sourceId,
          message: message,
          error: error,
          markCooldown: markCooldown,
        );
        break;
      case SourceHealthStep.detail:
        _sourceHealthService.markDetailFailure(
          sourceId: sourceId,
          message: message,
          error: error,
          markCooldown: markCooldown,
        );
        break;
      case SourceHealthStep.chapters:
        _sourceHealthService.markChaptersFailure(
          sourceId: sourceId,
          message: message,
          error: error,
          markCooldown: markCooldown,
        );
        break;
      case SourceHealthStep.content:
        _sourceHealthService.markContentFailure(
          sourceId: sourceId,
          message: message,
          error: error,
          markCooldown: markCooldown,
        );
        break;
      case SourceHealthStep.discoverCategories:
      case SourceHealthStep.discoverBooks:
      case SourceHealthStep.check:
        _sourceHealthService.markSearchFailure(
          sourceId: sourceId,
          message: message,
          error: error,
          markCooldown: markCooldown,
        );
        break;
    }
  }

  SourceCheckResult _skippedResult({
    required String sourceId,
    required String sourceName,
    required String usedKeyword,
    required SourceCheckLevel checkedLevel,
    required DateTime startedAt,
    required String message,
    required SourceCheckStep stepReached,
    required bool needsBrowser,
  }) {
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
      usedKeyword: usedKeyword,
      status: SourceCheckStatus.skipped,
      checkedLevel: checkedLevel,
      duration: DateTime.now().difference(startedAt),
      stepReached: stepReached,
      message: message,
      needsBrowser: needsBrowser,
      canAutoDisable: false,
      canBatchDelete: false,
    );
  }

  bool _looksLikeBrowserCapable(RegisteredSource registeredSource) {
    final capabilities =
        registeredSource.definition.manifest.capabilities
            .map((item) => item.trim().toLowerCase())
            .where((item) => item.isNotEmpty)
            .toSet();
    return capabilities.contains('browser') ||
        capabilities.contains('webview') ||
        capabilities.contains('challenge');
  }

  static String resolveCheckKeyword(
    String keyword, {
    required String? manifestKeyword,
  }) {
    return _resolveCheckKeyword(keyword, manifestKeyword: manifestKeyword);
  }

  static String _resolveCheckKeyword(
    String keyword, {
    required String? manifestKeyword,
  }) {
    final normalizedInput = keyword.trim();
    if (normalizedInput.isNotEmpty) {
      return normalizedInput;
    }
    final normalizedManifest = manifestKeyword?.trim() ?? '';
    if (normalizedManifest.isNotEmpty) {
      return normalizedManifest;
    }
    return defaultCheckKeyword;
  }

  void _logStepStarted({
    required String sourceId,
    required String sourceName,
    required SourceCheckLevel level,
    required SourceCheckStep step,
    required String keyword,
  }) {
    _logger.info(
      'Source check step started',
      context: <String, Object?>{
        'sourceId': sourceId,
        'sourceName': sourceName,
        'level': level.name,
        'step': step.name,
        'keyword': keyword,
      },
    );
  }

  Future<void> _evaluateAutoDisable({
    required String sourceId,
    required String sourceName,
  }) async {
    await _autoDisableService.evaluateSource(
      sourceId: sourceId,
      sourceName: sourceName,
      trigger: 'source_check',
    );
  }
}
