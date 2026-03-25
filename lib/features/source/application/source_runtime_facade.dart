import 'package:uuid/uuid.dart';

import '../../../data/datasources/local/app_database.dart';
import '../../../data/repositories/script_source_repository_impl.dart';
import '../../../domain/entities/script_source.dart';
import '../../../domain/repositories/script_source_repository.dart';
import '../../../runtime/sources/source_registry.dart';
import '../../../runtime/sources/source_result_models.dart' as runtime_models;
import 'script_source_runtime_service.dart';

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

class SourceRuntimeFacade {
  static final SourceRuntimeFacade instance = SourceRuntimeFacade(
    scriptSourceRepository: ScriptSourceRepositoryImpl(AppDatabase.instance),
  );

  SourceRuntimeFacade({
    required ScriptSourceRepository scriptSourceRepository,
    ScriptSourceRuntimeService? scriptRuntimeService,
    Uuid? uuid,
  }) : _scriptSourceRepository = scriptSourceRepository,
       _scriptRuntimeService =
           scriptRuntimeService ?? ScriptSourceRuntimeService(),
       _uuid = uuid ?? const Uuid();

  final ScriptSourceRepository _scriptSourceRepository;
  final ScriptSourceRuntimeService _scriptRuntimeService;
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

  Future<ScriptSource> saveScriptSource({
    required String sourceCode,
    String? id,
    bool enabled = true,
  }) async {
    final normalizedCode = sourceCode.trim();
    if (normalizedCode.isEmpty) {
      throw StateError('Script source code cannot be empty.');
    }

    final persistedId = id?.trim().isNotEmpty == true ? id!.trim() : _uuid.v4();
    final existing = await _scriptSourceRepository.getById(persistedId);
    final registered = await _scriptRuntimeService.compileAndRegister(
      sourceCode: normalizedCode,
      runtimeId: persistedId,
      revision: 'script:${DateTime.now().millisecondsSinceEpoch}',
    );

    final now = DateTime.now();
    final manifest = registered.definition.manifest;
    final nextSource = ScriptSource(
      id: persistedId,
      name: manifest.name,
      group: manifest.group.trim().isEmpty ? null : manifest.group.trim(),
      author: manifest.author.trim().isEmpty ? null : manifest.author.trim(),
      description:
          manifest.description.trim().isEmpty
              ? null
              : manifest.description.trim(),
      sourceCode: normalizedCode,
      enabled: enabled,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _scriptSourceRepository.upsert(nextSource);

    if (!enabled) {
      _scriptRuntimeService.removeRegisteredSource(persistedId);
    }
    return nextSource;
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
    await _scriptSourceRepository.deleteById(id);
    _scriptRuntimeService.removeRegisteredSource(id);
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

  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
  }) {
    return _scriptRuntimeService.search(sourceId: sourceId, keyword: keyword);
  }

  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    return _scriptRuntimeService.detail(sourceId: sourceId, book: book);
  }

  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) {
    return _scriptRuntimeService.chapters(sourceId: sourceId, book: book);
  }

  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) {
    return _scriptRuntimeService.content(
      sourceId: sourceId,
      book: book,
      chapter: chapter,
    );
  }
}
