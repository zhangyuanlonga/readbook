import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChapterContentService', () {
    test('loads and cleans chapter content', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var hitCount = 0;
      server.listen((request) async {
        hitCount++;
        request.response
          ..statusCode = 200
          ..write('''
            <div class="content">
              <p>第一段</p>
              <p>最新网址：www.ad.com</p>
              <p>第二段</p>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's1',
          name: '源A',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(contentRule: '.content@html'),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);

      final first = await service.load(
        sourceId: 's1',
        chapterUrl: '$baseUrl/chapter-1',
      );
      final second = await service.load(
        sourceId: 's1',
        chapterUrl: '$baseUrl/chapter-1',
      );

      expect(first.content, contains('第一段'));
      expect(first.content, contains('第二段'));
      expect(first.content, isNot(contains('最新网址')));
      expect(first.fromCache, isFalse);
      expect(second.fromCache, isTrue);
      expect(hitCount, 1);

      await server.close(force: true);
    });

    test(
      'supports post request spec with json body and json content rule',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedMethod;
        String? observedHeader;
        String? observedBody;

        server.listen((request) async {
          observedMethod = request.method;
          observedHeader = request.headers.value('x-test');
          observedBody = await utf8.decoder.bind(request).join();

          request.response
            ..statusCode = 200
            ..write('{"data":{"text":"这是正文"}}');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_post',
            name: 'POST源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(contentRule: r'<p>{{$.data.text}}</p>'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_post',
          chapterUrl:
              '$baseUrl/content,{"method":"POST","headers":{"X-Test":"yes"},"body":{"chapter":12}}',
        );

        expect(observedMethod, 'POST');
        expect(observedHeader, 'yes');
        expect(observedBody, '{"chapter":12}');
        expect(result.content, contains('这是正文'));

        await server.close(force: true);
      },
    );

    test(
      'supports content init pre-request context and parse fallback',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedToken;

        server.listen((request) async {
          if (request.uri.path == '/content/init') {
            request.response
              ..statusCode = 200
              ..write('{"token":"content-token"}');
          } else {
            observedToken = request.headers.value('x-token');
            request.response
              ..statusCode = 200
              ..write('{"payload":{"body":"第一段\n\n第二段"}}');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_init',
            name: 'Init正文源',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              contentInitRule: '/content/init',
              contentRule: 'html:.missing@html||json:\$.payload.body',
            ),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_init',
          chapterUrl: '''
$baseUrl/content, {
  'headers': {'x-token': '{{token}}'}
}
''',
        );

        expect(observedToken, 'content-token');
        expect(result.content, contains('第一段'));
        expect(result.content, contains('第二段'));

        await server.close(force: true);
      },
    );

    test('throws when content rule is missing', () async {
      final repository = _FakeSourceRepository([
        SourceDefinition(id: 's1', name: '源A', baseUrl: 'https://example.com'),
      ]);

      final service = ChapterContentService(sourceRepository: repository);

      expect(
        () => service.load(
          sourceId: 's1',
          chapterUrl: 'https://example.com/chapter-1',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

class _FakeSourceRepository implements SourceRepository {
  _FakeSourceRepository(this.sources);

  final List<SourceDefinition> sources;

  @override
  Future<void> clear() async {
    sources.clear();
  }

  @override
  Future<void> deleteById(String sourceId) async {
    sources.removeWhere((source) => source.id == sourceId);
  }

  @override
  Future<void> deleteByIds(List<String> sourceIds) async {
    final idSet = sourceIds.toSet();
    sources.removeWhere((source) => idSet.contains(source.id));
  }

  @override
  Future<List<SourceDefinition>> getAll() async {
    return List.unmodifiable(sources);
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    final index = sources.indexWhere((source) => source.id == sourceId);
    if (index == -1) {
      return;
    }
    sources[index] = sources[index].copyWith(enabled: enabled);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> items) async {
    for (final item in items) {
      final index = sources.indexWhere((source) => source.id == item.id);
      if (index >= 0) {
        sources[index] = item;
      } else {
        sources.add(item);
      }
    }
  }

  @override
  Stream<List<SourceDefinition>> watchAll() {
    return Stream.value(List.unmodifiable(sources));
  }
}
