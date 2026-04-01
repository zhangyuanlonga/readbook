import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SearchService', () {
    test('filters runtime sources by content mode', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(
              id: 'novel_1',
              name: '小说源',
              capabilities: const <String>{'novel'},
            ),
            _buildRegisteredSource(
              id: 'manga_1',
              name: '漫画源',
              capabilities: const <String>{'manga'},
            ),
          ],
        ),
      );

      final novelReport = await service.search(
        keyword: '凡人',
        contentMode: SearchContentMode.novel,
      );
      expect(novelReport.sourceCount, 1);
      expect(novelReport.sourceNames.keys, <String>['novel_1']);

      final mangaReport = await service.search(
        keyword: '凡人',
        contentMode: SearchContentMode.manga,
      );
      expect(mangaReport.sourceCount, 1);
      expect(mangaReport.sourceNames.keys, <String>['manga_1']);
    });

    test('supports searching with specified source ids', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 's1', name: '源1'),
            _buildRegisteredSource(id: 's2', name: '源2'),
          ],
          booksBySourceId: <String, List<runtime_models.Book>>{
            's1': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book_s1',
                title: 'A书',
                author: '作者A',
                detailUrl: 'https://example.com/book/a',
              ),
            ],
            's2': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book_s2',
                title: 'B书',
                author: '作者B',
                detailUrl: 'https://example.com/book/b',
              ),
            ],
          },
        ),
      );

      final report = await service.search(
        keyword: '凡人',
        sourceIds: const <String>['s2'],
      );

      expect(report.sourceCount, 1);
      expect(report.books, hasLength(1));
      expect(report.books.first.title, 'B书');
    });

    test('includes enabled script runtime sources in search results', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 'script_source_1', name: '脚本源一'),
          ],
          booksBySourceId: <String, List<runtime_models.Book>>{
            'script_source_1': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'script_book_1',
                title: '脚本书源结果',
                author: '脚本作者',
                detailUrl: 'https://script.example.com/book/1',
              ),
            ],
          },
        ),
      );

      final report = await service.search(keyword: '凡人');

      expect(report.sourceCount, 1);
      expect(report.books, hasLength(1));
      expect(report.books.first.title, '脚本书源结果');
      expect(report.books.first.sourceId, 'script_source_1');
    });

    test('aggregates same title and author when enabled', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 's1', name: '源1'),
            _buildRegisteredSource(id: 's2', name: '源2'),
          ],
          booksBySourceId: <String, List<runtime_models.Book>>{
            's1': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book_1',
                title: '凡人修仙传',
                author: '忘语',
                detailUrl: 'https://example.com/book/1',
              ),
            ],
            's2': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book_2',
                title: '凡人修仙传',
                author: '忘语',
                detailUrl: 'https://example.com/book/2',
                intro: '另一来源',
              ),
            ],
          },
        ),
      );

      final report = await service.search(
        keyword: '凡人修仙传',
        aggregateByTitleAuthor: true,
      );

      expect(report.books, hasLength(1));
      expect(report.bookSourceHitCounts.values.single, 2);
      expect(report.bookSourceHits.values.single, hasLength(2));
    });

    test('reports unknown source when no runtime source is available', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(sources: const <RegisteredSource>[]),
      );

      await expectLater(
        service.search(keyword: '凡人'),
        throwsA(isA<AppException>()),
      );
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  bool enabled = true,
  Set<String> capabilities = const <String>{'novel'},
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
    this.booksBySourceId = const <String, List<runtime_models.Book>>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
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
  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
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
