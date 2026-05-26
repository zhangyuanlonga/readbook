import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/features/discover/application/server_discover_gateway_service.dart';
import 'package:shuxiang_reading_next/features/discover/domain/discover_source_summary.dart';
import 'package:shuxiang_reading_next/features/source/application/source_health_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  group('ServerDiscoverGatewayService', () {
    test('loads explore kinds from gateway sources', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.method == 'GET' && request.uri.path == '/api/v1/sources') {
          _writeOk(request, <String, Object?>{
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
            'pageSize': 500,
            'total': 1,
            'hasMore': false,
          });
          return;
        }
        if (request.method == 'POST' &&
            request.uri.path == '/api/v1/explore-kinds') {
          final body = await _readJson(request);
          expect(body['sourceId'], 'source_a');
          _writeOk(request, <String, Object?>{
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
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      final service = ServerDiscoverGatewayService(
        baseUrl: 'http://${server.address.host}:${server.port}/api/',
        sourceHealthService: _NoopSourceHealthService(),
      );

      final sources = await service.loadDiscoverSources();

      expect(sources, hasLength(1));
      final source = sources.single;
      expect(source.id, 'server-gateway:source_a');
      expect(source.name, '测试发现源');
      expect(source.categoryCount, 1);
      expect(source.executionContext, 'ctx-kinds');
      expect(source.sourceReport['stage'], 'exploreKinds');
      expect(source.categories.single.name, '热门推荐');
      expect(source.categories.single.ruleFindUrl, '/hot/{{page}}');

      await server.close(force: true);
    });

    test('loads category books and preserves downstream context', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/api/v1/explore') {
          final body = await _readJson(request);
          expect(body['sourceId'], 'source_a');
          expect(body['ruleFindUrl'], '/hot/{{page}}');
          expect(body['page'], 2);
          _writeOk(request, <String, Object?>{
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
          return;
        }
        request.response.statusCode = 404;
        await request.response.close();
      });

      final service = ServerDiscoverGatewayService(
        baseUrl: 'http://${server.address.host}:${server.port}/api/',
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

      expect(books, hasLength(1));
      final book = books.single;
      expect(book.name, '发现之书');
      expect(book.book?.sourceId, 'server-gateway:source_a');
      expect(book.book?.detailUrl, 'https://book.example/detail/1');
      expect(book.book?.tocUrl, 'https://book.example/toc/1');
      expect(book.book?.infoHtml, '<html>info</html>');
      expect(book.book?.tocHtml, '<html>toc</html>');
      expect(book.book?.executionContext, 'ctx-book');

      await server.close(force: true);
    });

    test('preserves standard gateway failure when explore fails', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 502;
        request.response.write(
          jsonEncode(<String, Object?>{
            'code': 'UPSTREAM_ERROR',
            'message': 'explore failed',
            'data': null,
            'failure': <String, Object?>{
              'stage': 'explore',
              'category': 'timeout',
              'code': 'UPSTREAM_TIMEOUT',
              'message': '发现请求超时',
              'retryable': true,
              'hint': '稍后重试或降低并发',
            },
          }),
        );
        await request.response.close();
      });

      final service = ServerDiscoverGatewayService(
        baseUrl: 'http://${server.address.host}:${server.port}/api/',
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

      await server.close(force: true);
    });
  });
}

Future<Map<String, Object?>> _readJson(HttpRequest request) async {
  final raw = await utf8.decoder.bind(request).join();
  return (jsonDecode(raw) as Map).map(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _writeOk(HttpRequest request, Object? data) {
  request.response.statusCode = 200;
  request.response.headers.contentType = ContentType.json;
  request.response.write(
    jsonEncode(<String, Object?>{
      'code': 'OK',
      'message': 'success',
      'data': data,
    }),
  );
  request.response.close();
}

class _NoopSourceHealthService extends SourceHealthService {
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
