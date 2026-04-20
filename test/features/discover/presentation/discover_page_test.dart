import 'package:flutter/material.dart';
import 'package:shuxiang_reading_next/core/errors/app_exception.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/domain/entities/script_source.dart';
import 'package:shuxiang_reading_next/domain/repositories/script_source_repository.dart';
import 'package:shuxiang_reading_next/features/discover/application/discover_preferences_service.dart';
import 'package:shuxiang_reading_next/features/discover/application/explore_service.dart';
import 'package:shuxiang_reading_next/features/discover/presentation/discover_page.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_runtime_facade.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_contract.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_manifest.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_registry.dart';
import 'package:shuxiang_reading_next/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SourceHealthService.instance.clear();
    await SourceHealthService.instance.persistNow();
  });

  testWidgets('shows discover source summary when no discover-capable source', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 's1',
            name: '普通源',
            supportsDiscover: false,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 900, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('当前已启用：1，支持发现：0'), findsOneWidget);
    expect(find.text('暂无支持发现的已启用书源'), findsOneWidget);
  });

  testWidgets('loads first discover category and renders books', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'discover_s1', name: '发现源A'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'discover_s1': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
        booksBySourceId: <String, List<runtime_models.Book>>{
          'discover_s1': const <runtime_models.Book>[
            runtime_models.Book(
              sourceId: 'discover_s1',
              title: '发现测试书籍',
              author: '作者A',
              detailUrl: 'https://example.com/book/1',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 900, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现源A'), findsOneWidget);
    expect(find.text('发现测试书籍'), findsWidgets);
  });

  testWidgets('uses denser phone card style at width 480 compared with 390', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const introText = '这是一段用于测试发现页密度策略变化的简介文本内容';
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'discover_density', name: '发现密度源'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'discover_density': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
        booksBySourceId: <String, List<runtime_models.Book>>{
          'discover_density': const <runtime_models.Book>[
            runtime_models.Book(
              sourceId: 'discover_density',
              title: '密度测试书籍',
              author: '作者A',
              intro: introText,
              detailUrl: 'https://example.com/book/density',
            ),
          ],
        },
      ),
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _TestHarness(width: 390, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    final intro390 = tester.widget<Text>(find.text(introText).first);
    expect(intro390.maxLines, 2);

    await tester.binding.setSurfaceSize(const Size(480, 844));
    await tester.pumpWidget(
      _TestHarness(width: 480, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    final intro480 = tester.widget<Text>(find.text(introText).first);
    expect(intro480.maxLines, 1);
  });

  testWidgets('shows category style hint text in side panel', (tester) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'discover_s2', name: '发现源B'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'discover_s2': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
              style: runtime_models.DiscoverCategoryStyle(
                layoutFlexBasisPercent: 25,
              ),
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 900, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议宽度: 25%'), findsOneWidget);
  });

  testWidgets('marks broken source and allows quick switch to next source', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'broken_s1', name: 'A异常源'),
          _buildRegisteredSource(id: 'ok_s2', name: 'B可用源'),
        ],
        failingCategorySourceIds: const <String>{'broken_s1'},
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'ok_s2': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 900, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('A异常源'), findsWidgets);
    expect(find.text('规则异常'), findsWidgets);

    await tester.tap(find.byKey(const Key('discover_next_source')));
    await tester.pumpAndSettle();

    expect(find.text('B可用源'), findsWidgets);
  });

  testWidgets('source switch buttons remain usable in narrow rail layout', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'broken_s1', name: 'A异常源'),
          _buildRegisteredSource(id: 'ok_s2', name: 'B可用源'),
        ],
        failingCategorySourceIds: const <String>{'broken_s1'},
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'ok_s2': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 700, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover_next_source')));
    await tester.pumpAndSettle();

    expect(find.text('B可用源'), findsWidgets);
  });

  testWidgets('restores remembered source after page rebuild', (tester) async {
    _registerDiscoverPageTearDown(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{
      'discover.selectedSourceId': 'remember_s2',
    });
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = DiscoverPreferencesService(preferences: prefs);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'default_s1', name: 'A默认源'),
          _buildRegisteredSource(id: 'remember_s2', name: 'B记忆源'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'default_s1': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
          'remember_s2': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          discoverPreferencesService: preferencesService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('B记忆源'), findsWidgets);
  });

  testWidgets('shows cached discover sources and categories before refresh completes', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = DiscoverPreferencesService(preferences: prefs);
    await preferencesService.saveSelectedSourceId('cached_s2');
    await preferencesService.saveSourceSnapshot(const <DiscoverSource>[
      DiscoverSource(
        id: 'cached_s1',
        name: '缓存源A',
        baseUrl: 'https://a.example.com',
      ),
      DiscoverSource(
        id: 'cached_s2',
        name: '缓存源B',
        baseUrl: 'https://b.example.com',
      ),
    ]);
    await preferencesService.saveCategorySnapshot(
      'cached_s2',
      const <ExploreCategoryItem>[
        ExploreCategoryItem(title: '推荐', url: '/discover?page={{page}}'),
      ],
    );

    final delayedService = _DelayedExploreService();

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: delayedService,
          discoverPreferencesService: preferencesService,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.text('缓存源B'), findsWidgets);
    expect(find.text('推荐'), findsWidgets);
  });

  testWidgets('source picker can filter novel and manga sources', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(
            id: 'novel_source',
            name: '小说源A',
            capabilities: const <String>{'novel', 'discover'},
          ),
          _buildRegisteredSource(
            id: 'manga_source',
            name: '漫画源B',
            capabilities: const <String>{'manga', 'discover'},
          ),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'novel_source': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
          'manga_source': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 900, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('discover_source_switch_button')));
    await tester.pumpAndSettle();

    expect(find.text('小说源A').evaluate().length, greaterThanOrEqualTo(2));
    expect(find.text('漫画源B'), findsWidgets);

    await tester.tap(find.byKey(const Key('discover_source_filter_manga')));
    await tester.pumpAndSettle();

    expect(find.text('小说源A').evaluate().length, 1);
    expect(find.text('漫画源B'), findsWidgets);
  });

  testWidgets('category preview hides non-actionable group titles', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'discover_s4', name: '发现源D'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'discover_s4': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(title: '男频分类'),
            runtime_models.DiscoverCategory(
              title: '古代言情',
              url: '/discover/ancient?page={{page}}',
            ),
            runtime_models.DiscoverCategory(
              title: '现代言情',
              url: '/discover/modern?page={{page}}',
            ),
          ],
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(width: 320, child: DiscoverPage(exploreService: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(ChoiceChip), matching: find.text('男频分类')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('男频分类')),
      findsNothing,
    );
  });

  testWidgets('renders without layout exceptions on phone and tablet sizes', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final service = ExploreService(
      sourceRuntimeFacade: _FakeRuntimeFacade(
        sources: <RegisteredSource>[
          _buildRegisteredSource(id: 'discover_smoke', name: '发现烟测源'),
        ],
        categoriesBySourceId: <String, List<runtime_models.DiscoverCategory>>{
          'discover_smoke': const <runtime_models.DiscoverCategory>[
            runtime_models.DiscoverCategory(
              title: '推荐',
              url: '/discover?page={{page}}',
            ),
          ],
        },
        booksBySourceId: <String, List<runtime_models.Book>>{
          'discover_smoke': const <runtime_models.Book>[
            runtime_models.Book(
              sourceId: 'discover_smoke',
              title: '烟测书籍',
              author: '作者A',
              detailUrl: 'https://example.com/book/smoke',
            ),
          ],
        },
      ),
    );

    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final item in const <_ViewportCase>[
      _ViewportCase(name: 'phone_360', size: Size(360, 800), dpr: 3.0),
      _ViewportCase(name: 'phone_412', size: Size(412, 915), dpr: 3.5),
      _ViewportCase(name: 'phone_480', size: Size(480, 1066), dpr: 3.0),
      _ViewportCase(name: 'phone_landscape', size: Size(640, 360), dpr: 3.0),
      _ViewportCase(name: 'tablet_840', size: Size(840, 1180), dpr: 2.0),
      _ViewportCase(name: 'large_1366', size: Size(1366, 1024), dpr: 2.0),
    ]) {
      await tester.binding.setSurfaceSize(item.size);
      await tester.pumpWidget(
        _TestHarness(
          width: item.size.width,
          height: item.size.height,
          dpr: item.dpr,
          child: DiscoverPage(exploreService: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason:
            'unexpected exception at ${item.name} (${item.size.width}x${item.size.height}@${item.dpr})',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

void _registerDiscoverPageTearDown(WidgetTester tester) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
    await SourceHealthService.instance.persistNow();
  });
}

class _TestHarness extends StatelessWidget {
  const _TestHarness({
    required this.width,
    required this.child,
    this.height = 844,
    this.dpr = 3,
  });

  final double width;
  final double height;
  final double dpr;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, height), devicePixelRatio: dpr),
      child: ProviderScope(child: MaterialApp(home: child)),
    );
  }
}

class _ViewportCase {
  const _ViewportCase({
    required this.name,
    required this.size,
    required this.dpr,
  });

  final String name;
  final Size size;
  final double dpr;
}

RegisteredSource _buildRegisteredSource({
  required String id,
  required String name,
  bool enabled = true,
  bool supportsDiscover = true,
  Set<String>? capabilities,
  Future<List<runtime_models.DiscoverCategory>> Function()? discoverCategories,
  Future<List<runtime_models.Book>> Function(
    runtime_models.DiscoverCategory category,
    int page,
    int pageSize,
  )?
  discoverBooks,
}) {
  final normalizedCapabilities =
      capabilities ?? <String>{'novel', if (supportsDiscover) 'discover'};
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
        capabilities: normalizedCapabilities,
      ),
      discoverCategories:
          !supportsDiscover
              ? null
              : (_) async =>
                  await (discoverCategories?.call() ??
                      const <runtime_models.DiscoverCategory>[]),
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
    this.categoriesBySourceId =
        const <String, List<runtime_models.DiscoverCategory>>{},
    this.booksBySourceId = const <String, List<runtime_models.Book>>{},
    this.failingCategorySourceIds = const <String>{},
  }) : super(scriptSourceRepository: _FakeScriptSourceRepository());

  final List<RegisteredSource> sources;
  final Map<String, List<runtime_models.DiscoverCategory>> categoriesBySourceId;
  final Map<String, List<runtime_models.Book>> booksBySourceId;
  final Set<String> failingCategorySourceIds;

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
  Future<ScriptSourceReloadReport> reloadScriptSources({
    bool enabledOnly = true,
  }) async {
    return ScriptSourceReloadReport(
      loaded: registeredScriptSources(enabledOnly: enabledOnly),
      failures: const <ScriptSourceReloadFailure>[],
    );
  }

  @override
  Future<List<runtime_models.DiscoverCategory>> discoverCategories({
    required String sourceId,
  }) async {
    if (failingCategorySourceIds.contains(sourceId)) {
      throw AppException(
        code: ErrorCode.ruleParse,
        stage: ErrorStage.source,
        sourceId: sourceId,
        briefMessage: '规则异常',
      );
    }
    return categoriesBySourceId[sourceId] ??
        const <runtime_models.DiscoverCategory>[];
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

class _DelayedExploreService extends ExploreService {
  _DelayedExploreService() : super(sourceRuntimeFacade: _FakeRuntimeFacade(sources: const <RegisteredSource>[]));

  @override
  Future<DiscoverSourceSummary> loadDiscoverSourceSummary() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    return const DiscoverSourceSummary(
      enabledSourceCount: 0,
      discoverCapableCount: 0,
      discoverSources: <DiscoverSource>[],
    );
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
