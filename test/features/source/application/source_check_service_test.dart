import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/entities/source_health.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/source/application/source_check_service.dart';
import 'package:flutter_appread/features/source/application/source_health_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/session/source_session.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceCheckService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('single source searchOnly returns healthy result', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          's1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '凡人修仙传',
              author: '忘语',
              detailUrl: 'https://example.com/book/1',
            ),
          ],
        },
      );
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: SourceHealthService(),
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
      );

      expect(result.status, SourceCheckStatus.healthy);
      expect(result.stepReached, SourceCheckStep.search);
      expect(result.canAutoDisable, isFalse);
    });

    test('batch check marks empty search result as failed', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
          _buildRegisteredSource(id: 's2', name: '源2'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          's1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '凡人修仙传',
              author: '忘语',
              detailUrl: 'https://example.com/book/1',
            ),
          ],
          's2': const <runtime_models.Book>[],
        },
      );
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: SourceHealthService(),
      );

      final results = await service.checkSources(
        sourceIds: const <String>['s1', 's2'],
        keyword: '凡人修仙传',
      );

      expect(results, hasLength(2));
      expect(results.first.status, SourceCheckStatus.healthy);
      expect(results.last.status, SourceCheckStatus.failed);
      expect(results.last.canBatchDelete, isTrue);
    });

    test('batch check can skip cooling down source', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          's1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '凡人修仙传',
              author: '忘语',
              detailUrl: 'https://example.com/book/1',
            ),
          ],
        },
      );
      final healthService = SourceHealthService();
      healthService.upsert(
        SourceHealthSnapshot(
          sourceId: 's1',
          level: SourceHealthLevel.unavailable,
          enabled: true,
          cooldownUntil: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
        skipCooldown: true,
      );

      expect(result.status, SourceCheckStatus.skipped);
      expect(result.message, contains('冷却中'));
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
  Future<RegisteredSource?> ensureRegisteredScriptSourceById(
    String sourceId,
  ) async {
    for (final source in sources) {
      if (source.runtime.id == sourceId) {
        return source;
      }
    }
    return null;
  }

  @override
  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
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
