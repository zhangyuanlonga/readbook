import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient', () {
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
        decoder: (data) =>
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
        decoder: (data) =>
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
        decoder: (data) =>
            (data as Map).map((key, value) => MapEntry('$key', value)),
      );
      final second = await client.request<Map<String, dynamic>>(
        method: ApiMethod.get,
        path: path,
        enableCache: true,
        decoder: (data) =>
            (data as Map).map((key, value) => MapEntry('$key', value)),
      );

      expect(first['count'], 1);
      expect(second['count'], 1);
      expect(count, 1);
      await server.close(force: true);
    });
  });
}
