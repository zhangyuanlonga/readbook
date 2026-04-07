import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/source/application/source_check_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_diagnostic_execution_container.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_scheduler_service.dart';
import 'package:shuxiang_reading_next/runtime/session/source_session.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
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

    test('batch check creates and disposes diagnostic container per source', () async {
      final diagnosticOne = _FakeDiagnosticExecutionContainer(
        books: const <runtime_models.Book>[
          runtime_models.Book(
            title: '凡人修仙传',
            author: '忘语',
            detailUrl: 'https://example.com/book/1',
          ),
        ],
        detailBook: const runtime_models.Book(
          title: '凡人修仙传',
          author: '忘语',
          detailUrl: 'https://example.com/book/1',
        ),
        chapterList: const <runtime_models.Chapter>[],
        contentResult: const runtime_models.Content(title: '', content: ''),
      );
      final diagnosticTwo = _FakeDiagnosticExecutionContainer(
        books: const <runtime_models.Book>[
          runtime_models.Book(
            title: '斗破苍穹',
            author: '天蚕土豆',
            detailUrl: 'https://example.com/book/2',
          ),
        ],
        detailBook: const runtime_models.Book(
          title: '斗破苍穹',
          author: '天蚕土豆',
          detailUrl: 'https://example.com/book/2',
        ),
        chapterList: const <runtime_models.Chapter>[],
        contentResult: const runtime_models.Content(title: '', content: ''),
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
          _buildRegisteredSource(id: 's2', name: '源2'),
        ],
        diagnosticContainerBySourceId:
            <String, SourceRuntimeDiagnosticExecutionContainer>{
              's1': diagnosticOne,
              's2': diagnosticTwo,
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
      expect(diagnosticOne.searchCalls, 1);
      expect(diagnosticTwo.searchCalls, 1);
      expect(diagnosticOne.disposed, isTrue);
      expect(diagnosticTwo.disposed, isTrue);
      expect(runtimeFacade.searchCalls, 0);
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

    test('skips source check when higher-priority task is active', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
        ],
      );
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: SourceHealthService(),
        taskScheduler: _BlockingScheduler(),
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
      );

      expect(result.status, SourceCheckStatus.skipped);
      expect(result.message, contains('更高优先级'));
    });

    test('searchAndDetail updates detail-related health progress', () async {
      const detailBook = runtime_models.Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );
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
        detailBySourceId: const <String, runtime_models.Book>{
          's1': detailBook,
        },
      );
      final healthService = SourceHealthService();
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
        level: SourceCheckLevel.searchAndDetail,
      );

      final snapshot = healthService.snapshotFor('s1');
      expect(result.stepReached, SourceCheckStep.detail);
      expect(snapshot.totalSuccesses, 2);
      expect(snapshot.lastSuccessAt, isNotNull);
      expect(snapshot.level, SourceHealthLevel.healthy);
    });

    test('fullReadPath updates chapters and content health progress', () async {
      const detailBook = runtime_models.Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );
      const readableChapter = runtime_models.Chapter(
        title: '第一章',
        url: 'https://example.com/book/1/ch1',
        index: 0,
      );
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
        detailBySourceId: const <String, runtime_models.Book>{
          's1': detailBook,
        },
        chaptersBySourceId: const <String, List<runtime_models.Chapter>>{
          's1': <runtime_models.Chapter>[readableChapter],
        },
        contentBySourceId: const <String, runtime_models.Content>{
          's1': runtime_models.Content(title: '第一章', content: '正文内容'),
        },
      );
      final healthService = SourceHealthService();
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
        level: SourceCheckLevel.fullReadPath,
      );

      final snapshot = healthService.snapshotFor('s1');
      expect(result.status, SourceCheckStatus.healthy);
      expect(result.stepReached, SourceCheckStep.content);
      expect(snapshot.totalSuccesses, 4);
      expect(snapshot.level, SourceHealthLevel.healthy);
    });

    test('source check prefers diagnostic execution container and disposes it', () async {
      const detailBook = runtime_models.Book(
        title: '凡人修仙传',
        author: '忘语',
        detailUrl: 'https://example.com/book/1',
      );
      const readableChapter = runtime_models.Chapter(
        title: '第一章',
        url: 'https://example.com/book/1/ch1',
        index: 0,
      );
      final diagnosticContainer = _FakeDiagnosticExecutionContainer(
        books: const <runtime_models.Book>[
          runtime_models.Book(
            title: '凡人修仙传',
            author: '忘语',
            detailUrl: 'https://example.com/book/1',
          ),
        ],
        detailBook: detailBook,
        chapterList: const <runtime_models.Chapter>[readableChapter],
        contentResult: const runtime_models.Content(title: '第一章', content: '正文内容'),
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
        ],
        diagnosticContainerBySourceId: <String, SourceRuntimeDiagnosticExecutionContainer>{
          's1': diagnosticContainer,
        },
      );
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: SourceHealthService(),
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
        level: SourceCheckLevel.fullReadPath,
      );

      expect(result.status, SourceCheckStatus.healthy);
      expect(diagnosticContainer.searchCalls, 1);
      expect(diagnosticContainer.detailCalls, 1);
      expect(diagnosticContainer.chaptersCalls, 1);
      expect(diagnosticContainer.contentCalls, 1);
      expect(diagnosticContainer.disposed, isTrue);
      expect(runtimeFacade.searchCalls, 0);
      expect(runtimeFacade.detailCalls, 0);
      expect(runtimeFacade.chaptersCalls, 0);
      expect(runtimeFacade.contentCalls, 0);
    });

    test('browser-capable successful check marks source as warning', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 's1',
            name: '源1',
            capabilities: const <String>{'search', 'detail', 'chapters', 'content', 'browser'},
          ),
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
      final service = SourceCheckService(
        sourceRuntimeFacade: runtimeFacade,
        sourceHealthService: healthService,
      );

      final result = await service.checkSource(
        sourceId: 's1',
        keyword: '凡人修仙传',
      );

      final snapshot = healthService.snapshotFor('s1');
      expect(result.status, SourceCheckStatus.warning);
      expect(snapshot.level, SourceHealthLevel.warning);
      expect(snapshot.challengeCount, 1);
    });

    test('resolveCheckKeyword prefers input then manifest then fallback', () {
      expect(
        SourceCheckService.resolveCheckKeyword(
          '斗破苍穹',
          manifestKeyword: '凡人修仙传',
        ),
        '斗破苍穹',
      );
      expect(
        SourceCheckService.resolveCheckKeyword(
          '',
          manifestKeyword: '凡人修仙传',
        ),
        '凡人修仙传',
      );
      expect(
        SourceCheckService.resolveCheckKeyword('', manifestKeyword: null),
        SourceCheckService.defaultCheckKeyword,
      );
    });
  });
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  Set<String> capabilities = const <String>{'search', 'detail', 'chapters', 'content'},
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
    this.detailBySourceId = const <String, runtime_models.Book>{},
    this.chaptersBySourceId = const <String, List<runtime_models.Chapter>>{},
    this.contentBySourceId = const <String, runtime_models.Content>{},
    this.diagnosticContainerBySourceId =
        const <String, SourceRuntimeDiagnosticExecutionContainer>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, List<runtime_models.Book>> booksBySourceId;
  final Map<String, runtime_models.Book> detailBySourceId;
  final Map<String, List<runtime_models.Chapter>> chaptersBySourceId;
  final Map<String, runtime_models.Content> contentBySourceId;
  final Map<String, SourceRuntimeDiagnosticExecutionContainer>
  diagnosticContainerBySourceId;
  int searchCalls = 0;
  int detailCalls = 0;
  int chaptersCalls = 0;
  int contentCalls = 0;

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
  Future<SourceRuntimeDiagnosticExecutionContainer?>
  createDiagnosticExecutionContainerById(
    String sourceId, {
    SessionCancellationHandle? cancellationHandle,
  }) async {
    return diagnosticContainerBySourceId[sourceId];
  }

  @override
  Future<List<runtime_models.Book>> search({
    required String sourceId,
    required String keyword,
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    searchCalls += 1;
    return booksBySourceId[sourceId] ?? const <runtime_models.Book>[];
  }

  @override
  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    detailCalls += 1;
    return detailBySourceId[sourceId] ?? book;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    chaptersCalls += 1;
    return chaptersBySourceId[sourceId] ?? const <runtime_models.Chapter>[];
  }

  @override
  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    contentCalls += 1;
    return contentBySourceId[sourceId] ??
        runtime_models.Content(title: chapter.title, content: '');
  }
}

class _FakeDiagnosticExecutionContainer
    implements SourceRuntimeDiagnosticExecutionContainer {
  _FakeDiagnosticExecutionContainer({
    required this.books,
    required this.detailBook,
    required this.chapterList,
    required this.contentResult,
  });

  final List<runtime_models.Book> books;
  final runtime_models.Book detailBook;
  final List<runtime_models.Chapter> chapterList;
  final runtime_models.Content contentResult;
  int searchCalls = 0;
  int detailCalls = 0;
  int chaptersCalls = 0;
  int contentCalls = 0;
  bool disposed = false;

  @override
  String get sourceId => 's1';

  @override
  String get sourceName => '源1';

  @override
  Future<List<runtime_models.Book>> search(String keyword) async {
    searchCalls += 1;
    return books;
  }

  @override
  Future<runtime_models.Book> detail(runtime_models.Book book) async {
    detailCalls += 1;
    return detailBook;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters(runtime_models.Book book) async {
    chaptersCalls += 1;
    return chapterList;
  }

  @override
  Future<runtime_models.Content> content(
    runtime_models.Book book,
    runtime_models.Chapter chapter,
  ) async {
    contentCalls += 1;
    return contentResult;
  }

  @override
  void dispose() {
    disposed = true;
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

class _BlockingScheduler extends SourceRuntimeSchedulerService {
  @override
  Future<SourceRuntimeTaskLease?> acquire({
    required SourceRuntimeSchedulerScene scene,
    required Iterable<String> conflictKeys,
    bool cancelIfBlockedByHigherPriority = false,
  }) async {
    return null;
  }
}
