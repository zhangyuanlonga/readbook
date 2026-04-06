import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/script_source_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/features/source/application/script_source_runtime_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceRuntimeFacade', () {
    late AppDatabase database;
    late ScriptSourceRepositoryImpl repository;
    late _FakeScriptSourceRuntimeService runtimeService;
    late SourceRuntimeFacade facade;
    late SourceHealthService healthService;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = ScriptSourceRepositoryImpl(database);
      runtimeService = _FakeScriptSourceRuntimeService();
      healthService = SourceHealthService();
      facade = SourceRuntimeFacade(
        scriptSourceRepository: repository,
        scriptRuntimeService: runtimeService,
        sourceHealthService: healthService,
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
      expect(saved.checkKeyword, '凡人修仙传');
      expect(saved.enabled, isTrue);
      expect(runtimeService.sourceById(saved.id), isNotNull);
      expect(
        healthService.snapshotFor(saved.id).level,
        SourceHealthLevel.unchecked,
      );
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

    test('prefers literal meta.name from source code when saving', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(name: '🌐 69书吧'),
      );

      expect(saved.name, '🌐 69书吧');
      expect(runtimeService.sourceById(saved.id)?.runtime.name, isNotNull);
    });

    test('ignores meta.enabled when host source is enabled', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(
          name: '宿主启用源',
          includeMetaEnabled: true,
          metaEnabled: false,
        ),
        enabled: true,
      );

      expect(saved.enabled, isTrue);
      expect(runtimeService.sourceById(saved.id), isNotNull);
      expect(
        facade
            .registeredScriptSources(enabledOnly: true)
            .map((source) => source.runtime.id),
        contains(saved.id),
      );
    });

    test('always uses isolated runtime for detail', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(name: '隔离详情源'),
      );
      const book = runtime_models.Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );

      await facade.detail(sourceId: saved.id, book: book);
      await facade.detail(sourceId: saved.id, book: book);

      expect(runtimeService.isolatedDetailCalls, 2);
      expect(runtimeService.detailCalls, 0);
    });

    test('always uses isolated runtime for content', () async {
      final saved = await facade.saveScriptSource(
        sourceCode: _buildSourceCode(name: '隔离正文源'),
      );
      const book = runtime_models.Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );
      const chapter = runtime_models.Chapter(
        title: '第一章',
        url: 'https://example.com/book/1/ch1',
        index: 0,
      );

      await facade.content(sourceId: saved.id, book: book, chapter: chapter);
      await facade.content(sourceId: saved.id, book: book, chapter: chapter);

      expect(runtimeService.isolatedContentCalls, 2);
      expect(runtimeService.contentCalls, 0);
    });
  });
}

class _FakeScriptSourceRuntimeService extends ScriptSourceRuntimeService {
  _FakeScriptSourceRuntimeService() : super();

  int detailCalls = 0;
  int isolatedDetailCalls = 0;
  int contentCalls = 0;
  int isolatedContentCalls = 0;

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
    final checkKeyword = _extractField(sourceCode, 'checkKeyword');
    final enabled = _extractBoolField(sourceCode, 'enabled') ?? true;

    final definition = RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: group,
        author: author,
        description: description,
        checkKeyword: checkKeyword,
        enabled: enabled,
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

  @override
  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    detailCalls += 1;
    return book;
  }

  @override
  Future<runtime_models.Book> detailIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
  }) async {
    isolatedDetailCalls += 1;
    return book;
  }

  @override
  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    contentCalls += 1;
    return runtime_models.Content(title: chapter.title, content: '正文');
  }

  @override
  Future<runtime_models.Content> contentIsolated({
    required String sourceId,
    required String sourceCode,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    isolatedContentCalls += 1;
    return runtime_models.Content(title: chapter.title, content: '正文');
  }

  String? _extractField(String sourceCode, String field) {
    final pattern = RegExp("$field\\s*:\\s*['\\\"]([^'\\\"]+)['\\\"]");
    final match = pattern.firstMatch(sourceCode);
    return match?.group(1)?.trim();
  }

  bool? _extractBoolField(String sourceCode, String field) {
    final pattern = RegExp('$field\\s*:\\s*(true|false)');
    final match = pattern.firstMatch(sourceCode);
    final raw = match?.group(1);
    if (raw == null) {
      return null;
    }
    return raw == 'true';
  }
}

String _buildSourceCode({
  required String name,
  String group = '默认分组',
  String author = 'tester',
  String description = 'desc',
  String checkKeyword = '凡人修仙传',
  bool includeMetaEnabled = false,
  bool metaEnabled = true,
}) {
  final enabledLine =
      includeMetaEnabled ? "    enabled: $metaEnabled,\n" : '';
  return """
export default {
  meta: {
    name: '$name',
    group: '$group',
    author: '$author',
    description: '$description',
    checkKeyword: '$checkKeyword',
$enabledLine  },
  async search(ctx, keyword) { return []; },
  async detail(ctx, book) { return book; },
  async chapters(ctx, book) { return []; },
  async content(ctx, book, chapter) { return { title: chapter.title, content: '' }; },
}
""";
}
