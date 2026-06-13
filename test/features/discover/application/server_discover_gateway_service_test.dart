import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_key.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/core/cache/cache_scope.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/errors/gateway_failure.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/domain/entities/source_health.dart';
import 'package:shuxiang_reading_next/features/discover/application/server_discover_gateway_service.dart';
import 'package:shuxiang_reading_next/features/discover/domain/discover_source_summary.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_persistence_service.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';

void main() {
  group('ServerDiscoverGatewayService', () {
    test('loads source list without eagerly loading categories', () async {
      final client =
          _FakeDiscoverApiClient()
            ..responses.add(<String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'id': 'source_a',
                  'sourceUrl': 'https://source.example',
                  'sourceName': '测试发现源',
                  'enabled': true,
                  'healthStatus': 'healthy',
                },
              ],
              'page': 1,
              'pageSize': 100,
              'total': 128,
              'hasMore': false,
            });
      final service = ServerDiscoverGatewayService(
        client: client,
        catalogClient: client,
        sourceHealthService: _NoopSourceHealthService(),
      );

      final sources = await service.loadDiscoverSources();

      expect(client.calls, hasLength(1));
      expect(client.calls.single.method, ApiMethod.get);
      expect(client.calls.single.path, '/v1/discovery/book-sources');
      expect(client.calls.single.queryParameters['page'], 1);
      expect(client.calls.single.queryParameters['page_size'], 100);
      expect(sources, hasLength(1));
      final source = sources.single;
      expect(source.id, 'server-gateway:source_a');
      expect(source.name, '测试发现源');
      expect(source.categoryCount, 0);
      expect(source.latencyMs, isNull);
      expect(source.executionContext, isNull);
      expect(source.categories, isEmpty);
    });

    test('loads paged source list and remote keyword search', () async {
      final client =
          _FakeDiscoverApiClient()
            ..responses.addAll(<Object?>[
              <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'id': 'source_a',
                    'sourceUrl': 'https://a.example',
                    'sourceName': '第一页书源',
                    'enabled': true,
                  },
                ],
                'page': 2,
                'pageSize': 100,
                'total': 201,
                'hasMore': true,
              },
              <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'id': 'source_b',
                    'sourceUrl': 'https://b.example',
                    'sourceName': '远程命中书源',
                    'enabled': true,
                  },
                ],
                'page': 1,
                'pageSize': 100,
                'total': 1,
                'hasMore': false,
              },
            ]);
      final service = ServerDiscoverGatewayService(
        client: client,
        catalogClient: client,
        sourceHealthService: _NoopSourceHealthService(),
      );

      final page = await service.loadDiscoverSourcePage(page: 2, pageSize: 100);
      final search = await service.searchDiscoverSources(keyword: '远程命中');

      expect(page.page, 2);
      expect(page.pageSize, 100);
      expect(page.total, 201);
      expect(page.hasMore, isTrue);
      expect(page.items.single.name, '第一页书源');
      expect(client.calls[0].queryParameters['page'], 2);
      expect(client.calls[0].queryParameters['page_size'], 100);
      expect(search.items.single.name, '远程命中书源');
      expect(client.calls[1].queryParameters['keyword'], '远程命中');
      expect(client.calls[1].queryParameters['page'], 1);
      expect(client.calls[1].queryParameters['page_size'], 100);
    });

    test('loads source categories on demand', () async {
      final client =
          _FakeDiscoverApiClient()
            ..responses.add(<String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'title': '热门推荐',
                  'url': '/hot/{{page}}',
                  'type': 'url',
                },
              ],
              'sourceId': 'source_a',
              'sourceUrl': 'https://source.example',
              'sourceName': '测试发现源',
              'sourceReport': <String, Object?>{'stage': 'exploreKinds'},
              'executionContext': 'ctx-kinds',
            });
      final service = ServerDiscoverGatewayService(
        client: client,
        sourceHealthService: _NoopSourceHealthService(),
      );
      const source = DiscoverSourceSummary(
        id: 'server-gateway:source_a',
        sourceUrl: 'https://source.example',
        name: '测试发现源',
        categoryCount: 0,
        status: DiscoverSourceStatus.available,
        latencyMs: null,
        categories: <DiscoverSourceCategory>[],
      );

      final loaded = await service.loadSourceCategories(source: source);

      expect(client.calls.single.method, ApiMethod.post);
      expect(client.calls.single.path, 'v1/explore-kinds');
      final body = client.calls.single.body as Map<String, Object?>;
      expect(body['sourceId'], 'source_a');
      expect(loaded.id, 'server-gateway:source_a');
      expect(loaded.name, '测试发现源');
      expect(loaded.categoryCount, 1);
      expect(loaded.executionContext, 'ctx-kinds');
      expect(loaded.sourceReport['stage'], 'exploreKinds');
      expect(loaded.categories.single.name, '热门推荐');
      expect(loaded.categories.single.ruleFindUrl, '/hot/{{page}}');
    });

    test('loads category books and preserves downstream context', () async {
      final client =
          _FakeDiscoverApiClient()
            ..responses.add(<String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'name': '发现之书',
                  'author': '作者甲',
                  'bookUrl': 'https://book.example/detail/1',
                  'tocUrl': 'https://book.example/toc/1',
                  'coverUrl': 'https://book.example/cover.jpg',
                  'intro': '简介',
                  'kind': '玄幻',
                  'lastChapter': '第一章',
                  'updateTime': '今天',
                  'wordCount': '10万字',
                  'infoHtml': '<html>info</html>',
                  'tocHtml': '<html>toc</html>',
                  'executionContext': 'ctx-book',
                },
              ],
              'page': 2,
              'sourceId': 'source_a',
              'sourceUrl': 'https://source.example',
              'sourceName': '测试发现源',
              'sourceReport': <String, Object?>{'stage': 'explore'},
              'executionContext': 'ctx-page',
            });
      final service = ServerDiscoverGatewayService(
        client: client,
        sourceHealthService: _NoopSourceHealthService(),
      );
      const source = DiscoverSourceSummary(
        id: 'server-gateway:source_a',
        name: '测试发现源',
        categoryCount: 1,
        status: DiscoverSourceStatus.available,
        latencyMs: 12,
        categories: <DiscoverSourceCategory>[],
      );
      const category = DiscoverSourceCategory(
        id: 'hot',
        name: '热门推荐',
        ruleFindUrl: '/hot/{{page}}',
        books: <DiscoverCategoryBook>[],
      );

      final books = await service.loadCategoryBooks(
        source: source,
        category: category,
        page: 2,
      );

      expect(client.calls.single.method, ApiMethod.post);
      expect(client.calls.single.path, 'v1/explore');
      final body = client.calls.single.body as Map<String, Object?>;
      expect(body['sourceId'], 'source_a');
      expect(body['ruleFindUrl'], '/hot/{{page}}');
      expect(body['page'], 2);
      expect(books, hasLength(1));
      final book = books.single;
      expect(book.name, '发现之书');
      expect(book.book?.sourceId, 'server-gateway:source_a');
      expect(book.book?.detailUrl, 'https://book.example/detail/1');
      expect(book.book?.tocUrl, 'https://book.example/toc/1');
      expect(book.book?.infoHtml, '<html>info</html>');
      expect(book.book?.tocHtml, '<html>toc</html>');
      expect(book.book?.executionContext, 'ctx-book');
    });

    test('preserves standard gateway failure when explore fails', () async {
      final failure = GatewayFailure(
        stage: 'explore',
        category: 'timeout',
        code: 'UPSTREAM_TIMEOUT',
        message: '发现请求超时',
        retryable: true,
        hint: '稍后重试或降低并发',
      );
      final client =
          _FakeDiscoverApiClient()
            ..failure = ApiException(
              code: ErrorCode.network,
              briefMessage: failure.message,
              apiCode: 'UPSTREAM_ERROR',
              stage: ErrorStage.source,
              gatewayFailure: failure,
            );
      final service = ServerDiscoverGatewayService(
        client: client,
        sourceHealthService: _NoopSourceHealthService(),
      );
      const source = DiscoverSourceSummary(
        id: 'server-gateway:source_a',
        name: '测试发现源',
        categoryCount: 1,
        status: DiscoverSourceStatus.available,
        latencyMs: 12,
        categories: <DiscoverSourceCategory>[],
      );
      const category = DiscoverSourceCategory(
        id: 'hot',
        name: '热门推荐',
        ruleFindUrl: '/hot/{{page}}',
        books: <DiscoverCategoryBook>[],
      );

      await expectLater(
        service.loadCategoryBooks(source: source, category: category),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ErrorCode.network)
              .having((e) => e.stage, 'stage', ErrorStage.source)
              .having(
                (e) => e.gatewayFailure?.code,
                'failure.code',
                'UPSTREAM_TIMEOUT',
              )
              .having(
                (e) => e.gatewayFailure?.hint,
                'failure.hint',
                '稍后重试或降低并发',
              ),
        ),
      );
    });
  });
}

class _FakeDiscoverApiClient extends ApiClient {
  final List<_ApiCall> calls = <_ApiCall>[];
  final List<Object?> responses = <Object?>[];
  ApiException? failure;

  @override
  Future<T> request<T>({
    required ApiMethod method,
    required String path,
    Map<String, dynamic> queryParameters = const {},
    Object? body,
    Map<String, String> headers = const {},
    Duration? timeout,
    int? maxRetries,
    bool enableRetry = true,
    bool enableCache = false,
    ApiCachePolicy cachePolicy = ApiCachePolicy.realtime,
    Duration? cacheTtl,
    bool attachAccessToken = false,
    bool enableAuthRefresh = true,
    ErrorStage stage = ErrorStage.unknown,
    T Function(Object? data)? decoder,
  }) async {
    calls.add(
      _ApiCall(
        method: method,
        path: path,
        queryParameters: queryParameters,
        body: body,
        stage: stage,
      ),
    );
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    if (decoder == null) {
      return responses.removeAt(0) as T;
    }
    return decoder(responses.removeAt(0));
  }
}

class _ApiCall {
  const _ApiCall({
    required this.method,
    required this.path,
    required this.queryParameters,
    required this.body,
    required this.stage,
  });

  final ApiMethod method;
  final String path;
  final Map<String, dynamic> queryParameters;
  final Object? body;
  final ErrorStage stage;
}

class _NoopSourceHealthService extends SourceHealthService {
  _NoopSourceHealthService()
    : super(persistenceService: _NoopSourceHealthPersistenceService());

  @override
  void markDiscoverCategoriesSuccess({
    required String sourceId,
    bool enabled = true,
  }) {}

  @override
  void markDiscoverCategoriesFailure({
    required String sourceId,
    required String? message,
    bool enabled = true,
    Object? error,
    bool markCooldown = false,
  }) {}

  @override
  void markDiscoverBooksSuccess({
    required String sourceId,
    bool enabled = true,
  }) {}

  @override
  void markDiscoverBooksFailure({
    required String sourceId,
    required String? message,
    bool enabled = true,
    Object? error,
    bool markCooldown = false,
  }) {}
}

class _NoopSourceHealthPersistenceService
    implements SourceHealthPersistenceService {
  @override
  AppCacheScope get scope => AppCacheScope.sourceHealth;

  @override
  String get backendName => 'noop.source_health';

  @override
  Future<AppCacheReadResult> read(
    AppCacheKey key, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheReadResult.miss(key: key, backend: backendName);
  }

  @override
  Future<AppCacheWriteResult> write(
    AppCacheEntry entry, {
    AppCachePolicy? policy,
  }) async {
    return AppCacheWriteResult.skipped(key: entry.key, backend: backendName);
  }

  @override
  Future<AppCacheDeleteResult> delete(AppCacheKey key) async {
    return AppCacheDeleteResult.skipped(
      scope: scope,
      backend: backendName,
      key: key,
    );
  }

  @override
  Future<AppCacheDeleteResult> clearScope({String? owner}) async {
    return AppCacheDeleteResult.deleted(scope: scope, backend: backendName);
  }

  @override
  Future<AppCacheStats> stats({String? owner}) async {
    return AppCacheStats(
      scope: scope,
      backend: backendName,
      entries: 0,
      bytes: 0,
    );
  }

  @override
  Future<AppCachePruneResult> prune(AppCachePolicy policy) async {
    return AppCachePruneResult(scope: scope, backend: backendName);
  }

  @override
  Future<Map<String, SourceHealthSnapshot>> loadSnapshots() async {
    return <String, SourceHealthSnapshot>{};
  }

  @override
  Future<void> saveSnapshots(
    Map<String, SourceHealthSnapshot> snapshots,
  ) async {}
}
