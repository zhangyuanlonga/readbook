import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/search/application/search_hit_cache_service.dart';
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

  group('SearchService hit cache', () {
    test('persists source hits after search completed', () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      final hitCacheService = SearchHitCacheService(database: database);
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 's1', name: '源1'),
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
          },
        ),
        searchHitCacheService: hitCacheService,
      );

      final report = await service.search(keyword: '凡人修仙传');
      expect(report.books, hasLength(1));

      final counts = await hitCacheService.loadSourceHitCounts(
        title: '凡人修仙传',
        author: '忘语',
      );
      expect(counts['s1'], 1);

      await database.close();
    });

    test('does not fail search when hit cache persistence throws', () async {
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 's1', name: '源1'),
          ],
          booksBySourceId: <String, List<runtime_models.Book>>{
            's1': const <runtime_models.Book>[
              runtime_models.Book(
                id: 'book_1',
                title: '测试书',
                author: '',
                detailUrl: 'https://example.com/book/1',
              ),
            ],
          },
        ),
        searchHitCacheService: _ThrowingSearchHitCacheService(),
      );

      final report = await service.search(keyword: '测试书');
      expect(report.books, hasLength(1));
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
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
    return sources;
  }

  @override
  Future<ScriptSourceReloadReport> reloadScriptSources({bool enabledOnly = true}) async {
    return ScriptSourceReloadReport(
      loaded: sources,
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

class _ThrowingSearchHitCacheService extends SearchHitCacheService {
  _ThrowingSearchHitCacheService()
    : super(database: AppDatabase(executor: NativeDatabase.memory()));

  @override
  Future<void> recordBooks(
    Iterable<Book> books, {
    Map<String, String> sourceNames = const <String, String>{},
  }) {
    throw StateError('mock cache write failed');
  }
}
