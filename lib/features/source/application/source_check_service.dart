import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/source_health.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'source_health_auto_disable_service.dart';
import 'source_health_reason_classifier.dart';
import 'source_health_service.dart';
import 'source_runtime_facade.dart';

enum SourceCheckLevel { searchOnly, searchAndDetail, fullReadPath }

enum SourceCheckStatus { healthy, warning, failed, skipped }

enum SourceCheckStep { none, search, detail, chapters, content }

class SourceCheckResult {
  const SourceCheckResult({
    required this.sourceId,
    required this.sourceName,
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
  final SourceCheckStatus status;
  final SourceCheckLevel checkedLevel;
  final Duration duration;
  final SourceCheckStep stepReached;
  final String message;
  final bool needsBrowser;
  final bool canAutoDisable;
  final bool canBatchDelete;
}

class SourceCheckService {
  SourceCheckService({
    SourceRuntimeFacade? sourceRuntimeFacade,
    SourceHealthService? sourceHealthService,
    SourceHealthReasonClassifier? reasonClassifier,
    SourceHealthAutoDisableService? autoDisableService,
  }) : _sourceRuntimeFacade =
           sourceRuntimeFacade ?? SourceRuntimeFacade.instance,
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _reasonClassifier =
           reasonClassifier ?? const SourceHealthReasonClassifier(),
       _autoDisableService =
           autoDisableService ?? SourceHealthAutoDisableService.instance;

  final SourceRuntimeFacade _sourceRuntimeFacade;
  final SourceHealthService _sourceHealthService;
  final SourceHealthReasonClassifier _reasonClassifier;
  final SourceHealthAutoDisableService _autoDisableService;

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

    if (skipCooldown && snapshot.coolingDown) {
      return _skippedResult(
        sourceId: sourceId,
        sourceName: sourceName,
        checkedLevel: level,
        startedAt: startedAt,
        message: '源处于冷却中，已跳过本次检测。',
        stepReached: SourceCheckStep.none,
        needsBrowser: needsBrowser,
      );
    }

    try {
      final books = await _sourceRuntimeFacade.search(
        sourceId: sourceId,
        keyword: keyword,
        allowInteractiveChallenge: allowInteractiveChallenge,
      );
      if (books.isEmpty) {
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
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
          checkedLevel: level,
          stepReached: stepReached,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
      }

      workingBook = await _sourceRuntimeFacade.detail(
        sourceId: sourceId,
        book: workingBook,
      );
      stepReached = SourceCheckStep.detail;

      if (level == SourceCheckLevel.searchAndDetail) {
        return _successResult(
          sourceId: sourceId,
          sourceName: sourceName,
          checkedLevel: level,
          stepReached: stepReached,
          startedAt: startedAt,
          needsBrowser: needsBrowser,
        );
      }

      final chapters = await _sourceRuntimeFacade.chapters(
        sourceId: sourceId,
        book: workingBook,
      );
      stepReached = SourceCheckStep.chapters;
      final contentChapter = chapters.firstWhere(
        (chapter) => !chapter.isVolume,
        orElse:
            () => const runtime_models.Chapter(title: '', url: '', index: 0),
      );
      if (contentChapter.url.trim().isEmpty) {
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
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

      final content = await _sourceRuntimeFacade.content(
        sourceId: sourceId,
        book: workingBook,
        chapter: contentChapter,
      );
      stepReached = SourceCheckStep.content;
      if (content.content.trim().isEmpty && content.images.isEmpty) {
        final result = _failureResult(
          sourceId: sourceId,
          sourceName: sourceName,
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

      return _successResult(
        sourceId: sourceId,
        sourceName: sourceName,
        checkedLevel: level,
        stepReached: stepReached,
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
    } on AppException catch (error) {
      final result = _failureResult(
        sourceId: sourceId,
        sourceName: sourceName,
        checkedLevel: level,
        stepReached: SourceCheckStep.none,
        message: error.briefMessage,
        failureKind: _reasonClassifier.classify(appException: error),
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
      await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
      return result;
    } catch (error) {
      final result = _failureResult(
        sourceId: sourceId,
        sourceName: sourceName,
        checkedLevel: level,
        stepReached: SourceCheckStep.none,
        message: error.toString(),
        failureKind: _reasonClassifier.classify(error: error),
        startedAt: startedAt,
        needsBrowser: needsBrowser,
      );
      await _evaluateAutoDisable(sourceId: sourceId, sourceName: sourceName);
      return result;
    }
  }

  Future<List<SourceCheckResult>> checkSources({
    required Iterable<String> sourceIds,
    required String keyword,
    SourceCheckLevel level = SourceCheckLevel.searchOnly,
    bool allowInteractiveChallenge = false,
    bool skipCooldown = false,
  }) async {
    final results = <SourceCheckResult>[];
    for (final sourceId in sourceIds) {
      results.add(
        await checkSource(
          sourceId: sourceId,
          keyword: keyword,
          level: level,
          allowInteractiveChallenge: allowInteractiveChallenge,
          skipCooldown: skipCooldown,
        ),
      );
    }
    return results;
  }

  SourceCheckResult _successResult({
    required String sourceId,
    required String sourceName,
    required SourceCheckLevel checkedLevel,
    required SourceCheckStep stepReached,
    required DateTime startedAt,
    required bool needsBrowser,
  }) {
    _sourceHealthService.markSearchSuccess(
      sourceId: sourceId,
      latencyMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
    final status =
        needsBrowser ? SourceCheckStatus.warning : SourceCheckStatus.healthy;
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
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
    required SourceCheckLevel checkedLevel,
    required SourceCheckStep stepReached,
    required String message,
    required SourceHealthFailureKind failureKind,
    required DateTime startedAt,
    bool needsBrowser = false,
  }) {
    _sourceHealthService.markSearchFailure(
      sourceId: sourceId,
      message: message,
      markCooldown:
          failureKind == SourceHealthFailureKind.browserChallenge ||
          failureKind == SourceHealthFailureKind.timeout,
    );
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
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

  SourceCheckResult _skippedResult({
    required String sourceId,
    required String sourceName,
    required SourceCheckLevel checkedLevel,
    required DateTime startedAt,
    required String message,
    required SourceCheckStep stepReached,
    required bool needsBrowser,
  }) {
    return SourceCheckResult(
      sourceId: sourceId,
      sourceName: sourceName,
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
