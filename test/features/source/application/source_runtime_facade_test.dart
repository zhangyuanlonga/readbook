import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/script_source_repository_impl.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/features/source/application/script_source_runtime_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SourceRuntimeFacade', () {
    late AppDatabase database;
    late ScriptSourceRepositoryImpl repository;
    late _FakeScriptSourceRuntimeService runtimeService;
    late SourceRuntimeFacade facade;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = ScriptSourceRepositoryImpl(database);
      runtimeService = _FakeScriptSourceRuntimeService();
      facade = SourceRuntimeFacade(
        scriptSourceRepository: repository,
        scriptRuntimeService: runtimeService,
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('saves source and registers it into runtime', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(name: '脚本源一', group: '分组A'),
      );

      expect(saved.name, '脚本源一');
      expect(saved.group, '分组A');
      expect(saved.enabled, isTrue);
      expect(runtimeService.sourceById(saved.id), isNotNull);
    });

    test('reloads only enabled script sources by default', () async {
      final now = DateTime.parse('2026-03-25T12:00:00.000Z');
      await repository.upsert(
        ScriptSource(
          id: 'enabled_1',
          name: '启用源',
          sourceCode: _buildSourceCode(name: '启用源'),
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.upsert(
        ScriptSource(
          id: 'disabled_1',
          name: '停用源',
          sourceCode: _buildSourceCode(name: '停用源'),
          enabled: false,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final report = await facade.reloadScriptSources();

      expect(report.loaded, hasLength(1));
      expect(report.loaded.first.runtime.id, 'enabled_1');
      expect(runtimeService.sourceById('disabled_1'), isNull);
    });

    test('toggles runtime registration when enabled state changes', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(name: '可切换源'),
      );

      expect(runtimeService.sourceById(saved.id), isNotNull);

      await facade.setScriptSourceEnabled(id: saved.id, enabled: false);
      expect(runtimeService.sourceById(saved.id), isNull);

      await facade.setScriptSourceEnabled(id: saved.id, enabled: true);
      expect(runtimeService.sourceById(saved.id), isNotNull);
    });
  });
}

class _FakeScriptSourceRuntimeService extends ScriptSourceRuntimeService {
  _FakeScriptSourceRuntimeService() : super();

  @override
  Future<RegisteredSource> compileAndRegister({
    required String sourceCode,
    String? runtimeId,
    String revision = 'scratch',
  }) async {
    final name = _extractField(sourceCode, 'name') ?? '未命名脚本源';
    final group = _extractField(sourceCode, 'group') ?? '未分组';
    final author = _extractField(sourceCode, 'author') ?? 'unknown';
    final description = _extractField(sourceCode, 'description') ?? '';

    final definition = RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: group,
        author: author,
        description: description,
        enabled: true,
        capabilities: const <String>{'search', 'detail', 'chapters', 'content'},
      ),
      search: (_, __) async => const <runtime_models.Book>[],
      detail: (_, book) async => book,
      chapters: (_, __) async => const <runtime_models.Chapter>[],
      content:
          (_, __, chapter) async =>
              runtime_models.Content(title: chapter.title, content: ''),
    );

    final normalizedRuntimeId = runtimeId?.trim() ?? '';
    if (normalizedRuntimeId.isEmpty) {
      return registry.register(definition, revision: revision);
    }
    return registry.upsert(normalizedRuntimeId, definition, revision: revision);
  }

  String? _extractField(String sourceCode, String field) {
    final pattern = RegExp("$field\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]");
    final match = pattern.firstMatch(sourceCode);
    return match?.group(1)?.trim();
  }
}

String _buildSourceCode({
  required String name,
  String group = '默认分组',
  String author = 'tester',
  String description = 'desc',
}) {
  return """
export default {
  meta: {
    name: '$name',
    group: '$group',
    author: '$author',
    description: '$description',
  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title, content: '' }; },
}
""";
}
