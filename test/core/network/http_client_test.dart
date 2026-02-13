import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/network/http_client.dart';
import 'package:flutter_appread/core/network/request_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppHttpClient', () {
    test('sends query and headers', () async {
      final observed = <String, String>{};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        observed['method'] = request.method;
        observed['path'] = request.uri.path;
        observed['key'] = request.uri.queryParameters['key'] ?? '';
        observed['header'] = request.headers.value('x-source-id') ?? '';
        request.response
          ..statusCode = 200
          ..write('ok');
        await request.response.close();
      });

      final client = AppHttpClient();
      final response = await client.get(
        RequestContext(
          url: 'http://${server.address.host}:${server.port}/search',
          queryParameters: const {'key': 'abc'},
          headers: const {'x-source-id': 's-1'},
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(observed['method'], 'GET');
      expect(observed['path'], '/search');
      expect(observed['key'], 'abc');
      expect(observed['header'], 's-1');

      await server.close(force: true);
    });

    test('supports post with raw body', () async {
      final observed = <String, String>{};
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        observed['method'] = request.method;
        observed['contentType'] = request.headers.value('content-type') ?? '';
        observed['body'] = await utf8.decoder.bind(request).join();
        request.response
          ..statusCode = 200
          ..write('ok');
        await request.response.close();
      });

      final client = AppHttpClient();
      final response = await client.get(
        RequestContext(
          url: 'http://${server.address.host}:${server.port}/search',
          method: HttpRequestMethod.post,
          body: 'keyword=abc&page=1',
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      expect(response.statusCode, 200);
      expect(observed['method'], 'POST');
      expect(observed['body'], 'keyword=abc&page=1');
      expect(
        observed['contentType'],
        contains('application/x-www-form-urlencoded'),
      );

      await server.close(force: true);
    });

    test('retries when status code is retryable', () async {
      var count = 0;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        count++;
        if (count == 1) {
          request.response
            ..statusCode = 500
            ..write('error');
        } else {
          request.response
            ..statusCode = 200
            ..write('ok');
        }
        await request.response.close();
      });

      final client = AppHttpClient();
      final response = await client.get(
        RequestContext(
          url: 'http://${server.address.host}:${server.port}/retry',
          maxRetries: 1,
        ),
      );

      expect(response.statusCode, 200);
      expect(response.body, 'ok');
      expect(count, 2);

      await server.close(force: true);
    });

    test('throws network exception on timeout', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        request.response
          ..statusCode = 200
          ..write('late');
        await request.response.close();
      });

      final client = AppHttpClient();

      expect(
        () => client.get(
          RequestContext(
            url: 'http://${server.address.host}:${server.port}/timeout',
            receiveTimeout: const Duration(milliseconds: 50),
          ),
        ),
        throwsA(isA<NetworkException>()),
      );

      await server.close(force: true);
    });
  });
}
