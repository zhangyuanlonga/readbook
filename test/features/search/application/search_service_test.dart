import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/network/http_client.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchService', () {
    test('filters sources by content mode (novel/manga)', () async {
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 'novel_1',
          name: '小说源',
          baseUrl: 'https://novel.example.com',
          sourceType: 0,
          enabled: false,
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.result@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
        ),
        SourceDefinition(
          id: 'manga_1',
          name: '漫画源',
          baseUrl: 'https://comic.example.com',
          sourceType: 2,
          enabled: false,
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.result@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);

      expect(
        () =>
            service.search(keyword: '凡人', contentMode: SearchContentMode.manga),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('漫画书源'),
          ),
        ),
      );

      expect(
        () =>
            service.search(keyword: '凡人', contentMode: SearchContentMode.novel),
        throwsA(
          isA<AppException>().having(
            (error) => error.briefMessage,
            'briefMessage',
            contains('小说书源'),
          ),
        ),
      );
    });

    test('supports searching with specified source ids', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/s1') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="item"><a class="title" href="/book/1">A书</a></div>
            ''');
        } else if (request.uri.path == '/s2') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="item"><a class="title" href="/book/2">B书</a></div>
            ''');
        } else {
          request.response
            ..statusCode = 200
            ..write('<div class="empty">no data</div>');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's1',
          name: '源1',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule: '/s1?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
        ),
        SourceDefinition(
          id: 's2',
          name: '源2',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule: '/s2?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(
        keyword: '凡人',
        sourceIds: const ['s2'],
      );

      expect(report.sourceCount, 1);
      expect(report.books, hasLength(1));
      expect(report.books.first.title, 'B书');

      await server.close(force: true);
    });

    test('searches enabled sources and keeps per-source failures', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/ok') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="result-item">
                <a class="title" href="/book/1">凡人修仙传</a>
                <span class="author">忘语</span>
              </div>
            ''');
        } else {
          request.response
            ..statusCode = 200
            ..write('<div class="empty">no data</div>');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_ok',
          name: '成功源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule: '/ok?key={{key}}',
            searchListRule: '.result-item@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
            searchAuthorRule: '.author@text',
          ),
        ),
        SourceDefinition(
          id: 's_fail',
          name: '失败源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule: '/fail?key={{key}}',
            searchListRule: '.result-item@html',
            searchTitleRule: '.title@text',
            searchDetailUrlRule: '.title@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人');

      expect(report.books, hasLength(1));
      expect(report.books.first.title, '凡人修仙传');
      expect(report.books.first.detailUrl, '$baseUrl/book/1');
      expect(report.successSourceCount, 1);
      expect(report.failedSourceCount, 1);
      expect(report.failures.first.sourceId, 's_fail');

      await server.close(force: true);
    });

    test('supports searchUrl postfix options with POST body', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedMethod;
      String? observedBody;

      server.listen((request) async {
        observedMethod = request.method;
        observedBody = await utf8.decoder.bind(request).join();

        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/11">凡人修仙传</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_post',
          name: 'POST源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule:
                '$baseUrl/search,{"method":"POST","body":"keyword={{key}}&page={{page}}&size=10"}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedMethod, 'POST');
      expect(
        observedBody,
        contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
      );
      expect(observedBody, contains('page=1'));

      await server.close(force: true);
    });

    test('supports POST json body and header passthrough', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedMethod;
      String? observedBody;
      String? observedContentType;
      String? observedToken;

      server.listen((request) async {
        observedMethod = request.method;
        observedBody = await utf8.decoder.bind(request).join();
        observedContentType = request.headers.value(
          HttpHeaders.contentTypeHeader,
        );
        observedToken = request.headers.value('x-token');

        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/21">凡人修仙传</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_json_post',
          name: 'JSON POST源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '''
$baseUrl/search, {
  'method': 'POST',
  'body': {
    'keyword': '{{key}}',
    'page': '{{page}}',
    'next': '{{page+1}}'
  },
  'headers': {'x-token': 'demo-token'}
}
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedMethod, 'POST');
      expect(observedToken, 'demo-token');
      expect(observedContentType, contains('application/json'));
      expect(observedBody, contains('"keyword":"凡人修仙传"'));
      expect(observedBody, contains('"page":"1"'));
      expect(observedBody, contains('"next":"2"'));

      await server.close(force: true);
    });

    test('supports POST raw body and keeps keyword unencoded', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedMethod;
      String? observedBody;
      String? observedContentType;
      String? observedMode;

      server.listen((request) async {
        observedMethod = request.method;
        observedBody = await utf8.decoder.bind(request).join();
        observedContentType = request.headers.value(
          HttpHeaders.contentTypeHeader,
        );
        observedMode = request.headers.value('x-mode');

        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/22">凡人修仙传</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_raw_post',
          name: 'RAW POST源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '''
$baseUrl/search, {
  'method': 'POST',
  'contentType': 'text/plain',
  'body': 'keyword={{key}}|next={{page+1}}',
  'headers': {'x-mode': 'raw'}
}
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedMethod, 'POST');
      expect(observedMode, 'raw');
      expect(observedContentType, contains('text/plain'));
      expect(observedBody, 'keyword=凡人修仙传|next=2');

      await server.close(force: true);
    });

    test('supports init pre-request context for search stage', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedToken;

      server.listen((request) async {
        if (request.uri.path == '/init') {
          request.response
            ..statusCode = 200
            ..write('{"token":"abc-token"}');
          await request.response.close();
          return;
        }

        observedToken = request.headers.value('x-token');
        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/31">凡人修仙传</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_init',
          name: 'INIT源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchInitRule: '/init',
            searchRule: '''
$baseUrl/search, {
  'method': 'GET',
  'headers': {'x-token': '{{token}}'}
}
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedToken, 'abc-token');

      await server.close(force: true);
    });

    test(
      'supports composite searchUrl with spaces and trailing option object',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedMethod;
        String? observedBody;
        String? observedHeader;
        String? observedQuery;

        server.listen((request) async {
          observedMethod = request.method;
          observedBody = await utf8.decoder.bind(request).join();
          observedHeader = request.headers.value('x-search');
          observedQuery = request.uri.query;

          request.response
            ..statusCode = 200
            ..write('''
            <div class="item">
              <a class="name" href="/book/12">凡人修仙传</a>
            </div>
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_composite',
            name: '复合源',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              searchRule: '''
$baseUrl/search?channel=a,b, {
  'method': 'POST',
  'body': 'keyword={{key}}&next={{page+1}}&optional={{missingVar}}',
  'headers': '{"x-search":"enabled"}'
}
''',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
        ]);

        final service = SearchService(sourceRepository: repository);
        final report = await service.search(keyword: '凡人修仙传');

        expect(report.books, hasLength(1));
        expect(observedMethod, 'POST');
        expect(observedHeader, 'enabled');
        expect(observedQuery, contains('channel=a,b'));
        expect(
          observedBody,
          contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
        );
        expect(observedBody, contains('next=2'));
        expect(observedBody, contains('optional='));

        await server.close(force: true);
      },
    );

    test(
      'supports searchUrl with legacy script prelude before request URL',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedMethod;
        String? observedBody;

        server.listen((request) async {
          observedMethod = request.method;
          observedBody = await utf8.decoder.bind(request).join();

          request.response
            ..statusCode = 200
            ..write('''
            <div class="item">
              <a class="name" href="/book/legacy">凡人修仙传</a>
            </div>
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_legacy_prelude',
            name: 'legacy prelude 源',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              searchRule: '''
{{url=source.getKey();
cookie.removeCookie(url)}}
$baseUrl/search, {
  "method": "POST",
  "body": "keyword={{key}}&page={{page}}"
}
''',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
        ]);

        final service = SearchService(sourceRepository: repository);
        final report = await service.search(keyword: '凡人修仙传');

        expect(report.books, hasLength(1));
        expect(observedMethod, 'POST');
        expect(
          observedBody,
          contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
        );
        expect(observedBody, contains('page=1'));

        await server.close(force: true);
      },
    );

    test('extracts url template from java wrapper expression', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedQuery;

      server.listen((request) async {
        observedQuery = request.uri.query;
        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/wrapped">凡人修仙传</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_java_wrap',
          name: 'java 包装源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '{{java.put("su",`$baseUrl/search?keyword={{key}}`)}}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(
        observedQuery,
        contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
      );

      await server.close(force: true);
    });

    test('supports @js searchUrl with JSON.stringify options', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedMethod;
      String? observedBody;

      server.listen((request) async {
        observedMethod = request.method;
        observedBody = await utf8.decoder.bind(request).join();

        request.response
          ..statusCode = 200
          ..write('''
            <div class="item"><a class="name" href="/book/js1">凡人修仙传</a></div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_js_stringify',
          name: 'JS stringify 源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '''
@js:
var so="/search,"+JSON.stringify({
  "body": "keyword="+key+"&page="+page,
  "method": "POST"
});
so
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedMethod, 'POST');
      expect(
        observedBody,
        contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
      );
      expect(observedBody, contains('page=1'));

      await server.close(force: true);
    });

    test('supports @js url + post variable pattern', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedMethod;
      String? observedBody;

      server.listen((request) async {
        observedMethod = request.method;
        observedBody = await utf8.decoder.bind(request).join();

        request.response
          ..statusCode = 200
          ..write('''
            <div class="item"><a class="name" href="/book/js2">凡人修仙传</a></div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_js_var_post',
          name: 'JS var post 源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '''
@js:
var url=source.getKey();
var so="/search,";
var body=`keyword=\${key}&page=\${page}`;
var post={
  "body": String(body),
  "method": "POST"
};
url+so+JSON.stringify(post)
''',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(observedMethod, 'POST');
      expect(
        observedBody,
        contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
      );
      expect(observedBody, contains('page=1'));

      await server.close(force: true);
    });

    test(
      'extracts url template from java wrapper expression with js-style placeholders',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedQuery;

        server.listen((request) async {
          observedQuery = request.uri.query;
          request.response
            ..statusCode = 200
            ..write('''
              <div class="item">
                <a class="name" href="/book/wrapped2">凡人修仙传</a>
              </div>
            ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_java_wrap_js_placeholder',
            name: 'java 包装源 js 占位符',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              searchRule:
                  '{{java.put("su",`$baseUrl/search?keyword=\${key}&start=\${page-1}`)}}',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
        ]);

        final service = SearchService(sourceRepository: repository);
        final report = await service.search(keyword: '凡人修仙传');

        expect(report.books, hasLength(1));
        expect(
          observedQuery,
          contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
        );
        expect(observedQuery, contains('start=0'));

        await server.close(force: true);
      },
    );

    test('supports json search rules with inline js pipeline', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('''
            {
              "booklist": [
                {
                  "title": "凡人修仙传",
                  "author": "忘语",
                  "intro": "修仙长路",
                  "bid": "465030"
                }
              ]
            }
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_json',
          name: 'JSON源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '/search?wd={{key}}&start={{page-1}}',
            searchListRule: r'$.booklist[*]',
            searchTitleRule: r'$.title',
            searchDetailUrlRule:
                '\$.bid\n<js>1100000000+parseInt(result)</js>\nhttps://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid={{result}}',
            searchAuthorRule: r'$.author',
            searchIntroRule: r'$.intro',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人修仙传');

      expect(report.books, hasLength(1));
      expect(report.books.first.title, '凡人修仙传');
      expect(
        report.books.first.detailUrl,
        'https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1100465030',
      );
      expect(report.books.first.author, '忘语');

      await server.close(force: true);
    });

    test(
      'supports legado json shorthand search rules from api payload',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedMethod;
        String? observedBody;

        server.listen((request) async {
          observedMethod = request.method;
          observedBody = await utf8.decoder.bind(request).join();

          request.response
            ..statusCode = 200
            ..write('''
            {
              "data": {
                "books": [
                  {
                    "articlename": "凡人修仙传",
                    "author": "忘语",
                    "tid": 465030,
                    "siteid": 117,
                    "lastchapter": "第一章"
                  }
                ]
              }
            }
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_legado_json',
            name: 'Legado JSON源',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              searchRule:
                  '$baseUrl/api-search,{"method":"POST","body":"keyword={{key}}&page={{page}}&size=10"}',
              searchListRule: 'data.books',
              searchTitleRule: 'articlename',
              searchDetailUrlRule: '/api-info-{{\$.tid}}-{{\$.siteid}}',
              searchAuthorRule: 'author##<\\/?em>',
              searchLatestChapterRule: 'lastchapter',
            ),
          ),
        ]);

        final service = SearchService(sourceRepository: repository);
        final report = await service.search(keyword: '凡人修仙传');

        expect(report.books, hasLength(1));
        expect(report.books.first.title, '凡人修仙传');
        expect(report.books.first.author, '忘语');
        expect(report.books.first.detailUrl, '$baseUrl/api-info-465030-117');
        expect(observedMethod, 'POST');
        expect(
          observedBody,
          contains('keyword=%E5%87%A1%E4%BA%BA%E4%BF%AE%E4%BB%99%E4%BC%A0'),
        );

        await server.close(force: true);
      },
    );

    test('supports legado lz-base64 search response payload', () async {
      final encodedPayload =
          File(
            'test/fixtures/aaawz_search_payload_lz_base64.txt',
          ).readAsStringSync().trim();

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(encodedPayload);
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_lz_payload',
          name: '压缩响应源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule:
                '$baseUrl/api-search,{"method":"POST","body":"keyword={{key}}&page={{page}}&size=10"}',
            searchListRule: 'data.books',
            searchTitleRule: 'articlename',
            searchDetailUrlRule: '/api-info-{{\$.tid}}-{{\$.siteid}}',
            searchAuthorRule: 'author',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '凡人');

      expect(report.books, isNotEmpty);
      expect(report.failures, isEmpty);
      expect(report.books.first.title, isNotEmpty);
      expect(report.books.first.detailUrl, contains('/api-info-'));

      await server.close(force: true);
    });

    test('normalizes non-prefixed html rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('''
            <div class="book">
              <a class="name" href="/detail/1">测试书</a>
              <img class="cover" src="/cover.png" />
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_a',
          name: '源A',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.book',
            searchTitleRule: '.name',
            searchDetailUrlRule: '.name@href',
            searchCoverUrlRule: '.cover@src',
          ),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);
      final report = await service.search(keyword: '测试');

      expect(report.books, hasLength(1));
      expect(report.books.first.title, '测试书');
      expect(report.books.first.coverUrl, '$baseUrl/cover.png');

      await server.close(force: true);
    });

    test('runs single-source connectivity test and updates health', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="name" href="/book/3">连通性测试书</a>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final source = SourceDefinition(
        id: 's_single',
        name: '单源',
        baseUrl: baseUrl,
        rules: const SourceRuleSet(
          searchRule: '/search?key={{key}}',
          searchListRule: '.item@html',
          searchTitleRule: '.name@text',
          searchDetailUrlRule: '.name@href',
        ),
      );

      final repository = _FakeSourceRepository([source]);
      final service = SearchService(sourceRepository: repository);

      final report = await service.testSingleSource(
        source: source,
        keyword: '连通性',
      );

      expect(report.isSuccess, isTrue);
      expect(report.method.name, 'get');
      expect(report.statusCode, 200);
      expect(report.matchedBookCount, 1);
      expect(report.probeOnly, isFalse);

      final latest = (await repository.getAll()).first;
      expect(latest.lastCheckStatus, SourceHealthStatus.healthy);
      expect(latest.lastCheckedAt, isNotNull);
      expect(latest.lastCheckMessage, contains('命中 1 条'));

      await server.close(force: true);
    });

    test(
      'quick probe can skip init request for faster liveness check',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/search') {
            request.response
              ..statusCode = 200
              ..write('{"ok":true}');
          } else {
            request.response.statusCode = 404;
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final source = SourceDefinition(
          id: 's_probe_skip_init',
          name: '探活跳过初始化',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchInitRule: '/init',
            searchRule: '/search?key={{key}}',
          ),
        );

        final repository = _FakeSourceRepository([source]);
        final service = SearchService(sourceRepository: repository);

        final report = await service.testSingleSource(
          source: source,
          keyword: '探活',
          validateRules: false,
          skipInit: true,
        );

        expect(report.isSuccess, isTrue);
        expect(report.probeOnly, isTrue);
        expect(report.statusCode, 200);

        await server.close(force: true);
      },
    );

    test('supports quick connectivity probe without parse rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('{"ok":true}');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final source = SourceDefinition(
        id: 's_probe_only',
        name: '探活源',
        baseUrl: baseUrl,
        rules: const SourceRuleSet(searchRule: '/ping?key={{key}}'),
      );

      final repository = _FakeSourceRepository([source]);
      final service = SearchService(sourceRepository: repository);

      final report = await service.testSingleSource(
        source: source,
        keyword: '探活',
        validateRules: false,
      );

      expect(report.isSuccess, isTrue);
      expect(report.statusCode, 200);
      expect(report.probeOnly, isTrue);
      expect(report.matchedBookCount, 0);

      final latest = (await repository.getAll()).first;
      expect(latest.lastCheckStatus, SourceHealthStatus.healthy);
      expect(latest.lastCheckedAt, isNotNull);
      expect(latest.lastCheckMessage, contains('网络可达'));

      await server.close(force: true);
    });

    test(
      'marks source as unavailable when connectivity test hits network error',
      () async {
        final source = SourceDefinition(
          id: 's_unreachable',
          name: '不可达源',
          baseUrl: 'http://127.0.0.1:1',
          rules: const SourceRuleSet(
            searchRule: '/search?key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        );

        final repository = _FakeSourceRepository([source]);
        final service = SearchService(
          sourceRepository: repository,
          httpClient: AppHttpClient(
            defaultConnectTimeout: const Duration(milliseconds: 200),
            defaultReceiveTimeout: const Duration(milliseconds: 300),
          ),
        );

        final report = await service.testSingleSource(
          source: source,
          keyword: '网络失败',
        );

        expect(report.isSuccess, isFalse);
        expect(report.error, isA<NetworkException>());

        final latest = (await repository.getAll()).first;
        expect(latest.lastCheckStatus, SourceHealthStatus.unavailable);
        expect(latest.lastCheckedAt, isNotNull);
      },
    );

    test('limits concurrent source requests to configured range', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var inFlight = 0;
      var maxInFlight = 0;

      server.listen((request) async {
        inFlight += 1;
        if (inFlight > maxInFlight) {
          maxInFlight = inFlight;
        }

        await Future<void>.delayed(const Duration(milliseconds: 180));

        request.response
          ..statusCode = 200
          ..write('''
        <div class="item">
          <a class="name" href="/book/${request.uri.queryParameters['sid']}">并发测试</a>
        </div>
      ''');
        await request.response.close();

        inFlight -= 1;
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final sources = List<SourceDefinition>.generate(
        6,
        (index) => SourceDefinition(
          id: 's_concurrent_$index',
          name: '并发源$index',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            searchRule: '/search?sid=$index&key={{key}}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
          ),
        ),
      );

      final service = SearchService(
        sourceRepository: _FakeSourceRepository(sources),
        maxConcurrentSources: 4,
      );

      final report = await service.search(keyword: '并发');

      expect(report.books.length, greaterThanOrEqualTo(1));
      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1));

      await server.close(force: true);
    });

    test(
      'cancels previous search and returns partial progress safely',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          await Future<void>.delayed(const Duration(milliseconds: 260));
          request.response
            ..statusCode = 200
            ..write('''
        <div class="item">
          <a class="name" href="/book/${request.uri.queryParameters['sid']}">取消测试</a>
        </div>
      ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final sources = List<SourceDefinition>.generate(
          5,
          (index) => SourceDefinition(
            id: 's_cancel_$index',
            name: '取消源$index',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              searchRule: '/search?sid=$index&key={{key}}',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
        );

        final token = SearchCancellationToken();
        final service = SearchService(
          sourceRepository: _FakeSourceRepository(sources),
          maxConcurrentSources: 4,
        );

        final future = service.search(keyword: '取消', cancellationToken: token);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        token.cancel();
        final report = await future;

        expect(report.sourceCount, 5);
        expect(report.processedSourceCount, lessThan(report.sourceCount));

        await server.close(force: true);
      },
    );

    test(
      'emits progressive results while searching multiple sources',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final sid = request.uri.queryParameters['sid'] ?? '0';
          final delay = sid == '0' ? 60 : 220;
          await Future<void>.delayed(Duration(milliseconds: delay));

          request.response
            ..statusCode = 200
            ..write('''
        <div class="item">
          <a class="name" href="/book/$sid">渐进结果$sid</a>
        </div>
      ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_progress_0',
            name: '渐进源0',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              searchRule: '/search?sid=0&key={{key}}',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
          SourceDefinition(
            id: 's_progress_1',
            name: '渐进源1',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              searchRule: '/search?sid=1&key={{key}}',
              searchListRule: '.item@html',
              searchTitleRule: '.name@text',
              searchDetailUrlRule: '.name@href',
            ),
          ),
        ]);

        final callbacks = <SearchExecutionReport>[];
        final service = SearchService(sourceRepository: repository);

        final report = await service.search(
          keyword: '渐进',
          onProgress: callbacks.add,
        );

        expect(callbacks.length, greaterThanOrEqualTo(2));
        expect(
          callbacks.first.processedSourceCount,
          lessThan(report.sourceCount),
        );
        expect(callbacks.last.processedSourceCount, report.sourceCount);
        expect(report.books.length, 2);

        await server.close(force: true);
      },
    );

    test('throws when there is no enabled source', () async {
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_a',
          name: '源A',
          baseUrl: 'https://example.com',
          enabled: false,
          rules: const SourceRuleSet(searchRule: '/search?key={{key}}'),
        ),
      ]);

      final service = SearchService(sourceRepository: repository);

      expect(
        () => service.search(keyword: 'abc'),
        throwsA(isA<UnknownSourceException>()),
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
