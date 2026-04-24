import 'dart:async';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/script_source_repository_impl.dart';
import '../../../domain/entities/script_source.dart';
import '../../../domain/repositories/script_source_repository.dart';
import '../../../runtime/session/source_session.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_contract.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import '../../../domain/entities/source_health.dart';
import '../../../core/logging/app_logger.dart';
import 'source_site_cluster_service.dart';
import 'script_source_runtime_service.dart';
import 'source_health_service.dart';
import 'source_login_state_service.dart';
import 'source_runtime_diagnostic_execution_container.dart';
import 'source_runtime_execution_policy_service.dart';
import 'source_runtime_warm_state_service.dart';

class ScriptSourceReloadFailure {
  const ScriptSourceReloadFailure({required this.source, required this.error});

  final ScriptSource source;
  final Object error;
}

class ScriptSourceReloadReport {
  const ScriptSourceReloadReport({
    required this.loaded,
    required this.failures,
  });

  final List<RegisteredSource> loaded;
  final List<ScriptSourceReloadFailure> failures;
}

class SourceRuntimeDebugArtifactsSnapshot {
  const SourceRuntimeDebugArtifactsSnapshot({
    this.logs = const <Map<String, Object?>>[],
    this.traces = const <Map<String, Object?>>[],
  });

  final List<Map<String, Object?>> logs;
  final List<Map<String, Object?>> traces;
}

class SourceRuntimeFacade {
  static final SourceRuntimeFacade instance = SourceRuntimeFacade(
    scriptSourceRepository: ScriptSourceRepositoryImpl(AppDatabase.instance),
  );

  SourceRuntimeFacade({
    required ScriptSourceRepository scriptSourceRepository,
    ScriptSourceRuntimeService? scriptRuntimeService,
    SourceSiteClusterService? siteClusterService,
    SourceHealthService? sourceHealthService,
    SourceRuntimeExecutionPolicyService? executionPolicyService,
    SourceRuntimeWarmStateService? warmStateService,
    SourceLoginStateService? sourceLoginStateService,
    AppLogger? logger,
    Uuid? uuid,
  }) : _scriptSourceRepository = scriptSourceRepository,
       _scriptRuntimeService =
           scriptRuntimeService ?? ScriptSourceRuntimeService(),
       _siteClusterService =
           siteClusterService ?? const SourceSiteClusterService(),
       _sourceHealthService =
           sourceHealthService ?? SourceHealthService.instance,
       _executionPolicyService =
           executionPolicyService ??
           SourceRuntimeExecutionPolicyService.instance,
       _warmStateService =
           warmStateService ?? SourceRuntimeWarmStateService.instance,
       _sourceLoginStateService =
           sourceLoginStateService ?? SourceLoginStateService(),
       _logger = logger ?? AppLogger.instance,
       _uuid = uuid ?? const Uuid();

  final ScriptSourceRepository _scriptSourceRepository;
  final ScriptSourceRuntimeService _scriptRuntimeService;
  final SourceSiteClusterService _siteClusterService;
  final SourceHealthService _sourceHealthService;
  final SourceRuntimeExecutionPolicyService _executionPolicyService;
  final SourceRuntimeWarmStateService _warmStateService;
  final SourceLoginStateService _sourceLoginStateService;
  final AppLogger _logger;
  final Uuid _uuid;

  Future<List<ScriptSource>> listScriptSources() {
    return _scriptSourceRepository.getAll();
  }

  Stream<List<ScriptSource>> watchScriptSources() {
    return _scriptSourceRepository.watchAll();
  }

  Future<ScriptSource?> getScriptSourceById(String id) {
    return _scriptSourceRepository.getById(id);
  }

  SourceRuntimeDebugArtifactsSnapshot consumeLastDebugArtifacts(
    String sourceId,
  ) {
    final artifacts = _scriptRuntimeService.consumeLastDebugArtifacts(sourceId);
    return SourceRuntimeDebugArtifactsSnapshot(
      logs: artifacts.logs,
      traces: artifacts.traces,
    );
  }

  Future<ScriptSource> saveScriptSource({
    required String sourceCode,
    String? id,
    bool enabled = true,
  }) async {
    final saveStopwatch = Stopwatch()..start();
    final normalizedCode = sourceCode.trim();
    if (normalizedCode.isEmpty) {
      throw StateError('Script source code cannot be empty.');
    }

    final persistedId = id?.trim().isNotEmpty == true ? id!.trim() : _uuid.v4();
    final existing = await _scriptSourceRepository.getById(persistedId);
    _warmStateService.clearSource(persistedId);
    final compileStopwatch = Stopwatch()..start();
    final registered = await _scriptRuntimeService.compileAndRegister(
      sourceCode: normalizedCode,
      runtimeId: persistedId,
      revision: 'script:${DateTime.now().millisecondsSinceEpoch}',
    );
    final compileCostMs = compileStopwatch.elapsedMilliseconds;

    final now = DateTime.now();
    final manifest = registered.definition.manifest;
    final siteMeta = _siteClusterService.resolve(
      homepage: manifest.homepage,
      domains: manifest.domains,
    );
    final resolvedName = _resolvePersistedName(
      sourceCode: normalizedCode,
      manifestName: manifest.name,
    );
    final nextSource = ScriptSource(
      id: persistedId,
      name: resolvedName,
      group: manifest.group.trim().isEmpty ? null : manifest.group.trim(),
      author: manifest.author.trim().isEmpty ? null : manifest.author.trim(),
      description:
          manifest.description.trim().isEmpty
              ? null
              : manifest.description.trim(),
      checkKeyword:
          manifest.checkKeyword?.trim().isEmpty ?? true
              ? null
              : manifest.checkKeyword!.trim(),
      primaryHost: siteMeta.primaryHost,
      registrableDomain: siteMeta.registrableDomain,
      clusterKey: siteMeta.clusterKey,
      sourceCode: normalizedCode,
      enabled: enabled,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final persistStopwatch = Stopwatch()..start();
    await _scriptSourceRepository.upsert(nextSource);
    final persistCostMs = persistStopwatch.elapsedMilliseconds;

    if (existing == null) {
      _sourceHealthService.upsert(
        SourceHealthSnapshot(
          sourceId: persistedId,
          level: SourceHealthLevel.unchecked,
          enabled: enabled,
        ),
      );
    }

    if (!enabled) {
      _scriptRuntimeService.removeRegisteredSource(persistedId);
    }
    _logger.info(
      'Script source saved',
      context: <String, Object?>{
        'sourceId': persistedId,
        'isNew': existing == null,
        'enabled': enabled,
        'compileMs': compileCostMs,
        'persistMs': persistCostMs,
        'totalMs': saveStopwatch.elapsedMilliseconds,
      },
    );
    return nextSource;
  }

  String _resolvePersistedName({
    required String sourceCode,
    required String manifestName,
  }) {
    final normalizedManifestName = manifestName.trim();
    final rawName = _extractLiteralMetaField(sourceCode, 'name');
    if (rawName == null) {
      return normalizedManifestName;
    }

    final normalizedRawName = rawName.trim();
    if (normalizedRawName.isEmpty) {
      return normalizedManifestName;
    }

    if (normalizedManifestName.isEmpty) {
      return normalizedRawName;
    }

    if (_containsSuspiciousReplacement(normalizedManifestName) &&
        !_containsSuspiciousReplacement(normalizedRawName)) {
      return normalizedRawName;
    }

    return normalizedRawName;
  }

  String? _extractLiteralMetaField(String sourceCode, String fieldName) {
    final metaMatch = RegExp(
      r'\bmeta\s*:\s*\{([\s\S]*?)\n\s*\}',
      multiLine: true,
    ).firstMatch(sourceCode);
    final block = metaMatch?.group(1);
    if (block == null || block.trim().isEmpty) {
      return null;
    }

    final pattern = RegExp(
      "\\b$fieldName\\s*:\\s*(['\"])((?:\\\\.|(?!\\1)[\\s\\S])*)\\1",
      multiLine: true,
    );
    final match = pattern.firstMatch(block);
    final rawValue = match?.group(2);
    if (rawValue == null) {
      return null;
    }

    return rawValue
        .replaceAll(r"\'", "'")
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\t', '\t');
  }

  bool _containsSuspiciousReplacement(String value) {
    return value.contains('\uFFFD');
  }

  Future<void> setScriptSourceEnabled({
    required String id,
    required bool enabled,
  }) async {
    await _scriptSourceRepository.setEnabled(id: id, enabled: enabled);
    final source = await _scriptSourceRepository.getById(id);
    if (source == null) {
      return;
    }
    if (!enabled) {
      _warmStateService.clearSource(id);
      _scriptRuntimeService.removeRegisteredSource(id);
      return;
    }
    await _scriptRuntimeService.compileAndRegister(
      sourceCode: source.sourceCode,
      runtimeId: source.id,
      revision: 'script:${source.updatedAt.millisecondsSinceEpoch}',
    );
  }

  Future<void> deleteScriptSource(String id) async {
    _warmStateService.clearSource(id);
    await _scriptSourceRepository.deleteById(id);
    await _sourceLoginStateService.removeSourceLoginState(id);
    await _sourceLoginStateService.removeBookCustomStatesForSource(id);
    _scriptRuntimeService.removeRegisteredSource(id);
  }

  void clearReadingFlow({
    required String sourceId,
    String detailUrl = '',
    String tocUrl = '',
    String title = '',
  }) {
    _scriptRuntimeService.clearReadingFlow(
      sourceId: sourceId,
      detailUrl: detailUrl,
      tocUrl: tocUrl,
      title: title,
    );
  }

  Future<ScriptSourceReloadReport> reloadScriptSources({
    bool enabledOnly = true,
  }) async {
    _scriptRuntimeService.clearRegisteredSources();
    final sources = await _scriptSourceRepository.getAll();
    final loaded = <RegisteredSource>[];
    final failures = <ScriptSourceReloadFailure>[];

    for (final source in sources) {
      if (enabledOnly && !source.enabled) {
        continue;
      }
      try {
        final registered = await _scriptRuntimeService.compileAndRegister(
          sourceCode: source.sourceCode,
          runtimeId: source.id,
          revision: 'script:${source.updatedAt.millisecondsSinceEpoch}',
        );
        loaded.add(registered);
      } catch (error) {
        failures.add(ScriptSourceReloadFailure(source: source, error: error));
      }
    }

    return ScriptSourceReloadReport(
      loaded: List<RegisteredSource>.unmodifiable(loaded),
      failures: List<ScriptSourceReloadFailure>.unmodifiable(failures),
    );
  }

  List<RegisteredSource> registeredScriptSources({bool enabledOnly = true}) {
    return _scriptRuntimeService.allSources(enabledOnly: enabledOnly);
  }

  RegisteredSource? registeredScriptSourceById(String sourceId) {
    return _scriptRuntimeService.sourceById(sourceId);
  }

  SourceRuntimeContext createRuntimeContext(
    RegisteredSource source, {
    SourceUiContext ui = const SourceUiContext(),
  }) {
    return _scriptRuntimeService.createContext(source, ui: ui);
  }

  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final existing = _scriptRuntimeService.sourceById(normalized);
    if (existing != null) {
      return existing;
    }

    final source = await _scriptSourceRepository.getById(normalized);
    if (source == null || !source.enabled) {
      return null;
    }

    return _scriptRuntimeService.compileAndRegister(
      sourceCode: source.sourceCode,
      runtimeId: source.id,
      revision: 'script:${source.updatedAt.millisecondsSinceEpoch}',
    );
  }

  Future<SourceRuntimeDiagnosticExecutionContainer?>
  createDiagnosticExecutionContainerById(
    String sourceId, {
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final normalizedSourceId = sourceId.trim();
    if (normalizedSourceId.isEmpty) {
      return null;
    }
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    if (source == null || !source.enabled) {
      return null;
    }
    try {
      return await _scriptRuntimeService.createDiagnosticExecutionContainer(
        sourceId: normalizedSourceId,
        sourceCode: source.sourceCode,
        cancellationHandle: cancellationHandle,
        serializeStartup: true,
      );
    } catch (error, stackTrace) {
      if (error is SessionTaskCancelledException) {
        rethrow;
      }
      throw _normalizeRuntimeException(
        sourceId: normalizedSourceId,
        step: SourceRuntimeExecutionStep.search,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.search,
      scene: SourceRuntimeExecutionScene.search,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.requestIsolated) {
          return _scriptRuntimeService.searchIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            keyword: keyword,
            allowInteractiveChallenge: allowInteractiveChallenge,
            cancellationHandle: cancellationHandle,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.search(
          sourceId: normalizedSourceId,
          keyword: keyword,
          allowInteractiveChallenge: allowInteractiveChallenge,
          cancellationHandle: cancellationHandle,
        );
      },
    );
  }

  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.discoverCategories,
      scene: SourceRuntimeExecutionScene.discover,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.requestIsolated) {
          return _scriptRuntimeService.discoverCategoriesIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.discoverCategories(
          sourceId: normalizedSourceId,
        );
      },
    );
  }

  Future<List<runtime_models.Book>> discoverBooks({
    required String sourceId,
    required runtime_models.DiscoverCategory category,
    required int page,
    required int pageSize,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.discoverBooks,
      scene: SourceRuntimeExecutionScene.discover,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.requestIsolated) {
          return _scriptRuntimeService.discoverBooksIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            category: category,
            page: page,
            pageSize: pageSize,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.discoverBooks(
          sourceId: normalizedSourceId,
          category: category,
          page: page,
          pageSize: pageSize,
        );
      },
    );
  }

  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.detail,
      scene: SourceRuntimeExecutionScene.detail,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.flowIsolated) {
          return _scriptRuntimeService.detailIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            book: book,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.detail(
          sourceId: normalizedSourceId,
          book: book,
        );
      },
    );
  }

  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.chapters,
      scene: SourceRuntimeExecutionScene.reader,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.flowIsolated) {
          return _scriptRuntimeService.chaptersIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            book: book,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.chapters(
          sourceId: normalizedSourceId,
          book: book,
        );
      },
    );
  }

  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final source = await _scriptSourceRepository.getById(normalizedSourceId);
    return _runWithExecutionPlan(
      sourceId: normalizedSourceId,
      source: source,
      step: SourceRuntimeExecutionStep.content,
      scene: SourceRuntimeExecutionScene.reader,
      action: (plan) {
        if (plan.containerKind ==
            SourceRuntimeExecutionContainerKind.flowIsolated) {
          return _scriptRuntimeService.contentIsolated(
            sourceId: normalizedSourceId,
            sourceCode: source!.sourceCode,
            book: book,
            chapter: chapter,
            serializeStartup: plan.serializeStartup,
          );
        }
        return _scriptRuntimeService.content(
          sourceId: normalizedSourceId,
          book: book,
          chapter: chapter,
        );
      },
    );
  }

  Future<T> _runWithExecutionPlan<T>({
    required String sourceId,
    required ScriptSource? source,
    required SourceRuntimeExecutionStep step,
    required SourceRuntimeExecutionScene scene,
    required Future<T> Function(SourceRuntimeExecutionPlan plan) action,
  }) async {
    final normalizedSourceId = sourceId.trim();
    final stepName = step.name;
    final warmState = _warmStateService.stateFor(
      sourceId: normalizedSourceId,
      step: stepName,
    );
    final plan = _executionPolicyService.resolve(
      source: source,
      step: step,
      scene: scene,
      warmState: warmState,
    );
    _logger.info(
      'Source runtime execution plan',
      context: <String, Object?>{
        'sourceId': normalizedSourceId,
        'sourceName': source?.name,
        'step': step.name,
        'scene': scene.name,
        'containerKind': plan.containerKind.name,
        'warmState': plan.warmState.name,
        'serializeStartup': plan.serializeStartup,
        'markWarmOnSuccess': plan.markWarmOnSuccess,
      },
    );

    if (source != null &&
        source.enabled &&
        warmState == SourceRuntimeWarmState.cold) {
      _warmStateService.markWarming(
        sourceId: normalizedSourceId,
        step: stepName,
      );
    }

    try {
      final result = await action(plan);
      if (source != null && source.enabled && plan.markWarmOnSuccess) {
        _warmStateService.markWarm(
          sourceId: normalizedSourceId,
          step: stepName,
        );
      }
      return result;
    } catch (error, stackTrace) {
      if (error is SessionTaskCancelledException) {
        rethrow;
      }
      if (source != null && source.enabled) {
        _warmStateService.markUnstable(
          sourceId: normalizedSourceId,
          step: stepName,
        );
      }
      throw _normalizeRuntimeException(
        sourceId: normalizedSourceId,
        step: step,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  AppException _normalizeRuntimeException({
    required String sourceId,
    required SourceRuntimeExecutionStep step,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final stage = _errorStageForStep(step);
    if (error is AppException) {
      return error.copyWith(
        sourceId:
            error.sourceId?.trim().isNotEmpty == true
                ? error.sourceId
                : sourceId,
        stage: error.stage == ErrorStage.unknown ? stage : error.stage,
        stackTrace: error.stackTrace ?? stackTrace,
      );
    }

    final message = error.toString().trim();
    if (error is TimeoutException ||
        error is HttpException ||
        error is SocketException) {
      return NetworkException(
        briefMessage: message.isEmpty ? '网络请求失败。' : message,
        sourceId: sourceId,
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FormatException) {
      return DecodeException(
        briefMessage: message.isEmpty ? '响应解析失败。' : message,
        sourceId: sourceId,
        stage: stage,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return AppException(
      code: ErrorCode.unknown,
      briefMessage: message.isEmpty ? '脚本源执行失败。' : message,
      sourceId: sourceId,
      stage: stage,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  ErrorStage _errorStageForStep(SourceRuntimeExecutionStep step) {
    return switch (step) {
      SourceRuntimeExecutionStep.search => ErrorStage.search,
      SourceRuntimeExecutionStep.discoverCategories => ErrorStage.source,
      SourceRuntimeExecutionStep.discoverBooks => ErrorStage.source,
      SourceRuntimeExecutionStep.detail => ErrorStage.detail,
      SourceRuntimeExecutionStep.chapters => ErrorStage.toc,
      SourceRuntimeExecutionStep.content => ErrorStage.content,
    };
  }
}
