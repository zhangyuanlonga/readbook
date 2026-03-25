import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/core/webview/webview_executor.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/source/application/script_source_runtime_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookDetailService', () {
    test('loads detail and toc then applies reversed order', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="title">凡人修仙传</h1>
              <span class="author">忘语</span>
              <p class="intro">一个凡人的修仙故事。</p>
              <img class="cover" src="/cover.jpg" />
              <a class="toc" href="/book/1/toc">目录</a>
            ''');
        } else if (request.uri.path == '/book/1/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="chapter"><a class="link" href="/c1">第1章</a></div>
              <div class="chapter"><a class="link" href="/c2">第2章</a></div>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's1',
          name: '测试源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: '.title',
            detailAuthorRule: '.author',
            detailIntroRule: '.intro',
            detailCoverUrlRule: '.cover@src',
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
            tocReversed: true,
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's1',
        bookId: 'book_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.detail.title, '凡人修仙传');
      expect(result.detail.author, '忘语');
      expect(result.detail.coverUrl, '$baseUrl/cover.jpg');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第2章');
      expect(result.chapters.first.chapterUrl, '$baseUrl/c2');
      expect(result.tocFromCache, isFalse);

      await server.close(force: true);
    });

    test('supports "-" prefixed toc list rule reverse order', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="title">凡人修仙传</h1>
              <a class="toc" href="/book/1/toc">目录</a>
            ''');
        } else if (request.uri.path == '/book/1/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="chapter"><a class="link" href="/c1">第1章</a></div>
              <div class="chapter"><a class="link" href="/c2">第2章</a></div>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_reverse_toc',
          name: '目录倒序源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: '.title@text',
            detailTocUrlRule: '.toc@href',
            tocListRule: '-.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_reverse_toc',
        bookId: 'book_reverse_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第2章');
      expect(result.chapters.last.title, '第1章');

      await server.close(force: true);
    });

    test('loads paged toc via nextTocUrl rule', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/paged') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/toc/p1">目录</a>');
        } else if (request.uri.path == '/toc/p1') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="chapter"><a class="link" href="/c1">第1章</a></div>
              <a class="next" href="/toc/p2">下一页</a>
            ''');
        } else if (request.uri.path == '/toc/p2') {
          request.response
            ..statusCode = 200
            ..write(
              '<div class="chapter"><a class="link" href="/c2">第2章</a></div>',
            );
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_toc_next',
          name: '目录翻页源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
            tocNextUrlRule: '.next@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_toc_next',
        bookId: 'book_toc_next',
        detailUrl: '$baseUrl/book/paged',
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第1章');
      expect(result.chapters.last.title, '第2章');
      expect(result.chapters.last.chapterUrl, '$baseUrl/c2');

      await server.close(force: true);
    });

    test(
      'loads detail and chapters from script runtime facade fallback',
      () async {
        final facade = SourceRuntimeFacade(
          scriptSourceRepository: _NoopScriptSourceRepository(),
          scriptRuntimeService: _FakeScriptSourceRuntimeService(
            registeredSources: <RegisteredSource>[
              RegisteredSource(
                runtime: const SourceRuntimeInfo(
                  id: 'script_detail_1',
                  name: '脚本详情源',
                  group: '默认分组',
                  revision: 'script-1',
                ),
                definition: RuntimeSourceDefinition(
                  manifest: const SourceManifest(
                    name: '脚本详情源',
                    group: '默认分组',
                    author: 'tester',
                    description: 'desc',
                  ),
                  search: _noopRuntimeSearch,
                  detail: _noopRuntimeDetail,
                  chapters: _noopRuntimeChapters,
                  content: _noopRuntimeContent,
                ),
              ),
            ],
            detailBySourceId: <String, runtime_models.Book>{
              'script_detail_1': const runtime_models.Book(
                id: 'script_book_1',
                title: '脚本详情书籍',
                author: '脚本作者',
                cover: 'https://script.example.com/cover.jpg',
                intro: '脚本简介',
                detailUrl: 'https://script.example.com/book/1',
                sourceId: 'script_detail_1',
                extra: <String, dynamic>{
                  'catalogUrl': 'https://script.example.com/book/1/toc',
                },
              ),
            },
            chaptersBySourceId: <String, List<runtime_models.Chapter>>{
              'script_detail_1': const <runtime_models.Chapter>[
                runtime_models.Chapter(
                  id: 'script_ch_1',
                  title: '第一章',
                  url: 'https://script.example.com/ch/1',
                  index: 0,
                  sourceId: 'script_detail_1',
                ),
                runtime_models.Chapter(
                  id: 'script_ch_2',
                  title: '第二章',
                  url: 'https://script.example.com/ch/2',
                  index: 1,
                  sourceId: 'script_detail_1',
                ),
              ],
            },
          ),
        );

        final service = BookDetailService(
          sourceRepository: _FakeSourceRepository(const <SourceDefinition>[]),
          sourceRuntimeFacade: facade,
        );

        final result = await service.load(
          sourceId: 'script_detail_1',
          bookId: 'script_book_1',
          detailUrl: 'https://script.example.com/book/1',
        );

        expect(result.detail.title, '脚本详情书籍');
        expect(result.detail.author, '脚本作者');
        expect(result.detail.coverUrl, 'https://script.example.com/cover.jpg');
        expect(result.detail.tocUrl, 'https://script.example.com/book/1/toc');
        expect(result.sourceName, '脚本详情源');
        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '第一章');
        expect(
          result.chapters.first.chapterUrl,
          'https://script.example.com/ch/1',
        );
      },
    );

    test('passes source/book js context into detail rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(
            '<div class="chapter"><a class="link" href="/c1">第一章</a></div>',
          );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_ctx_detail',
          name: 'JS详情源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: "@js:book.id + '|' + source.bookSourceName",
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_ctx_detail',
        bookId: 'book_ctx_1',
        detailUrl: '$baseUrl/book/ctx',
      );

      expect(result.detail.title, 'book_ctx_1|JS详情源');
      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.chapterUrl, '$baseUrl/c1');

      await server.close(force: true);
    });

    test('supports gbk decoding for detail and toc request specs', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);

      server.listen((request) async {
        if (request.uri.path == '/book/gbk') {
          final detailHtml = '<h1 class="title">剑来</h1>';
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'html')
            ..add(gbk!.encode(detailHtml));
        } else if (request.uri.path == '/book/gbk/toc') {
          final tocHtml =
              '<div class="chapter"><a class="link" href="/c1">第一章</a></div>';
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'html')
            ..add(gbk!.encode(tocHtml));
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_gbk_detail',
          name: 'GBK详情源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            detailTitleRule: '.title@text',
            detailTocUrlRule: '$baseUrl/book/gbk/toc,{"charset":"GBK"}',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_gbk_detail',
        bookId: 'book_gbk_detail',
        detailUrl: '$baseUrl/book/gbk,{"charset":"GBK"}',
      );

      expect(result.detail.title, '剑来');
      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.title, '第一章');
      expect(result.chapters.first.chapterUrl, '$baseUrl/c1');

      await server.close(force: true);
    });

    test('loads json detail with init rule and template toc url', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/detail') {
          request.response
            ..statusCode = 200
            ..write('''
              {
                "data": {
                  "bookInfo": {
                    "resourceID": "1100465030",
                    "resourceName": "凡人修仙传"
                  }
                }
              }
            ''');
        } else if (request.uri.path == '/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              {
                "rows": [
                  {"serialID": 1, "serialName": "第一章"},
                  {"serialID": 2, "serialName": "第二章"}
                ]
              }
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_json',
          name: 'JSON测试源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            detailRule: r'$.data.bookInfo',
            detailTitleRule: r'$.resourceName',
            detailTocUrlRule: '$baseUrl/toc?bookId={{\$.resourceID}}',
            tocListRule: r'$.rows',
            tocTitleRule: r'$.serialName',
            tocChapterUrlRule:
                '$baseUrl/content,{"method":"POST","body":{"bookId":"{{baseUrl.match(/bookId=(\\d+)/)[1]}}","chapter":{{\$.serialID}}}}',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's_json',
        bookId: 'book_json_1',
        detailUrl: '$baseUrl/detail?bookId=1100465030',
      );

      expect(result.detail.title, '凡人修仙传');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第一章');
      expect(result.chapters.first.chapterUrl, contains('$baseUrl/content'));
      expect(
        result.chapters.first.chapterUrl,
        contains('"bookId":"1100465030"'),
      );
      expect(result.chapters.first.chapterUrl, contains('"chapter":1'));

      await server.close(force: true);
    });

    test('supports init pre-request context for toc request headers', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedToken;

      server.listen((request) async {
        if (request.uri.path == '/detail/init') {
          request.response
            ..statusCode = 200
            ..write('{"token":"detail-token"}');
        } else if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/book/1/toc">目录</a>');
        } else if (request.uri.path == '/book/1/toc') {
          observedToken = request.headers.value('x-token');
          request.response
            ..statusCode = 200
            ..write(
              '<div class="chapter"><a class="link" href="/c1">第1章</a></div>',
            );
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_init_toc',
          name: 'Init目录源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            detailInitRule: '/detail/init',
            detailTocUrlRule: '''
$baseUrl/book/1/toc, {
  'headers': {'x-token': '{{token}}'}
}
''',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's_init_toc',
        bookId: 'book_init_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.chapters, hasLength(1));
      expect(observedToken, 'detail-token');

      await server.close(force: true);
    });

    test(
      'returns chapter list from cache when force refresh is false',
      () async {
        var tocHitCount = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/book/1') {
            request.response
              ..statusCode = 200
              ..write('<a class="toc" href="/book/1/toc">目录</a>');
          } else if (request.uri.path == '/book/1/toc') {
            tocHitCount++;
            request.response
              ..statusCode = 200
              ..write(
                '<div class="chapter"><a class="link" href="/c1">第1章</a></div>',
              );
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's1',
            name: '测试源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTocUrlRule: '.toc@href',
              tocListRule: '.chapter@html',
              tocTitleRule: '.link@text',
              tocChapterUrlRule: '.link@href',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);

        final first = await service.load(
          sourceId: 's1',
          bookId: 'book_1',
          detailUrl: '$baseUrl/book/1',
        );
        final second = await service.load(
          sourceId: 's1',
          bookId: 'book_1',
          detailUrl: '$baseUrl/book/1',
        );

        expect(first.tocFromCache, isFalse);
        expect(second.tocFromCache, isTrue);
        expect(tocHitCount, 1);

        await server.close(force: true);
      },
    );

    test('skips invalid chapter urls during toc parsing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/book/1/toc">目录</a>');
        } else if (request.uri.path == '/book/1/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="chapter"><a class="link" href="javascript:void(0)">无效1</a></div>
              <div class="chapter"><a class="link" href="#jump">无效2</a></div>
              <div class="chapter"><a class="link" href="mailto:test@example.com">无效3</a></div>
              <div class="chapter"><a class="link" href="/valid-1">有效1</a></div>
              <div class="chapter"><a class="link" href="//cdn.example.com/valid-2">有效2</a></div>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_url_clean',
          name: 'URL清洗源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_url_clean',
        bookId: 'book_clean_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '有效1');
      expect(result.chapters.first.chapterUrl, '$baseUrl/valid-1');
      expect(result.chapters.last.title, '有效2');
      expect(result.chapters.last.chapterUrl, 'http://cdn.example.com/valid-2');

      await server.close(force: true);
    });

    test('supports legacy toc chapterUrl onclick regex and js suffix', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/js') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/book/js/toc">目录</a>');
        } else if (request.uri.path == '/book/js/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="chapter"><a class="link" onclick="openChapter('/c1')">第1章</a></div>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_toc_js_suffix',
          name: '目录脚本后缀源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule:
                r'.link@onclick##.*\((.*)\).*##$1@js:result+",{"webView":true}"',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_toc_js_suffix',
        bookId: 'book_toc_js',
        detailUrl: '$baseUrl/book/js',
      );

      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.title, '第1章');
      expect(result.chapters.first.chapterUrl, '$baseUrl/c1,{"webView":true}');

      await server.close(force: true);
    });

    test(
      'supports script-only toc list and chapterUrl fallback rules',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/book/script') {
            request.response
              ..statusCode = 200
              ..write('<a class="toc" href="/book/script/toc">目录</a>');
          } else if (request.uri.path == '/book/script/toc') {
            request.response
              ..statusCode = 200
              ..write('ignored');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_toc_script_only',
            name: '目录脚本字段源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTocUrlRule: '.toc@href',
              tocListRule: '@js:[{"title":"第1章","cid":"c1"}]',
              tocTitleRule: 'title',
              tocChapterUrlRule: '@js:"/chapter/{{\$.cid}}"',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_toc_script_only',
          bookId: 'book_toc_script',
          detailUrl: '$baseUrl/book/script',
        );

        expect(result.chapters, hasLength(1));
        expect(result.chapters.first.title, '第1章');
        expect(result.chapters.first.chapterUrl, '$baseUrl/chapter/c1');

        await server.close(force: true);
      },
    );

    test('returns detail with empty toc when toc rule is missing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('<h1 class="title">凡人修仙传</h1>');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's1',
          name: '测试源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(detailTitleRule: '.title'),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's1',
        bookId: 'book_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.detail.id, 'book_1');
      expect(result.chapters, isEmpty);
      expect(result.tocError, isA<AppException>());
      expect(result.tocError!.stage, ErrorStage.toc);
      expect(result.tocError!.code, ErrorCode.validation);

      await server.close(force: true);
    });

    test(
      'supports legado compressed detail and toc payload with json shorthand rules',
      () async {
        final detailPayload =
            File(
              'test/fixtures/aaawz_detail_payload_lz_base64.txt',
            ).readAsStringSync().trim();
        final tocPayload =
            File(
              'test/fixtures/aaawz_toc_payload_lz_base64.txt',
            ).readAsStringSync().trim();

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/api-info-13148-35') {
            request.response
              ..statusCode = 200
              ..write(detailPayload);
          } else if (request.uri.path == '/api-chapterlist-13148-35') {
            request.response
              ..statusCode = 200
              ..write(tocPayload);
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_legacy_aaawz',
            name: '3A小说',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTitleRule: 'articlename',
              detailAuthorRule: 'author',
              detailCoverUrlRule: 'imgurl',
              detailTocUrlRule: r'/api-chapterlist-{{$.tid}}-{{$.siteid}}',
              tocListRule: '*',
              tocTitleRule: 'title',
              tocChapterUrlRule: r"{{baseUrl.replace('list-','-')}}-{{$.cid}}",
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_legacy_aaawz',
          bookId: 'book_legacy_1',
          detailUrl: '$baseUrl/api-info-13148-35',
        );

        expect(result.detail.title, '暗黑校园');
        expect(result.detail.author, '曼卿');
        expect(
          result.detail.coverUrl,
          'https://easyreadfs.nosdn.127.net/WPIuCpQ_VasdybVQQW-i6g==/8796093025462758042',
        );
        expect(result.detail.tocUrl, '$baseUrl/api-chapterlist-13148-35');
        expect(result.chapters, hasLength(2));
        expect(result.chapters.first.title, '第1章');
        expect(
          result.chapters.first.chapterUrl,
          '$baseUrl/api-chapter-13148-35-10196648',
        );
        expect(result.chapters.last.title, '第2章');
        expect(
          result.chapters.last.chapterUrl,
          '$baseUrl/api-chapter-13148-35-10196649',
        );
        expect(result.tocError, isNull);

        await server.close(force: true);
      },
    );

    test(
      'supports @put/@get variable chain across detail and toc rules',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/book/putget') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="title">变量链路测试</h1>
              <a class="toc" href="/book/putget/toc">目录</a>
            ''');
          } else if (request.uri.path == '/book/putget/toc') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="chapter"><a class="link" data-cid="1">第一章</a></div>
            ''');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_put_get_detail',
            name: '@put/@get 详情目录源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTitleRule: '.title@text@put:{toc:".toc@href"}',
              detailTocUrlRule: '@get:{toc}',
              tocListRule: '.chapter@html',
              tocTitleRule: '.link@text@put:{cid:".link@data-cid"}',
              tocChapterUrlRule: '/chapter/@get:{cid}',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_put_get_detail',
          bookId: 'book_put_get_detail',
          detailUrl: '$baseUrl/book/putget',
        );

        expect(result.detail.title, '变量链路测试');
        expect(result.detail.tocUrl, '$baseUrl/book/putget/toc');
        expect(result.chapters, hasLength(1));
        expect(result.chapters.first.title, '第一章');
        expect(result.chapters.first.chapterUrl, '$baseUrl/chapter/1');

        await server.close(force: true);
      },
    );

    test('persists java.put/java.get as book-scoped variables', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path.startsWith('/book/')) {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/toc">目录</a>');
        } else if (request.uri.path == '/toc') {
          request.response
            ..statusCode = 200
            ..write(
              '<div class="chapter"><a class="link" href="/c1">第一章</a></div>',
            );
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_book_scope_detail',
          name: 'book-scope-detail',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule:
                '@js:var saved = java.get("detail_key"); saved ? saved : (java.put("detail_key", book.detailUrl), "init")',
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final first = await service.load(
        sourceId: 's_book_scope_detail',
        bookId: 'book-a',
        detailUrl: '$baseUrl/book/1',
      );
      expect(first.detail.title, 'init');

      final second = await service.load(
        sourceId: 's_book_scope_detail',
        bookId: 'book-a',
        detailUrl: '$baseUrl/book/2',
      );
      expect(second.detail.title, '$baseUrl/book/1');

      final third = await service.load(
        sourceId: 's_book_scope_detail',
        bookId: 'book-b',
        detailUrl: '$baseUrl/book/3',
      );
      expect(third.detail.title, 'init');

      final persisted =
          repository.sources
                  .firstWhere((item) => item.id == 's_book_scope_detail')
                  .originalSource?[r'_appread_js_book_variables']
              as Map?;
      expect(
        persisted?['book-a'],
        isA<Map>().having(
          (value) => value['detail_key'],
          'detail_key',
          '$baseUrl/book/1',
        ),
      );
      expect(
        persisted?['book-b'],
        isA<Map>().having(
          (value) => value['detail_key'],
          'detail_key',
          '$baseUrl/book/3',
        ),
      );

      await server.close(force: true);
    });

    test('supports xpath-style detail and toc rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/xpath') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="title">诛仙</h1>
              <a class="toc" href="/book/xpath/toc">目录</a>
            ''');
        } else if (request.uri.path == '/book/xpath/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <ul>
                <li><a href="/c1">第一章</a></li>
                <li><a href="/c2">第二章</a></li>
              </ul>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_xpath_detail',
          name: 'XPath详情源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: '//h1[@class="title"]/text()',
            detailTocUrlRule: '//a[@class="toc"]/@href',
            tocListRule: '//li',
            tocTitleRule: './/a/text()',
            tocChapterUrlRule: './/a/@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_xpath_detail',
        bookId: 'book_xpath_detail',
        detailUrl: '$baseUrl/book/xpath',
      );

      expect(result.detail.title, '诛仙');
      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.chapterUrl, '$baseUrl/c1');

      await server.close(force: true);
    });

    test('supports mixed detail init request + @put parse variables', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? observedToken;

      server.listen((request) async {
        if (request.uri.path == '/init') {
          request.response
            ..statusCode = 200
            ..write('<meta name="token" content="detail-init-token" />');
        } else if (request.uri.path == '/book/mixed') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/book/mixed/toc">目录</a>');
        } else if (request.uri.path == '/book/mixed/toc') {
          observedToken = request.headers.value('x-token');
          request.response
            ..statusCode = 200
            ..write(
              '<div class="chapter"><a class="link" href="/c1">第一章</a></div>',
            );
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_init_mixed_detail',
          name: 'Init混合详情源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            detailInitRule: '/init\n@put:{tk:"meta[name=token]@content"}',
            detailTocUrlRule:
                '$baseUrl/book/mixed/toc,{"headers":{"x-token":"{{tk}}"}}',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_init_mixed_detail',
        bookId: 'book_init_mixed_detail',
        detailUrl: '$baseUrl/book/mixed',
      );

      expect(result.chapters, hasLength(1));
      expect(observedToken, 'detail-init-token');

      await server.close(force: true);
    });

    test('returns detail when toc request fails', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/1') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="title">凡人修仙传</h1>
              <a class="toc" href="/book/1/toc">目录</a>
            ''');
        } else if (request.uri.path == '/book/1/toc') {
          request.response
            ..statusCode = 500
            ..write('server error');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_toc_fail',
          name: '目录失败源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: '.title',
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's_toc_fail',
        bookId: 'book_1',
        detailUrl: '$baseUrl/book/1',
      );

      expect(result.detail.title, '凡人修仙传');
      expect(result.chapters, isEmpty);
      expect(result.tocError, isA<AppException>());
      expect(result.tocError!.stage, ErrorStage.toc);

      await server.close(force: true);
    });
    test(
      'ignores html-fragment toc url to avoid malformed toc requests',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requestUris = <String>[];

        server.listen((request) async {
          requestUris.add(request.uri.toString());

          if (request.uri.path == '/book/html-fragment') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="title">片段目录链接</h1>
              <meta property="og:novel:read_url" content="<!doctype html><html><body>bad</body></html>" />
            ''');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_html_fragment_toc',
            name: 'HTML片段目录源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTitleRule: '.title@text',
              detailTocUrlRule: '[property="og:novel:read_url"]@content',
              tocListRule: '.chapter@html',
              tocTitleRule: '.link@text',
              tocChapterUrlRule: '.link@href',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_html_fragment_toc',
          bookId: 'book_html_fragment_toc',
          detailUrl: '$baseUrl/book/html-fragment',
        );

        expect(result.detail.title, '片段目录链接');
        expect(result.chapters, isEmpty);
        expect(
          requestUris.any((uri) => uri.toLowerCase().contains('%3c')),
          isFalse,
        );

        await server.close(force: true);
      },
    );

    test('supports legacy toc title/url rules with bare extractors', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/book/legacy') {
          request.response
            ..statusCode = 200
            ..write('<a class="toc" href="/book/legacy/toc">目录</a>');
        } else if (request.uri.path == '/book/legacy/toc') {
          request.response
            ..statusCode = 200
            ..write('''
              <ul class="catalog-list">
                <li><a href="/legacy/c1">第一章</a></li>
                <li><a href="/legacy/c2">第二章</a></li>
              </ul>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_toc_bare',
          name: '目录裸提取测试源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTocUrlRule: '.toc@href',
            tocListRule: '.catalog-list li a@html',
            tocTitleRule: 'text',
            tocChapterUrlRule: 'href',
          ),
        ),
      ]);

      final service = BookDetailService(sourceRepository: repository);

      final result = await service.load(
        sourceId: 's_toc_bare',
        bookId: 'book_toc_bare',
        detailUrl: '$baseUrl/book/legacy',
      );

      expect(result.chapters, hasLength(2));
      expect(result.chapters.first.title, '第一章');
      expect(result.chapters.first.chapterUrl, '$baseUrl/legacy/c1');

      await server.close(force: true);
    });

    test(
      'keeps fallback title/author when canReName evaluates false',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/book/can-rename-false') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="title">详情标题</h1>
              <span class="author">详情作者</span>
              <a class="toc" href="/book/can-rename-false/toc">目录</a>
            ''');
          } else if (request.uri.path == '/book/can-rename-false/toc') {
            request.response
              ..statusCode = 200
              ..write(
                '<div class="chapter"><a class="link" href="/c1">第一章</a></div>',
              );
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_can_rename_false',
            name: '重命名关闭测试源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTitleRule: '.title@text',
              detailAuthorRule: '.author@text',
              detailCanRenameRule: 'false',
              detailTocUrlRule: '.toc@href',
              tocListRule: '.chapter@html',
              tocTitleRule: '.link@text',
              tocChapterUrlRule: '.link@href',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_can_rename_false',
          bookId: 'book_can_rename_false',
          detailUrl: '$baseUrl/book/can-rename-false',
          fallbackTitle: '入口标题',
          fallbackAuthor: '入口作者',
        );

        expect(result.detail.title, '入口标题');
        expect(result.detail.author, '入口作者');
        expect(result.chapters, hasLength(1));

        await server.close(force: true);
      },
    );

    test(
      'overrides fallback title/author when canReName evaluates true',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          if (request.uri.path == '/book/can-rename-true') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="title">详情标题</h1>
              <span class="author">详情作者</span>
              <a class="toc" href="/book/can-rename-true/toc">目录</a>
            ''');
          } else if (request.uri.path == '/book/can-rename-true/toc') {
            request.response
              ..statusCode = 200
              ..write(
                '<div class="chapter"><a class="link" href="/c1">第一章</a></div>',
              );
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_can_rename_true',
            name: '重命名开启测试源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              detailTitleRule: '.title@text',
              detailAuthorRule: '.author@text',
              detailCanRenameRule: 'true',
              detailTocUrlRule: '.toc@href',
              tocListRule: '.chapter@html',
              tocTitleRule: '.link@text',
              tocChapterUrlRule: '.link@href',
            ),
          ),
        ]);

        final service = BookDetailService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_can_rename_true',
          bookId: 'book_can_rename_true',
          detailUrl: '$baseUrl/book/can-rename-true',
          fallbackTitle: '入口标题',
          fallbackAuthor: '入口作者',
        );

        expect(result.detail.title, '详情标题');
        expect(result.detail.author, '详情作者');
        expect(result.chapters, hasLength(1));

        await server.close(force: true);
      },
    );

    test(
      'uses sourceRegex matched resource url for webView detail parsing',
      () async {
        final webViewExecutor = _FakeWebViewExecutor(
          body: '''
          <div class="ignored">ignored html</div>
        ''',
          matchedResourceUrl: 'https://cdn.example.com/ch/101',
        );
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_webview_detail_regex',
            name: 'WebView详情嗅探源',
            baseUrl: 'https://example.com',
            rules: const SourceRuleSet(
              detailTitleRule:
                  r'regex:(https://cdn\.example\.com/ch/\d+)::group=1',
              tocListRule: r'regex:(https://cdn\.example\.com/ch/\d+)::group=1',
              tocTitleRule: '@js:result',
              tocChapterUrlRule: '@js:result',
            ),
          ),
        ]);

        final service = BookDetailService(
          sourceRepository: repository,
          webViewExecutor: webViewExecutor,
        );
        final result = await service.load(
          sourceId: 's_webview_detail_regex',
          bookId: 'book_webview_detail_regex',
          detailUrl:
              'https://example.com/detail,{"webView":true,"sourceRegex":"cdn\\\\.example\\\\.com"}',
        );

        expect(result.detail.title, 'https://cdn.example.com/ch/101');
        expect(result.chapters, hasLength(1));
        expect(
          result.chapters.first.chapterUrl,
          'https://cdn.example.com/ch/101',
        );
        expect(webViewExecutor.callCount, 1);
        expect(webViewExecutor.lastRequest?.sourceRegex, r'cdn\.example\.com');
      },
    );

    test('falls back to HTTP when WebView detail request throws', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/detail') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="title">HTTP详情页</h1>
              <a class="toc" href="/detail/toc">目录</a>
            ''');
        } else if (request.uri.path == '/detail/toc') {
          request.response
            ..statusCode = 200
            ..write(
              '<div class="chapter"><a class="link" href="/detail/c1">第一章</a></div>',
            );
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final webViewExecutor = _FakeWebViewExecutor(
        body: '<div>ignored</div>',
        error: StateError('webview detail crashed'),
      );
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_webview_detail_fallback',
          name: 'WebView详情回退源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            detailTitleRule: '.title@text',
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
          ),
        ),
      ]);

      final service = BookDetailService(
        sourceRepository: repository,
        webViewExecutor: webViewExecutor,
      );
      final result = await service.load(
        sourceId: 's_webview_detail_fallback',
        bookId: 'book_webview_detail_fallback',
        detailUrl: '$baseUrl/detail,{"webView":true}',
      );

      expect(webViewExecutor.callCount, 1);
      expect(result.detail.title, 'HTTP详情页');
      expect(result.chapters, hasLength(1));
      expect(result.chapters.first.chapterUrl, '$baseUrl/detail/c1');

      await server.close(force: true);
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
  Future<void> setGroup({required String sourceId, String? group}) async {
    final index = sources.indexWhere((source) => source.id == sourceId);
    if (index == -1) {
      return;
    }
    sources[index] = sources[index].copyWith(group: group);
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

class _NoopScriptSourceRepository implements ScriptSourceRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<void> deleteById(String id) async {}

  @override
  Future<List<ScriptSource>> getAll() async => const <ScriptSource>[];

  @override
  Future<ScriptSource?> getById(String id) async => null;

  @override
  Future<void> setEnabled({required String id, required bool enabled}) async {}

  @override
  Future<void> upsert(ScriptSource source) async {}

  @override
  Stream<List<ScriptSource>> watchAll() =>
      const Stream<List<ScriptSource>>.empty();
}

class _FakeScriptSourceRuntimeService extends ScriptSourceRuntimeService {
  _FakeScriptSourceRuntimeService({
    required List<RegisteredSource> registeredSources,
    required this.detailBySourceId,
    required this.chaptersBySourceId,
  }) : _registeredSources = registeredSources,
       super();

  final List<RegisteredSource> _registeredSources;
  final Map<String, runtime_models.Book> detailBySourceId;
  final Map<String, List<runtime_models.Chapter>> chaptersBySourceId;

  @override
  RegisteredSource? sourceById(String sourceId) {
    for (final source in _registeredSources) {
      if (source.runtime.id == sourceId) {
        return source;
      }
    }
    return null;
  }

  @override
  Future<runtime_models.Book> detail({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    return detailBySourceId[sourceId] ?? book;
  }

  @override
  Future<List<runtime_models.Chapter>> chapters({
    required String sourceId,
    required runtime_models.Book book,
  }) async {
    return chaptersBySourceId[sourceId] ?? const <runtime_models.Chapter>[];
  }
}

Future<List<runtime_models.Book>> _noopRuntimeSearch(
  SourceRuntimeContext _,
  String __,
) async => const <runtime_models.Book>[];

Future<runtime_models.Book> _noopRuntimeDetail(
  SourceRuntimeContext _,
  runtime_models.Book book,
) async => book;

Future<List<runtime_models.Chapter>> _noopRuntimeChapters(
  SourceRuntimeContext _,
  runtime_models.Book __,
) async => const <runtime_models.Chapter>[];

Future<runtime_models.Content> _noopRuntimeContent(
  SourceRuntimeContext _,
  runtime_models.Book __,
  runtime_models.Chapter chapter,
) async => runtime_models.Content(title: chapter.title, content: '');

class _FakeWebViewExecutor extends WebViewExecutor {
  _FakeWebViewExecutor({
    required this.body,
    this.matchedResourceUrl,
    this.error,
  });

  final String body;
  final String? matchedResourceUrl;
  final Object? error;
  int callCount = 0;
  WebViewRequestPayload? lastRequest;

  @override
  Future<WebViewResponsePayload> load({
    required WebViewRequestPayload request,
  }) async {
    callCount += 1;
    lastRequest = request;
    if (error != null) {
      throw error!;
    }
    return WebViewResponsePayload(
      statusCode: 200,
      body: body,
      finalUrl: request.url,
      matchedResourceUrl: matchedResourceUrl,
    );
  }
}
