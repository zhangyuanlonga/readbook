import 'dart:async';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/network/request_context.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/discover/application/explore_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExploreService', () {
    test(
      'loadDiscoverSources filters disabled and unsupported sources',
      () async {
        final service = ExploreService(
          sourceRepository: _FakeSourceRepository(<SourceDefinition>[
            _buildExploreSource(id: 's1', enabled: true),
            _buildExploreSource(id: 's2', enabled: false),
            _buildExploreSource(id: 's3', enabled: true, exploreEnabled: false),
            _buildExploreSource(
              id: 's4',
              enabled: true,
              rules: const SourceRuleSet(
                exploreTitleRule: '.title@text',
                exploreDetailUrlRule: '.title@href',
              ),
            ),
          ]),
          searchService: _FakeSearchService(),
        );

        final sources = await service.loadDiscoverSources();
        expect(sources.map((source) => source.id), <String>['s1']);
      },
    );

    test('loadDiscoverSourceSummary reports enabled/discover counts', () async {
      final service = ExploreService(
        sourceRepository: _FakeSourceRepository(<SourceDefinition>[
          _buildExploreSource(id: 's1', enabled: true),
          _buildExploreSource(id: 's2', enabled: true, exploreEnabled: false),
          _buildExploreSource(id: 's3', enabled: false),
        ]),
        searchService: _FakeSearchService(),
      );

      final summary = await service.loadDiscoverSourceSummary();

      expect(summary.enabledSourceCount, 2);
      expect(summary.discoverCapableCount, 1);
      expect(summary.discoverSources.map((item) => item.id), <String>['s1']);
    });

    test('parseCategories supports json array style', () {
      final source = _buildExploreSource(
        id: 'json',
        exploreUrl: '''
[
  {"title":"男频","url":"/rank/boy?page={{page}}","style":{"layout_flexGrow":2,"layout_flexBasisPercent":50}},
  {"title":"女频","url":"/rank/girl?page={{page}}"}
]
''',
      );

      final service = ExploreService(
        sourceRepository: _FakeSourceRepository(<SourceDefinition>[source]),
        searchService: _FakeSearchService(),
      );
      final categories = service.parseCategories(source);

      expect(categories, hasLength(2));
      expect(categories.first.title, '男频');
      expect(categories.first.url, '/rank/boy?page={{page}}');
      expect(categories.first.style.layoutFlexGrow, 2);
      expect(categories.first.style.layoutFlexBasisPercent, 50);
      expect(categories.last.title, '女频');
      expect(categories.last.isActionable, isTrue);
    });

    test('parseCategories supports title::url lines', () {
      final source = _buildExploreSource(
        id: 'line',
        exploreUrl: '''
男频::/rank/boy?page={{page}}
女频::/rank/girl?page={{page}}
分组::
''',
      );

      final service = ExploreService(
        sourceRepository: _FakeSourceRepository(<SourceDefinition>[source]),
        searchService: _FakeSearchService(),
      );
      final categories = service.parseCategories(source);

      expect(categories, hasLength(3));
      expect(categories[0].title, '男频');
      expect(categories[0].url, '/rank/boy?page={{page}}');
      expect(categories[1].title, '女频');
      expect(categories[2].title, '分组');
      expect(categories[2].isActionable, isFalse);
    });

    test('parseCategories keeps invalid template handling resilient', () {
      final source = _buildExploreSource(
        id: 'invalid',
        exploreUrl: '{{id|bad}}',
      );

      final service = ExploreService(
        sourceRepository: _FakeSourceRepository(<SourceDefinition>[source]),
        searchService: _FakeSearchService(),
      );

      expect(
        () => service.parseCategories(source),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            ErrorCode.ruleParse,
          ),
        ),
      );
    });

    test('loadBooks maps explore rules into single-source search', () async {
      SourceDefinition? capturedSource;
      String? capturedKeyword;
      int? capturedPage;
      int? capturedPageSize;

      final source = _buildExploreSource(
        id: 'mapped',
        exploreUrl: '推荐::/discover?page={{page}}',
        rules: const SourceRuleSet(
          exploreInitRule: '/explore/init',
          exploreListRule: '.book-item@html',
          exploreTitleRule: '.book-title@text',
          exploreDetailUrlRule: '.book-title@href',
          exploreAuthorRule: '.book-author@text',
          exploreIntroRule: '.book-intro@text',
          exploreCoverUrlRule: '.book-cover@src',
          exploreLatestChapterRule: '.book-latest@text',
        ),
      );
      final category = const ExploreCategoryItem(
        title: '推荐',
        url: '/discover?page={{page}}',
      );

      final service = ExploreService(
        sourceRepository: _FakeSourceRepository(<SourceDefinition>[source]),
        searchService: _FakeSearchService(
          handler: ({
            required SourceDefinition source,
            required String keyword,
            required int page,
            required int pageSize,
          }) async {
            capturedSource = source;
            capturedKeyword = keyword;
            capturedPage = page;
            capturedPageSize = pageSize;
            return SingleSourceSearchResult(
              sourceId: source.id,
              sourceName: source.name,
              keyword: keyword,
              requestUrl: 'https://example.com/discover?page=$page',
              method: HttpRequestMethod.get,
              statusCode: 200,
              books: <Book>[
                const Book(
                  id: 'book-1',
                  sourceId: 'mapped',
                  title: '测试书籍',
                  detailUrl: 'https://example.com/book/1',
                ),
              ],
            );
          },
        ),
      );

      final pageResult = await service.loadBooks(
        source: source,
        category: category,
        page: 3,
        pageSize: 20,
      );

      expect(capturedKeyword, '推荐');
      expect(capturedPage, 3);
      expect(capturedPageSize, 20);
      expect(capturedSource?.rules.searchRule, '/discover?page={{page}}');
      expect(capturedSource?.rules.searchInitRule, '/explore/init');
      expect(capturedSource?.rules.searchListRule, '.book-item@html');
      expect(capturedSource?.rules.searchTitleRule, '.book-title@text');
      expect(capturedSource?.rules.searchDetailUrlRule, '.book-title@href');
      expect(capturedSource?.rules.searchAuthorRule, '.book-author@text');
      expect(capturedSource?.rules.searchIntroRule, '.book-intro@text');
      expect(capturedSource?.rules.searchCoverUrlRule, '.book-cover@src');
      expect(
        capturedSource?.rules.searchLatestChapterRule,
        '.book-latest@text',
      );

      expect(pageResult.page, 3);
      expect(pageResult.books, hasLength(1));
      expect(pageResult.hasMore, isFalse);
      expect(pageResult.requestUrl, 'https://example.com/discover?page=3');
    });
  });
}

SourceDefinition _buildExploreSource({
  required String id,
  bool enabled = true,
  bool exploreEnabled = true,
  String exploreUrl = '推荐::/discover?page={{page}}',
  SourceRuleSet rules = const SourceRuleSet(
    exploreListRule: '.item@html',
    exploreTitleRule: '.name@text',
    exploreDetailUrlRule: '.name@href',
  ),
}) {
  return SourceDefinition(
    id: id,
    name: '源$id',
    baseUrl: 'https://example.com',
    enabled: enabled,
    exploreEnabled: exploreEnabled,
    exploreUrl: exploreUrl,
    rules: rules,
  );
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
    if (handler == null) {
      return SingleSourceSearchResult(
        sourceId: source.id,
        sourceName: source.name,
        keyword: keyword,
        requestUrl: 'https://example.com',
        method: HttpRequestMethod.get,
        statusCode: 200,
        books: const <Book>[],
      );
    }

    return handler(
      source: source,
      keyword: keyword,
      page: page,
      pageSize: pageSize,
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
  Future<void> upsertAll(List<SourceDefinition> sources) async {}

  @override
  Stream<List<SourceDefinition>> watchAll() =>
      Stream<List<SourceDefinition>>.value(sources);
}
