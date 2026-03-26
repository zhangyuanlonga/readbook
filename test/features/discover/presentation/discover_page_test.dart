import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_appread/core/network/request_context.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/discover/application/discover_preferences_service.dart';
import 'package:flutter_appread/features/discover/application/explore_service.dart';
import 'package:flutter_appread/features/discover/presentation/discover_page.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows discover source summary when no discover-capable source', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 's1',
        name: '普通源',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: false,
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('当前已启用：1，支持发现：0'), findsOneWidget);
    expect(find.text('暂无支持发现的已启用书源'), findsOneWidget);
  });

  testWidgets('loads first discover category and renders books', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'discover_s1',
        name: '发现源A',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(
        handler: ({
          required SourceDefinition source,
          required String keyword,
          required int page,
          required int pageSize,
        }) async {
          return SingleSourceSearchResult(
            sourceId: source.id,
            sourceName: source.name,
            keyword: keyword,
            requestUrl: 'https://example.com/discover?page=$page',
            method: HttpRequestMethod.get,
            statusCode: 200,
            books: const <Book>[
              Book(
                id: 'b1',
                sourceId: 'discover_s1',
                title: '发现测试书籍',
                detailUrl: 'https://example.com/book/1',
              ),
            ],
          );
        },
      ),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('发现源A'), findsOneWidget);
    expect(find.text('发现测试书籍'), findsOneWidget);
  });

  testWidgets('uses denser phone card style at width 480 compared with 390', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const introText = '这是一段用于测试发现页密度策略变化的简介文本内容';
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'discover_density',
        name: '发现密度源',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(
        handler: ({
          required SourceDefinition source,
          required String keyword,
          required int page,
          required int pageSize,
        }) async {
          return SingleSourceSearchResult(
            sourceId: source.id,
            sourceName: source.name,
            keyword: keyword,
            requestUrl: 'https://example.com/discover?page=$page',
            method: HttpRequestMethod.get,
            statusCode: 200,
            books: const <Book>[
              Book(
                id: 'density-book',
                sourceId: 'discover_density',
                title: '密度测试书籍',
                intro: introText,
                detailUrl: 'https://example.com/book/density',
              ),
            ],
          );
        },
      ),
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _TestHarness(
        width: 390,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intro390 = tester.widget<Text>(find.text(introText).first);
    expect(intro390.maxLines, 2);

    await tester.binding.setSurfaceSize(const Size(480, 844));
    await tester.pumpWidget(
      _TestHarness(
        width: 480,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final intro480 = tester.widget<Text>(find.text(introText).first);
    expect(intro480.maxLines, 1);
  });

  testWidgets('shows category style hint text in side panel', (tester) async {
    _registerDiscoverPageTearDown(tester);
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'discover_s2',
        name: '发现源B',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl:
            '[{"title":"推荐","url":"/discover?page={{page}}","style":{"layout_flexBasisPercent":0.25}}]',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('建议宽度: 25%'), findsOneWidget);
  });

  testWidgets('marks broken source and allows quick switch to next source', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'broken_s1',
        name: 'A异常源',
        baseUrl: 'https://broken.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '{{id|bad}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
      SourceDefinition(
        id: 'ok_s2',
        name: 'B可用源',
        baseUrl: 'https://ok.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
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
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'broken_s1',
        name: 'A异常源',
        baseUrl: 'https://broken.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '{{id|bad}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
      SourceDefinition(
        id: 'ok_s2',
        name: 'B可用源',
        baseUrl: 'https://ok.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 700,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
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

    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'default_s1',
        name: 'A默认源',
        baseUrl: 'https://a.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
      SourceDefinition(
        id: 'remember_s2',
        name: 'B记忆源',
        baseUrl: 'https://b.example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          discoverPreferencesService: preferencesService,
          sourceRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('B记忆源'), findsWidgets);
  });

  testWidgets('source picker can filter novel and manga sources', (
    tester,
  ) async {
    _registerDiscoverPageTearDown(tester);
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'novel_source',
        name: '小说源A',
        baseUrl: 'https://novel.example.com',
        enabled: true,
        sourceType: 0,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
      SourceDefinition(
        id: 'manga_source',
        name: '漫画源B',
        baseUrl: 'https://manga.example.com',
        enabled: true,
        sourceType: 2,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 900,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
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
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'discover_s4',
        name: '发现源D',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl:
            '男频分类::\n古代言情::/discover/ancient?page={{page}}\n现代言情::/discover/modern?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
    );

    await tester.pumpWidget(
      _TestHarness(
        width: 320,
        child: DiscoverPage(
          exploreService: service,
          sourceRepository: repository,
        ),
      ),
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
    final repository = _FakeSourceRepository(<SourceDefinition>[
      SourceDefinition(
        id: 'discover_smoke',
        name: '发现烟测源',
        baseUrl: 'https://example.com',
        enabled: true,
        exploreEnabled: true,
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreListRule: '.item@html',
          exploreTitleRule: '.name@text',
          exploreDetailUrlRule: '.name@href',
        ),
      ),
    ]);
    final service = ExploreService(
      sourceRepository: repository,
      searchService: _FakeSearchService(),
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
          child: DiscoverPage(
            exploreService: service,
            sourceRepository: repository,
          ),
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
      child: MaterialApp(home: child),
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

class _FakeSearchService extends SearchService {
  _FakeSearchService({
    Future<SingleSourceSearchResult> Function({
      required SourceDefinition source,
      required String keyword,
      required int page,
      required int pageSize,
    })?
    handler,
  }) : _handler = handler,
       super(
         sourceRepository: _FakeSourceRepository(const <SourceDefinition>[]),
       );

  final Future<SingleSourceSearchResult> Function({
    required SourceDefinition source,
    required String keyword,
    required int page,
    required int pageSize,
  })?
  _handler;

  @override
  Future<SingleSourceSearchResult> searchSingleSource({
    required SourceDefinition source,
    required String keyword,
    int page = 1,
    int pageSize = 20,
    bool validateRules = true,
    bool skipInit = false,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) async {
    final handler = _handler;
    if (handler != null) {
      return handler(
        source: source,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
    }

    return SingleSourceSearchResult(
      sourceId: source.id,
      sourceName: source.name,
      keyword: keyword,
      requestUrl: 'https://example.com/discover?page=$page',
      method: HttpRequestMethod.get,
      statusCode: 200,
      books: const <Book>[],
    );
  }
}

class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository(this.sources);

  final List<SourceDefinition> sources;

  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String sourceId) async {}

  @override
  Future<void> deleteByIds(List<String> sourceIds) async {}

  @override
  Future<List<SourceDefinition>> getAll() async => sources;

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {}

  @override
  Future<void> setGroup({required String sourceId, String? group}) async {}

  @override
  Future<void> upsertAll(List<SourceDefinition> sources) async {}

  @override
  Stream<List<SourceDefinition>> watchAll() =>
      Stream<List<SourceDefinition>>.value(sources);
}
