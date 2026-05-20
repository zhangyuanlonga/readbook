import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../core/session/session_cancellation.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'source_runtime_diagnostic_execution_container.dart';

class ScriptSourceReloadFailure {
  const ScriptSourceReloadFailure({required this.sourceId, required this.error});

  final String sourceId;
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
  SourceRuntimeFacade();

  @Deprecated('Legacy singleton kept only as compatibility shim.')
  static final SourceRuntimeFacade instance = SourceRuntimeFacade();

  Future<ScriptSourceReloadReport> reloadScriptSources({
    bool enabledOnly = true,
  }) async {
    return const ScriptSourceReloadReport(
      loaded: <RegisteredSource>[],
      failures: <ScriptSourceReloadFailure>[],
    );
  }

  List<RegisteredSource> registeredScriptSources({bool enabledOnly = true}) {
    return const <RegisteredSource>[];
  }

  RegisteredSource? registeredScriptSourceById(String sourceId) => null;

  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    return null;
  }

  Future<SourceRuntimeDiagnosticExecutionContainer?>
  createDiagnosticExecutionContainerById(
    String sourceId, {
    SessionCancellationHandle? cancellationHandle,
  }) async {
    return null;
  }

  void clearReadingFlow({
    required String sourceId,
    String detailUrl = '',
    String tocUrl = '',
    String title = '',
  }) {}

  SourceRuntimeDebugArtifactsSnapshot consumeLastDebugArtifacts(
    String sourceId,
  ) {
    return const SourceRuntimeDebugArtifactsSnapshot();
  }

  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.search, sourceId: sourceId);
  }

  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.source, sourceId: sourceId);
  }

  Future<List<runtime_models.Book>> discoverBooks({
    required String sourceId,
    required runtime_models.DiscoverCategory category,
    required int page,
    required int pageSize,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.source, sourceId: sourceId);
  }

  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.detail, sourceId: sourceId);
  }

  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.toc, sourceId: sourceId);
  }

  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    throw _removedRuntimeException(stage: ErrorStage.content, sourceId: sourceId);
  }
}

AppException _removedRuntimeException({
  required ErrorStage stage,
  required String sourceId,
}) {
  return AppException(
    code: ErrorCode.unknownSource,
    stage: stage,
    sourceId: sourceId.trim().isEmpty ? null : sourceId.trim(),
    briefMessage: '该本地脚本书源能力已移除，请重新搜索并加入服务器书源版本。',
  );
}
