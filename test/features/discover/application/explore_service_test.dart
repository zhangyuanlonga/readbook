import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/discover/application/explore_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreService', () {
    test('loadDiscoverSources keeps enabled runtime discover sources only', () async {
      final service = ExploreService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 'novel_a', name: '小说源A'),
            _buildRegisteredSource(id: 'disabled_b', name: '禁用源B', enabled: false),
            _buildRegisteredSource(
              id: 'no_discover_c',
              name: '无发现源C',
              supportsDiscover: false,
            ),
          ],
        ),
      );

      final sources = await service.loadDiscoverSources();
      expect(sources.map((source) => source.id), <String>['novel_a']);
    });

    test('loadDiscoverSourceSummary reports enabled and discover counts', () async {
      final service = ExploreService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 's1', name: '源1'),
            _buildRegisteredSource(id: 's2', name: '源2', supportsDiscover: false),
            _buildRegisteredSource(id: 's3', name: '源3', enabled: false),
          ],
        ),
      );

      final summary = await service.loadDiscoverSourceSummary();
      expect(summary.enabledSourceCount, 2);
      expect(summary.discoverCapableCount, 1);
      expect(summary.discoverSources.map((item) => item.id), <String>['s1']);
    });

    test('parseCategories reads runtime categories and styles', () async {
      final runtimeSource = _buildRegisteredSource(id: 'json', name: '发现源');
      final service = ExploreService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[runtimeSource],
          categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
            'json': const <runtime_models.DiscoverCategory>[
              runtime_models.DiscoverCategory(
                title: '男频',
                url: '/rank/boy?page={{page}}',
                style: runtime_models.DiscoverCategoryStyle(
                  layoutFlexGrow: 2,
                  layoutFlexBasisPercent: 50,
                ),
              ),
              runtime_models.DiscoverCategory(title: '女频', url: '/rank/girl?page={{page}}'),
            ],
          },
        ),
      );

      final source = (await service.loadDiscoverSources()).first;
      final categories = await service.parseCategories(source);

      expect(categories, hasLength(2));
      expect(categories.first.title, '男频');
      expect(categories.first.url, '/rank/boy?page={{page}}');
      expect(categories.first.style.layoutFlexGrow, 2);
      expect(categories.first.style.layoutFlexBasisPercent, 50);
      expect(categories.last.title, '女频');
      expect(categories.last.isActionable, isTrue);
    });

    test('parseCategories allows direct discover source input', () async {
      final service = ExploreService(
        sourceRuntimeFacade: _FakeRuntimeFacade(sources: const <RegisteredSource>[]),
      );

      final categories = await service.parseCategories(
        const DiscoverSource(
          id: 'legacy',
          name: '旧源',
          baseUrl: 'https://example.com',
        ),
      );

      expect(categories, isEmpty);
    });

    test('loadBooks maps runtime discover books into domain books', () async {
      final runtimeSource = _buildRegisteredSource(id: 'mapped', name: '发现源');
      final service = ExploreService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[runtimeSource],
          categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
            'mapped': const <runtime_models.DiscoverCategory>[
              runtime_models.DiscoverCategory(title: '推荐', url: '/discover?page={{page}}'),
            ],
          },
          booksBySourceId: <String, List<runtime_models.Book>>{
            'mapped': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book-1',
                title: '测试书籍',
                author: '作者A',
                intro: '简介',
                detailUrl: 'https://example.com/book/1',
              ),
            ],
          },
        ),
      );

      final source = (await service.loadDiscoverSources()).first;
      final pageResult = await service.loadBooks(
        source: source,
        category: const ExploreCategoryItem(
          title: '推荐',
          url: '/discover?page={{page}}',
        ),
        page: 3,
        pageSize: 20,
      );

      expect(pageResult.page, 3);
      expect(pageResult.pageSize, 20);
      expect(pageResult.requestUrl, '');
      expect(pageResult.hasMore, isFalse);
      expect(pageResult.books, hasLength(1));
      expect(pageResult.books.first.id, 'book-1');
      expect(pageResult.books.first.title, '测试书籍');
      expect(pageResult.books.first.sourceId, 'mapped');
      expect(pageResult.books.first.detailUrl, 'https://example.com/book/1');
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  bool enabled = true,
  bool supportsDiscover = true,
  Set<String> capabilities = const <String>{'novel'},
  Future<List<runtime_models.DiscoverCategory>> Function()? discoverCategories,
  Future<List<runtime_models.Book>> Function(
    runtime_models.DiscoverCategory category,
    int page,
    int pageSize,
  )?
  discoverBooks,
}) {
  return RegisteredSource(
    runtime: SourceRuntimeInfo(
      id: id,
      name: name,
      group: '测试',
      revision: 'test',
    ),
    definition: RuntimeSourceDefinition(
      manifest: SourceManifest(
        name: name,
        group: '测试',
        author: 'tester',
        description: '',
        enabled: enabled,
        capabilities: capabilities,
      ),
      discoverCategories:
          !supportsDiscover
              ? null
              : (_) async => await (discoverCategories?.call() ?? const <runtime_models.DiscoverCategory>[]),
      discoverBooks:
          !supportsDiscover
              ? null
              : (_, category, page, pageSize) =>
                    discoverBooks?.call(category, page, pageSize) ??
                    const <runtime_models.Book>[],
      search: (_, __) async => const <runtime_models.Book>[],
      detail: (_, book) async => book,
      chapters: (_, __) async => const <runtime_models.Chapter>[],
      content:
          (_, __, ___) async =>
              const runtime_models.Content(title: '', content: ''),
    ),
  );
}

class _FakeRuntimeFacade extends SourceRuntimeFacade {
  _FakeRuntimeFacade({
    required this.sources,
    this.categoriesBySourceId = const <String, List<runtime_models.DiscoverCategory>>{},
    this.booksBySourceId = const <String, List<runtime_models.Book>>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, List<runtime_models.DiscoverCategory>> categoriesBySourceId;
  final Map<String, List<runtime_models.Book>> booksBySourceId;

  @override
  List<RegisteredSource> registeredScriptSources({bool enabledOnly = true}) {
    if (!enabledOnly) {
      return sources;
    }
    return sources
        .where((source) => source.definition.manifest.enabled)
        .toList(growable: false);
  }

  @override
  Future<ScriptSourceReloadReport> reloadScriptSources({bool enabledOnly = true}) async {
    return ScriptSourceReloadReport(
      loaded: registeredScriptSources(enabledOnly: enabledOnly),
      failures: const <ScriptSourceReloadFailure>[],
    );
  }

  @override
  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    return categoriesBySourceId[sourceId] ?? const <runtime_models.DiscoverCategory>[];
  }

  @override
  Future<List<runtime_models.Book>> discoverBooks({
    required String sourceId,
    required runtime_models.DiscoverCategory category,
    required int page,
    required int pageSize,
  }) async {
    return booksBySourceId[sourceId] ?? const <runtime_models.Book>[];
  }
}

class _FakeScriptSourceRepository implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}
