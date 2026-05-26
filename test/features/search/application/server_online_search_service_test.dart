import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/core/errors/error_codes.dart';
import 'package:shuxiang_reading_next/features/search/application/search_models.dart';
import 'package:shuxiang_reading_next/features/search/application/server_online_search_service.dart';

void main() {
  group('ServerOnlineSearchService', () {
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
  });
}
