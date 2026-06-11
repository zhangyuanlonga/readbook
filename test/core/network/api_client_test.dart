import 'dart:convert';
import 'dart:io';

import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/core/errors/error_stage.dart';
import 'package:shuxiang_reading_next/core/network/api_client.dart';
import 'package:shuxiang_reading_next/core/network/auth_token_refresher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
    setUp(() {
      ApiClient.defaultAuthTokenRefresher = null;
      ApiClient.defaultCacheUserIdResolver = null;
    });

    test('unwraps data when code is OK', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {'value': 42},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient();
      final result = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: 'http://${server.address.host}:${server.port}/ok',
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(result['value'], 42);
      await server.close(force: true);
    });

    test('throws ApiException when code is not OK', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'INVALID_ARGUMENT',
            'message': 'bad',
            'data': {},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient();
      await expectLater(
        client.request<Object?>(
          method: ApiMethod.get,
          path: 'http://${server.address.host}:${server.port}/error',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.apiCode, 'apiCode', 'INVALID_ARGUMENT')
              .having((e) => e.code, 'code', ErrorCode.validation),
        ),
      );

      await server.close(force: true);
    });

    test('preserves gateway failure from error envelope', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 502;
        request.response.write(
          jsonEncode({
            'code': 'UPSTREAM_ERROR',
            'message': 'upstream failed',
            'data': null,
            'failure': {
              'stage': 'toc',
              'category': 'timeout',
              'code': 'UPSTREAM_TIMEOUT',
              'message': 'toc timeout',
              'retryable': true,
              'hint': '上游请求超时，可稍后重试',
            },
          }),
        );
        await request.response.close();
      });

      final client = ApiClient();
      await expectLater(
        client.request<Object?>(
          method: ApiMethod.post,
          path: 'http://${server.address.host}:${server.port}/failure',
          enableRetry: false,
          stage: ErrorStage.detail,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ErrorCode.network)
              .having((e) => e.stage, 'stage', ErrorStage.toc)
              .having((e) => e.briefMessage, 'briefMessage', 'toc timeout')
              .having(
                (e) => e.gatewayFailure?.code,
                'gatewayFailure.code',
                'UPSTREAM_TIMEOUT',
              )
              .having(
                (e) => e.gatewayFailure?.retryable,
                'gatewayFailure.retryable',
                isTrue,
              ),
        ),
      );

      await server.close(force: true);
    });

    test('retries GET when status is 5xx', () async {
      var count = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        count += 1;
        if (count == 1) {
          request.response.statusCode = 500;
          request.response.write('error');
        } else {
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': {'ok': true},
            }),
          );
        }
        await request.response.close();
      });

      final client = ApiClient();
      final result = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: 'http://${server.address.host}:${server.port}/retry',
        maxRetries: 1,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(result['ok'], true);
      expect(count, 2);
      await server.close(force: true);
    });

    test('uses cache when enabled', () async {
      var count = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        count += 1;
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {'count': count},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient();
      final path = 'http://${server.address.host}:${server.port}/cache';
      final first = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        enableCache: true,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );
      final second = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        enableCache: true,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(first['count'], 1);
      expect(second['count'], 1);
      expect(count, 1);
      await server.close(force: true);
    });

    test('attaches authorization by default when token is available', () async {
      final refresher = _FakeAuthTokenRefresher();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer expired-token',
        );
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {'ok': true},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient(authTokenRefresher: refresher);
      final result = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: 'http://${server.address.host}:${server.port}/default-token',
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(result['ok'], true);
      await server.close(force: true);
    });

    test('does not attach authorization when request opts out', () async {
      final refresher = _FakeAuthTokenRefresher();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        expect(request.headers.value(HttpHeaders.authorizationHeader), isNull);
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {'ok': true},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient(authTokenRefresher: refresher);
      final result = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: 'http://${server.address.host}:${server.port}/public',
        attachAccessToken: false,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(result['ok'], true);
      await server.close(force: true);
    });

    test('scopes authenticated cache by user id', () async {
      var count = 0;
      var userId = 'user-a';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        count += 1;
        request.response.statusCode = 200;
        request.response.write(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {'count': count},
          }),
        );
        await request.response.close();
      });

      final client = ApiClient(cacheUserIdResolver: () async => userId);
      final path = 'http://${server.address.host}:${server.port}/cache';
      final first = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        attachAccessToken: true,
        cachePolicy: ApiCachePolicy.shortCache,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );
      final second = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        attachAccessToken: true,
        cachePolicy: ApiCachePolicy.shortCache,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );
      userId = 'user-b';
      final third = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        attachAccessToken: true,
        cachePolicy: ApiCachePolicy.shortCache,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(first['count'], 1);
      expect(second['count'], 1);
      expect(third['count'], 2);
      expect(count, 2);
      await server.close(force: true);
    });

    test(
      'does not attach authorization when token resolver returns null',
      () async {
        final refresher = _NullAuthTokenRefresher();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            isNull,
          );
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': <String, Object?>{},
            }),
          );
          await request.response.close();
        });

        final client = ApiClient(authTokenRefresher: refresher);
        await client.request<Map<String, dynamic>>(
          method: ApiMethod.get,
          path: 'http://${server.address.host}:${server.port}/no-token',
          attachAccessToken: true,
          decoder:
              (data) =>
                  (data as Map).map((key, value) => MapEntry('$key', value)),
        );

        await server.close(force: true);
      },
    );

    test(
      'refreshes explicit authorization header when automatic attach is off',
      () async {
        final refresher = _FakeAuthTokenRefresher();
        var count = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          count += 1;
          final authorization = request.headers.value(
            HttpHeaders.authorizationHeader,
          );
          if (count == 1) {
            expect(authorization, 'Bearer manual-expired-token');
            request.response.statusCode = 401;
            request.response.write(
              jsonEncode({
                'code': 'UNAUTHORIZED',
                'message': 'expired',
                'data': {},
              }),
            );
          } else {
            expect(authorization, 'Bearer refreshed-token');
            request.response.statusCode = 200;
            request.response.write(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': {'ok': true},
              }),
            );
          }
          await request.response.close();
        });

        final client = ApiClient(authTokenRefresher: refresher);
        final result = await client.request<Map<String, dynamic>>(
          method: ApiMethod.get,
          path: 'http://${server.address.host}:${server.port}/manual-auth',
          headers: const <String, String>{
            'Authorization': 'Bearer manual-expired-token',
          },
          attachAccessToken: false,
          decoder:
              (data) =>
                  (data as Map).map((key, value) => MapEntry('$key', value)),
        );

        expect(result['ok'], true);
        expect(refresher.refreshCallCount, 1);
        expect(count, 2);
        await server.close(force: true);
      },
    );

    test('uses default token refresher lazily for 401 retry', () async {
      ApiClient.defaultAuthTokenRefresher = null;
      final client = ApiClient();
      final refresher = _FakeAuthTokenRefresher();
      ApiClient.defaultAuthTokenRefresher = refresher;

      var count = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        count += 1;
        final authorization = request.headers.value(
          HttpHeaders.authorizationHeader,
        );
        if (count == 1) {
          expect(authorization, 'Bearer expired-token');
          request.response.statusCode = 401;
          request.response.write(
            jsonEncode({
              'code': 'UNAUTHORIZED',
              'message': 'expired',
              'data': {},
            }),
          );
        } else {
          expect(authorization, 'Bearer refreshed-token');
          request.response.statusCode = 200;
          request.response.write(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': {'ok': true},
            }),
          );
        }
        await request.response.close();
      });

      final result = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: 'http://${server.address.host}:${server.port}/refresh',
        attachAccessToken: true,
        decoder:
            (data) =>
                (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(result['ok'], true);
      expect(refresher.refreshCallCount, 1);
      await server.close(force: true);
      ApiClient.defaultAuthTokenRefresher = null;
    });
  });
}

class _NullAuthTokenRefresher implements AuthTokenRefresher {
  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> refreshToken() async => false;
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
