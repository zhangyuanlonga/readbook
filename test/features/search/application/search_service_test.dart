import 'dart:async';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/core/logging/app_logger.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
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
                title: 'A书',
                author: '作者A',
                detailUrl: 'https://example.com/book/a',
              ),
            ],
            's2': const <runtime_models.Book>[
              runtime_models.Book(
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
                title: '凡人修仙传',
                author: '忘语',
                detailUrl: 'https://example.com/book/1',
              ),
            ],
            's2': const <runtime_models.Book>[
              runtime_models.Book(
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

    test('search stage does not invoke detail chapters or content', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'script_source_1', name: '脚本源一'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          'script_source_1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '最小搜索结果',
              author: '',
              detailUrl: 'https://script.example.com/book/1',
            ),
          ],
        },
      );
      final service = SearchService(sourceRuntimeFacade: runtimeFacade);

      final report = await service.search(keyword: '凡人');

      expect(report.books, hasLength(1));
      expect(runtimeFacade.searchCallCount, 1);
      expect(runtimeFacade.detailCallCount, 0);
      expect(runtimeFacade.chaptersCallCount, 0);
      expect(runtimeFacade.contentCallCount, 0);
    });

    test('auto switch scenario limits sources and disables interactive challenge', () async {
      final sources = List<RegisteredSource>.generate(
        12,
        (index) => _buildRegisteredSource(id: 's$index', name: '源$index'),
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: sources,
        booksBySourceId: <String, List<runtime_models.Book>>{
          for (final source in sources)
            source.runtime.id: <runtime_models.Book>[
              runtime_models.Book(
                title: '书${source.runtime.id}',
                author: '作者',
                detailUrl: 'https://example.com/${source.runtime.id}',
              ),
            ],
        },
      );
      final service = SearchService(sourceRuntimeFacade: runtimeFacade);

      final report = await service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.autoSwitchSource,
      );

      expect(report.sourceCount, 8);
      expect(runtimeFacade.searchCalls, hasLength(8));
      expect(
        runtimeFacade.searchCalls.every((call) => !call.allowInteractiveChallenge),
        isTrue,
      );
    });

    test('switch source scenario keeps selected sources and allows interactive challenge', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
          _buildRegisteredSource(id: 's2', name: '源2'),
          _buildRegisteredSource(id: 's3', name: '源3'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          's1': const <runtime_models.Book>[],
          's2': const <runtime_models.Book>[],
          's3': const <runtime_models.Book>[],
        },
      );
      final service = SearchService(sourceRuntimeFacade: runtimeFacade);

      final report = await service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.switchSource,
        sourceIds: const <String>['s2', 's3'],
      );

      expect(report.sourceCount, 2);
      expect(
        runtimeFacade.searchCalls.map((call) => call.sourceId),
        unorderedEquals(<String>['s2', 's3']),
      );
      expect(
        runtimeFacade.searchCalls.every((call) => call.allowInteractiveChallenge),
        isTrue,
      );
    });

    test('search debug logging includes profile summary', () async {
      final logger = _RecordingLogger();
      final service = SearchService(
        sourceRuntimeFacade: _FakeRuntimeFacade(
          sources: <RegisteredSource>[
            _buildRegisteredSource(id: 'http', name: '轻源'),
            _buildRegisteredSource(
              id: 'browser',
              name: '浏览器源',
              capabilities: const <String>{'novel', 'browser'},
            ),
            _buildRegisteredSource(
              id: 'heavy',
              name: '重脚本源',
              capabilities: const <String>{'novel', 'js-heavy'},
            ),
          ],
          booksBySourceId: <String, List<runtime_models.Book>>{
            'http': const <runtime_models.Book>[],
            'browser': const <runtime_models.Book>[],
            'heavy': const <runtime_models.Book>[],
          },
        ),
        logger: logger,
      );
      service.setSearchDebugLoggingEnabled(true);

      await service.search(keyword: '凡人');

      final started = logger.infoLogs.firstWhere(
        (entry) => entry.message == 'Search started',
      );
      expect(started.context['profileSummary'], isNotNull);
      expect(
        started.context['profileSummary'],
        containsPair('httpLight', 1),
      );
      expect(
        started.context['profileSummary'],
        containsPair('browserHeavy', 1),
      );
      expect(
        started.context['profileSummary'],
        containsPair('jsHeavy', 1),
      );
    });

    test('budget scheduler does not exceed total budget', () async {
      final controls = _BudgetSearchControls(
        costsBySourceId: <String, int>{
          'browser': 3,
          'http1': 1,
          'http2': 1,
        },
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser',
            name: '浏览器源',
            capabilities: const <String>{'novel', 'browser'},
          ),
          _buildRegisteredSource(id: 'http1', name: '轻源1'),
          _buildRegisteredSource(id: 'http2', name: '轻源2'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          'browser': const <runtime_models.Book>[
            runtime_models.Book(
              title: '浏览器结果',
              author: '',
              detailUrl: 'https://example.com/browser',
            ),
          ],
          'http1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源1结果',
              author: '',
              detailUrl: 'https://example.com/http1',
            ),
          ],
          'http2': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源2结果',
              author: '',
              detailUrl: 'https://example.com/http2',
            ),
          ],
        },
        budgetControls: controls,
      );
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
        maxConcurrentSources: 3,
      );

      final searchFuture = service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.switchSource,
      );

      await controls.waitUntilStartedCount(1);
      expect(controls.maxObservedBudget, 3);
      expect(runtimeFacade.searchCalls.map((call) => call.sourceId), <String>[
        'browser',
      ]);

      controls.complete('browser');
      await controls.waitUntilStartedCount(3);
      expect(controls.maxObservedBudget, 3);
      controls.complete('http1');
      controls.complete('http2');

      final report = await searchFuture;
      expect(report.books, hasLength(3));
      expect(controls.maxObservedBudget, 3);
    });

    test('macos uses conservative default budget for heavy runtime search', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'search.system.maxConcurrentSources': 6,
      });
      final controls = _BudgetSearchControls(
        costsBySourceId: <String, int>{
          'browser': 3,
          'http1': 1,
          'http2': 1,
        },
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser',
            name: '浏览器源',
            capabilities: const <String>{'novel', 'browser'},
          ),
          _buildRegisteredSource(id: 'http1', name: '轻源1'),
          _buildRegisteredSource(id: 'http2', name: '轻源2'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          'browser': const <runtime_models.Book>[
            runtime_models.Book(
              title: '浏览器结果',
              author: '',
              detailUrl: 'https://example.com/browser',
            ),
          ],
          'http1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源1结果',
              author: '',
              detailUrl: 'https://example.com/http1',
            ),
          ],
          'http2': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源2结果',
              author: '',
              detailUrl: 'https://example.com/http2',
            ),
          ],
        },
        budgetControls: controls,
      );
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
        runtimePlatform: SearchRuntimePlatform.macos,
      );

      final searchFuture = service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.globalSearch,
      );

      await controls.waitUntilStartedCount(2);
      expect(controls.maxObservedBudget, 2);
      expect(
        runtimeFacade.searchCalls.map((call) => call.sourceId),
        <String>['http1', 'http2'],
      );

      controls.complete('http1');
      controls.complete('http2');
      await controls.waitUntilStartedCount(3);
      expect(
        runtimeFacade.searchCalls.map((call) => call.sourceId),
        <String>['http1', 'http2', 'browser'],
      );
      controls.complete('browser');

      final report = await searchFuture;
      expect(report.books, hasLength(3));
      expect(controls.maxObservedBudget, 3);
    });

    test('android uses higher default budget for mixed runtime search', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'search.system.maxConcurrentSources': 6,
      });
      final controls = _BudgetSearchControls(
        costsBySourceId: <String, int>{
          'browser': 3,
          'http1': 1,
          'http2': 1,
        },
      );
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser',
            name: '浏览器源',
            capabilities: const <String>{'novel', 'browser'},
          ),
          _buildRegisteredSource(id: 'http1', name: '轻源1'),
          _buildRegisteredSource(id: 'http2', name: '轻源2'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          'browser': const <runtime_models.Book>[
            runtime_models.Book(
              title: '浏览器结果',
              author: '',
              detailUrl: 'https://example.com/browser',
            ),
          ],
          'http1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源1结果',
              author: '',
              detailUrl: 'https://example.com/http1',
            ),
          ],
          'http2': const <runtime_models.Book>[
            runtime_models.Book(
              title: '轻源2结果',
              author: '',
              detailUrl: 'https://example.com/http2',
            ),
          ],
        },
        budgetControls: controls,
      );
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
        runtimePlatform: SearchRuntimePlatform.android,
      );

      final searchFuture = service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.globalSearch,
      );

      await controls.waitUntilStartedCount(3);
      expect(controls.maxObservedBudget, 5);
      controls.complete('browser');
      controls.complete('http1');
      controls.complete('http2');

      final report = await searchFuture;
      expect(report.books, hasLength(3));
      expect(controls.maxObservedBudget, 5);
    });

    test('cancelled search does not report in-flight task as failure or launch follow-up task', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'search.system.maxConcurrentSources': 1,
      });
      final token = SearchCancellationToken();
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 's1', name: '源1'),
          _buildRegisteredSource(id: 's2', name: '源2'),
        ],
        booksBySourceId: <String, List<runtime_models.Book>>{
          's1': const <runtime_models.Book>[
            runtime_models.Book(
              title: '书1',
              author: '',
              detailUrl: 'https://example.com/s1',
            ),
          ],
          's2': const <runtime_models.Book>[
            runtime_models.Book(
              title: '书2',
              author: '',
              detailUrl: 'https://example.com/s2',
            ),
          ],
        },
        responseDelayBySourceId: <String, Duration>{
          's1': const Duration(milliseconds: 80),
        },
      );
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
      );

      final searchFuture = service.search(
        keyword: '凡人',
        cancellationToken: token,
      );

      while (runtimeFacade.searchCalls.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      token.cancel();

      final report = await searchFuture;
      expect(report.failedSourceCount, 0);
      expect(report.successSourceCount, 0);
      expect(report.books, isEmpty);
      expect(runtimeFacade.searchCalls.map((call) => call.sourceId), <String>[
        's1',
      ]);
    });

    test('cooldown skips source after repeated failures', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser_source',
            name: '浏览器失败源',
            capabilities: const <String>{'novel', 'browser'},
          ),
        ],
      );
      runtimeFacade.throwOnSearchForSourceId = 'browser_source';
      final logger = _RecordingLogger();
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
        logger: logger,
      );
      service.setSearchDebugLoggingEnabled(true);

      final first = await service.search(keyword: '凡人');
      final second = await service.search(keyword: '凡人');

      expect(first.failedSourceCount, 1);
      expect(second.failedSourceCount, 1);
      await expectLater(
        service.search(keyword: '凡人'),
        throwsA(isA<UnknownSourceException>()),
      );
      expect(runtimeFacade.searchCallCount, 2);
      final cooldownLog = logger.warnLogs.lastWhere(
        (entry) => entry.message == 'Search sources skipped by cooldown',
      );
      expect(
        cooldownLog.context['sourceIds'],
        contains('browser_source'),
      );
    });

    test('failure history escalates browser source profile summary', () async {
      final runtimeFacade = _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'browser_source',
            name: '浏览器源',
            capabilities: const <String>{'novel', 'browser'},
          ),
        ],
      );
      runtimeFacade.throwOnSearchForSourceId = 'browser_source';
      final logger = _RecordingLogger();
      final service = SearchService(
        sourceRuntimeFacade: runtimeFacade,
        logger: logger,
      );
      service.setSearchDebugLoggingEnabled(true);

      final first = await service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.switchSource,
      );
      expect(first.failedSourceCount, 1);
      runtimeFacade.throwOnSearchForSourceId = null;
      await service.search(
        keyword: '凡人',
        scenario: SearchPlanScenario.switchSource,
      );

      final started = logger.infoLogs.lastWhere(
        (entry) => entry.message == 'Search started',
      );
      expect(
        started.context['profileSummary'],
        containsPair('browserHeavy', 1),
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
    this.budgetControls,
    this.responseDelayBySourceId = const <String, Duration>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, List<runtime_models.Book>> booksBySourceId;
  final _BudgetSearchControls? budgetControls;
  final Map<String, Duration> responseDelayBySourceId;
  String? throwOnSearchForSourceId;
  int searchCallCount = 0;
  int detailCallCount = 0;
  int chaptersCallCount = 0;
  int contentCallCount = 0;
  final List<_SearchCallRecord> searchCalls = <_SearchCallRecord>[];

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
    bool allowInteractiveChallenge = true,
    SessionCancellationHandle? cancellationHandle,
  }) async {
    searchCallCount += 1;
    searchCalls.add(
      _SearchCallRecord(
        sourceId: sourceId,
        keyword: keyword,
        allowInteractiveChallenge: allowInteractiveChallenge,
      ),
    );
    if (budgetControls != null) {
      await budgetControls!.enter(sourceId);
    }
    final delay = responseDelayBySourceId[sourceId];
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    if (throwOnSearchForSourceId == sourceId) {
      throw AppException(
        code: ErrorCode.unknown,
        stage: ErrorStage.search,
        sourceId: sourceId,
        briefMessage: 'browser challenge failed',
      );
    }
    return booksBySourceId[sourceId] ?? const <runtime_models.Book>[];
  }

  @override
  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    detailCallCount += 1;
    return book;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    chaptersCallCount += 1;
    return const <runtime_models.Chapter>[];
  }

  @override
  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    contentCallCount += 1;
    return const runtime_models.Content(title: '', content: '');
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

class _RecordingLogger implements AppLogger {
  final List<_LogEntry> infoLogs = <_LogEntry>[];
  final List<_LogEntry> warnLogs = <_LogEntry>[];

  @override
  void info(String message, {Map<String, Object?> context = const {}}) {
    infoLogs.add(_LogEntry(message: message, context: context));
  }

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {
    warnLogs.add(_LogEntry(message: message, context: context));
  }

  @override
  void error(
    String message, {
    AppException? exception,
    Map<String, Object?> context = const {},
  }) {}
}

class _LogEntry {
  const _LogEntry({required this.message, required this.context});

  final String message;
  final Map<String, Object?> context;
}

class _SearchCallRecord {
  const _SearchCallRecord({
    required this.sourceId,
    required this.keyword,
    required this.allowInteractiveChallenge,
  });

  final String sourceId;
  final String keyword;
  final bool allowInteractiveChallenge;
}

class _BudgetSearchControls {
  _BudgetSearchControls({required this.costsBySourceId});

  final Map<String, int> costsBySourceId;
  final Map<String, Completer<void>> _pending = <String, Completer<void>>{};
  int _startedCount = 0;
  int _activeBudget = 0;
  int maxObservedBudget = 0;

  Future<void> enter(String sourceId) async {
    final completer = Completer<void>();
    _pending[sourceId] = completer;
    _startedCount += 1;
    final cost = costsBySourceId[sourceId] ?? 1;
    _activeBudget += cost;
    if (_activeBudget > maxObservedBudget) {
      maxObservedBudget = _activeBudget;
    }
    await completer.future;
    _activeBudget -= cost;
  }

  Future<void> waitUntilStartedCount(int expected) async {
    while (_startedCount < expected) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  void complete(String sourceId) {
    _pending.remove(sourceId)?.complete();
  }
}
