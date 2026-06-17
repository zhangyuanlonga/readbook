import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/network/auth_token_refresher.dart';
import 'package:shuxiang_reading_next/features/search/application/search_hit_cache_service.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';
import 'package:shuxiang_reading_next/features/search/application/server_online_search_service.dart';

void main() {
  group('ServerOnlineSearchService', () {
    setUp(() {
      ApiClient.defaultAuthTokenRefresher = null;
    });

    tearDown(() {
      ApiClient.defaultAuthTokenRefresher = null;
    });

    test('parses standard gateway failure from sourceError SSE', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        final sourceError = <String, Object?>{
          'sourceId': 'source_a',
          'sourceName': '测试源',
          'message': 'legacy message',
          'failureStage': 'search',
          'failureCategory': 'timeout',
          'failure': <String, Object?>{
            'stage': 'search',
            'category': 'timeout',
            'code': 'UPSTREAM_TIMEOUT',
            'message': '搜索超时',
            'retryable': true,
            'hint': '降低并发后重试',
          },
        };
        request.response.write('event: start\n');
        request.response.write('data: {"sourceCount":1}\n\n');
        request.response.write('event: sourceError\n');
        request.response.write('data: ${jsonEncode(sourceError)}\n\n');
        await request.response.close();
      });

      final service = ServerOnlineSearchService(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        searchHitCacheService: SearchHitCacheService(),
      );

      final report = await service.search(
        keyword: '剑来',
        contentMode: SearchContentMode.novel,
        sourceIds: const <String>['source_a'],
      );

      expect(report.failures, hasLength(1));
      final failure = report.failures.single;
      expect(failure.sourceId, 'server-gateway:source_a');
      expect(failure.message, '搜索超时');
      expect(failure.code, ErrorCode.network);
      expect(failure.gatewayCode, 'UPSTREAM_TIMEOUT');
      expect(failure.retryable, isTrue);
      expect(failure.hint, '降低并发后重试');

      await server.close(force: true);
    });

    test('retries stream request with refreshed token on 401', () async {
      final refresher = _FakeAuthTokenRefresher();
      ApiClient.defaultAuthTokenRefresher = refresher;
      var requestCount = 0;
      final authorizations = <String?>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requestCount += 1;
        authorizations.add(
          request.headers.value(HttpHeaders.authorizationHeader),
        );
        if (requestCount == 1) {
          request.response.statusCode = 401;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'code': 'UNAUTHORIZED',
              'message': 'expired',
              'data': <String, Object?>{},
            }),
          );
          await request.response.close();
          return;
        }

        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write('event: start\n');
        request.response.write('data: {"sourceCount":1}\n\n');
        final endPayload = jsonEncode({
          'items': <Object?>[],
          'reports': <String, Object?>{
            'sourceCount': 1,
            'processedSourceCount': 1,
            'successSourceCount': 0,
            'failures': <Object?>[],
          },
          'sourceHits': <String, Object?>{},
        });
        request.response.write('event: end\n');
        request.response.write('data: $endPayload\n\n');
        await request.response.close();
      });

      final service = ServerOnlineSearchService(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        searchHitCacheService: SearchHitCacheService(),
      );

      final report = await service.search(
        keyword: '剑来',
        contentMode: SearchContentMode.novel,
        sourceIds: const <String>['source_a'],
      );

      expect(requestCount, 2);
      expect(authorizations, <String>[
        'Bearer expired-token',
        'Bearer refreshed-token',
      ]);
      expect(refresher.refreshCallCount, 1);
      expect(report.sourceCount, 1);
      await server.close(force: true);
    });

    test(
      'does not start network request when cancellation token is cancelled',
      () async {
        var requestCount = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          requestCount += 1;
          request.response.statusCode = 500;
          await request.response.close();
        });

        final service = ServerOnlineSearchService(
          baseUrl: 'http://${server.address.host}:${server.port}/',
          searchHitCacheService: SearchHitCacheService(),
        );
        final token = SearchCancellationToken()..cancel();

        final report = await service.search(
          keyword: '剑来',
          contentMode: SearchContentMode.novel,
          cancellationToken: token,
        );

        expect(report.books, isEmpty);
        expect(report.sourceCount, 0);
        expect(requestCount, 0);

        await server.close(force: true);
      },
    );

    test('source range lists include current content type', () async {
      final requests = <Uri>[];
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        requests.add(request.uri);
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'ok',
            'data': {
              'items': <Object?>[],
              'page': 1,
              'pageSize': 20,
              'total': 0,
              'hasMore': false,
            },
          }),
        );
        await request.response.close();
      });

      final service = ServerOnlineSearchService(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        searchHitCacheService: SearchHitCacheService(),
      );

      await service.loadSourcePage(
        contentMode: SearchContentMode.manga,
        page: 2,
        pageSize: 20,
        keyword: '热血',
      );
      await service.loadSourceGroupPage(
        contentMode: SearchContentMode.audio,
        page: 1,
        pageSize: 20,
      );

      expect(requests, hasLength(2));
      expect(requests[0].path, contains('/v1/sources'));
      expect(requests[0].queryParameters['contentType'], 'manga');
      expect(requests[0].queryParameters['accessScope'], 'me');
      expect(requests[0].queryParameters['keyword'], '热血');
      expect(requests[1].path, contains('/v1/search/source-groups'));
      expect(requests[1].queryParameters['contentType'], 'audio');

      await server.close(force: true);
    });

    test('search stream sends selected source group names', () async {
      Uri? searchUri;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        searchUri = request.uri;
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write('event: start\n');
        request.response.write('data: {"sourceCount":2}\n\n');
        request.response.write('event: end\n');
        request.response.write(
          'data: ${jsonEncode({
            'items': <Object?>[],
            'reports': <String, Object?>{'sourceCount': 2, 'processedSourceCount': 2, 'successSourceCount': 0, 'failures': <Object?>[]},
            'sourceHits': <String, Object?>{},
          })}\n\n',
        );
        await request.response.close();
      });

      final service = ServerOnlineSearchService(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        searchHitCacheService: SearchHitCacheService(),
      );

      await service.search(
        keyword: '剑来',
        contentMode: SearchContentMode.novel,
        groupNames: const <String>['免费公开书源'],
      );

      expect(searchUri, isNotNull);
      expect(searchUri!.path, contains('/v1/books/search/stream'));
      expect(searchUri!.queryParameters['sourceScopeMode'], 'include');
      expect(
        jsonDecode(searchUri!.queryParameters['groupNames']!) as List<dynamic>,
        <String>['免费公开书源'],
      );

      await server.close(force: true);
    });

    test('search stream sends multiple selected source ids', () async {
      Uri? searchUri;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        searchUri = request.uri;
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        request.response.write('event: start\n');
        request.response.write('data: {"sourceCount":2}\n\n');
        request.response.write('event: end\n');
        request.response.write(
          'data: ${jsonEncode({
            'items': <Object?>[],
            'reports': <String, Object?>{'sourceCount': 2, 'processedSourceCount': 2, 'successSourceCount': 0, 'failures': <Object?>[]},
            'sourceHits': <String, Object?>{},
          })}\n\n',
        );
        await request.response.close();
      });

      final service = ServerOnlineSearchService(
        baseUrl: 'http://${server.address.host}:${server.port}/',
        searchHitCacheService: SearchHitCacheService(),
      );

      await service.search(
        keyword: '剑来',
        contentMode: SearchContentMode.novel,
        sourceIds: const <String>['source_a', 'source_b'],
      );

      expect(searchUri, isNotNull);
      expect(searchUri!.queryParameters['sourceScopeMode'], 'include');
      expect(
        jsonDecode(searchUri!.queryParameters['sourceIds']!) as List<dynamic>,
        <String>['source_a', 'source_b'],
      );

      await server.close(force: true);
    });
  });
}

class _FakeAuthTokenRefresher implements AuthTokenRefresher {
  String _token = 'expired-token';
  int refreshCallCount = 0;

  @override
  Future<String?> getAccessToken() async => _token;

  @override
  Future<bool> refreshToken() async {
    refreshCallCount += 1;
    _token = 'refreshed-token';
    return true;
  }
}
