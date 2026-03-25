import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/webview/webview_executor.dart';
import 'package:flutter_appread/domain/entities/script_source.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/domain/repositories/script_source_repository.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/source/application/script_source_runtime_service.dart';
import 'package:flutter_appread/features/source/application/source_runtime_facade.dart';
import 'package:flutter_appread/runtime/sources/source_contract.dart';
import 'package:flutter_appread/runtime/sources/source_manifest.dart';
import 'package:flutter_appread/runtime/sources/source_registry.dart';
import 'package:flutter_appread/runtime/sources/source_result_models.dart'
    as runtime_models;
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnitTestServicesBinding extends BindingBase
    with SchedulerBinding, ServicesBinding {}

void main() {
  if (BindingBase.debugBindingType() == null) {
    _UnitTestServicesBinding();
  }
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

    test('loads chapter content from script runtime facade fallback', () async {
      final facade = SourceRuntimeFacade(
        scriptSourceRepository: _NoopScriptSourceRepository(),
        scriptRuntimeService: _FakeScriptSourceRuntimeService(
          registeredSources: <RegisteredSource>[
            RegisteredSource(
              runtime: const SourceRuntimeInfo(
                id: 'script_content_1',
                name: '脚本正文源',
                group: '默认分组',
                revision: 'script-1',
              ),
              definition: RuntimeSourceDefinition(
                manifest: const SourceManifest(
                  name: '脚本正文源',
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
          contentBySourceId: <String, runtime_models.Content>{
            'script_content_1': const runtime_models.Content(
              title: '脚本章节',
              content: '脚本正文内容',
              sourceId: 'script_content_1',
            ),
          },
        ),
      );

      final service = ChapterContentService(
        sourceRepository: _FakeSourceRepository(const <SourceDefinition>[]),
        sourceRuntimeFacade: facade,
      );

      final result = await service.load(
        sourceId: 'script_content_1',
        chapterUrl: 'https://script.example.com/chapter/1',
        bookId: 'script_book_1',
        chapterIndex: 0,
        chapterTitle: '第一章',
      );

      expect(result.content, '脚本正文内容');
    });

    test('applies content replaceRegex rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div class="content">第一段 REMOVE_ME 第二段</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_replace_regex',
          name: '替换源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule: '.content@text',
            contentReplaceRegex: r'REMOVE_ME##',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_replace_regex',
        chapterUrl: '$baseUrl/chapter-replace',
      );

      expect(result.content, contains('第一段'));
      expect(result.content, contains('第二段'));
      expect(result.content, isNot(contains('REMOVE_ME')));

      await server.close(force: true);
    });

    test('loads paged content via nextContentUrl rule', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/chapter/1') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="content">第一段</div>
              <a class="next" href="/chapter/1-p2">下一页</a>
            ''');
        } else if (request.uri.path == '/chapter/1-p2') {
          request.response
            ..statusCode = 200
            ..write('<div class="content">第二段</div>');
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
          id: 's_next_content',
          name: '正文翻页源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule: '.content@text',
            contentNextUrlRule: '.next@href',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_next_content',
        chapterUrl: '$baseUrl/chapter/1',
      );

      expect(result.content, contains('第一段'));
      expect(result.content, contains('第二段'));

      await server.close(force: true);
    });

    test('respects retry option in chapter request url', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          request.response
            ..statusCode = 500
            ..write('error');
        } else {
          request.response
            ..statusCode = 200
            ..write('<div class="content">重试成功</div>');
        }
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_retry_content',
          name: '重试源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(contentRule: '.content@text'),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_retry_content',
        chapterUrl: '$baseUrl/chapter-retry,{"retry":1}',
      );

      expect(result.content, contains('重试成功'));
      expect(requestCount, 2);

      await server.close(force: true);
    });

    test('passes source/book/chapter js context into content rules', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div class="content">ignored</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_ctx_content',
          name: 'JS正文源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule:
                "@js:book.id + '|' + chapter.chapterUrl + '|' + source.bookSourceName",
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_ctx_content',
        chapterUrl: '$baseUrl/chapter/42',
        bookId: 'book_ctx_42',
        chapterIndex: 3,
        chapterTitle: '第三章',
      );

      expect(result.content, 'book_ctx_42|$baseUrl/chapter/42|JS正文源');

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

    test('supports gbk decoding for content init and chapter requests', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final gbk = Charset.getByName('gbk');
      expect(gbk, isNotNull);
      String? observedToken;

      server.listen((request) async {
        if (request.uri.path == '/content/init') {
          const payload = '{"token":"token-1"}';
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('application', 'json')
            ..add(gbk!.encode(payload));
        } else if (request.uri.path == '/content/main') {
          observedToken = request.headers.value('x-token');
          const html = '<div class="content">第一段</div>';
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('text', 'html')
            ..add(gbk!.encode(html));
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
          id: 's_gbk_content',
          name: 'GBK正文源',
          baseUrl: baseUrl,
          rules: SourceRuleSet(
            contentInitRule: '$baseUrl/content/init,{"charset":"GBK"}',
            contentRule: '.content@text',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_gbk_content',
        chapterUrl:
            '$baseUrl/content/main,{"charset":"GBK","headers":{"x-token":"{{token}}"}}',
      );

      expect(observedToken, 'token-1');
      expect(result.content, contains('第一段'));

      await server.close(force: true);
    });

    test(
      'supports legacy compressed json payload with shorthand content rule',
      () async {
        final payload =
            File(
              'test/fixtures/aaawz_detail_payload_lz_base64.txt',
            ).readAsStringSync().trim();

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response
            ..statusCode = 200
            ..write(payload);
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_legacy_content',
            name: 'Legacy正文源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(contentRule: 'intro'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_legacy_content',
          chapterUrl: '$baseUrl/api-info-13148-35',
        );

        expect(result.fromCache, isFalse);
        expect(result.content, contains('校园内少女遭肆虐'));
        expect(result.content, contains('法律面前不分年纪'));

        await server.close(force: true);
      },
    );

    test('decrypts legacy chapter payload via content decrypt rule', () async {
      const decryptRule =
          r'{"type":"aes_cbc_pkcs7_iv16_base64_lzbase64","key":"123#2^0@0vm@08.b5%$1[A]1&4115s((","urlContains":"-chapter-"}';
      final encryptedPayload = _encryptLegacyAesChapterPayload(
        plainText: '<div class="content">第一段\n\n第二段</div>',
        key: r'123#2^0@0vm@08.b5%$1[A]1&4115s((',
      );

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(encryptedPayload);
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_decrypt',
          name: '解密正文源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule: '.content@text',
            contentDecryptRule: decryptRule,
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_decrypt',
        chapterUrl: '$baseUrl/api-chapter-13148-35-10196648',
      );

      expect(result.content, contains('第一段'));
      expect(result.content, contains('第二段'));

      await server.close(force: true);
    });

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

    test('parses image chapter content and returns image urls', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var hitCount = 0;
      server.listen((request) async {
        hitCount++;
        request.response
          ..statusCode = 200
          ..write('''
            <div class="manga">
              <img src="/images/1.jpg" />
              <img src="https://cdn.example.com/2.png" />
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 'm1',
          name: '漫画源',
          baseUrl: baseUrl,
          sourceType: 2,
          rules: const SourceRuleSet(contentRule: '.manga img@src'),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);

      final first = await service.load(
        sourceId: 'm1',
        chapterUrl: '$baseUrl/chapter-1',
      );
      final second = await service.load(
        sourceId: 'm1',
        chapterUrl: '$baseUrl/chapter-1',
      );

      expect(first.isImageContent, isTrue);
      expect(first.imageUrls, hasLength(2));
      expect(first.imageUrls.first, '$baseUrl/images/1.jpg');
      expect(first.imageUrls.last, 'https://cdn.example.com/2.png');
      expect(first.fromCache, isFalse);
      expect(second.isImageContent, isTrue);
      expect(second.imageUrls, hasLength(2));
      expect(second.fromCache, isTrue);
      expect(hitCount, 1);

      await server.close(force: true);
    });

    test(
      'allows manga sources without ruleContent and extracts image urls',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response
            ..statusCode = 200
            ..write('''
            <div class="manga">
              <img data-src="/images/1001.jpg" />
              <img src="https://cdn.example.com/1002.png" />
            </div>
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 'm_no_content_rule',
            name: '漫画无正文规则源',
            baseUrl: baseUrl,
            sourceType: 2,
            rules: const SourceRuleSet(),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 'm_no_content_rule',
          chapterUrl: '$baseUrl/chapter-1',
        );

        expect(result.isImageContent, isTrue);
        expect(result.imageUrls, hasLength(2));
        expect(result.imageUrls.first, '$baseUrl/images/1001.jpg');
        expect(result.imageUrls.last, 'https://cdn.example.com/1002.png');

        await server.close(force: true);
      },
    );

    test(
      'falls back to response image extraction for lazy image attributes',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response
            ..statusCode = 200
            ..write('''
            <div class="manga">
              <img data-original="/images/1.jpg" />
              <img data-src="https://cdn.example.com/2.webp" />
            </div>
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 'm2',
            name: '漫画懒加载源',
            baseUrl: baseUrl,
            sourceType: 2,
            rules: const SourceRuleSet(contentRule: '.manga img@src'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 'm2',
          chapterUrl: '$baseUrl/chapter-1',
        );

        expect(result.isImageContent, isTrue);
        expect(result.imageUrls, hasLength(2));
        expect(result.imageUrls.first, '$baseUrl/images/1.jpg');
        expect(result.imageUrls.last, 'https://cdn.example.com/2.webp');

        await server.close(force: true);
      },
    );

    test(
      'extracts manga images from lazy attrs srcset background and embedded json',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response
            ..statusCode = 200
            ..write('''
            <div class="manga">
              <img data-lazy="/images/lazy.jpg" />
              <img data-echo="https://cdn.example.com/echo.png" />
              <img srcset="/images/srcset-1.jpg 1x, /images/srcset-2.jpg 2x" />
              <div style="background-image:url('/images/bg.webp')"></div>
              <script>
                window.__DATA__ = {"images":["/images/json-1.jpg","https://cdn.example.com/json-2.jpeg"]};
              </script>
            </div>
          ''');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 'm3',
            name: '漫画扩展规则源',
            baseUrl: baseUrl,
            sourceType: 2,
            rules: const SourceRuleSet(contentRule: '.manga img@src'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 'm3',
          chapterUrl: '$baseUrl/chapter-1',
        );

        expect(result.isImageContent, isTrue);
        expect(result.imageUrls, contains('$baseUrl/images/lazy.jpg'));
        expect(result.imageUrls, contains('https://cdn.example.com/echo.png'));
        expect(result.imageUrls, contains('$baseUrl/images/srcset-1.jpg'));
        expect(result.imageUrls, contains('$baseUrl/images/bg.webp'));
        expect(result.imageUrls, contains('$baseUrl/images/json-1.jpg'));
        expect(
          result.imageUrls,
          contains('https://cdn.example.com/json-2.jpeg'),
        );

        await server.close(force: true);
      },
    );

    test('returns anti-hotlink image headers and keeps them in cache', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<img src="/images/1.jpg" />');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 'm4',
          name: '防盗链源',
          baseUrl: baseUrl,
          sourceType: 2,
          headers: const {'User-Agent': 'source-agent'},
          rules: const SourceRuleSet(contentRule: '.manga img@src'),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);

      final first = await service.load(
        sourceId: 'm4',
        chapterUrl:
            '$baseUrl/chapter-1,{"headers":{"Referer":"$baseUrl/custom-ref","User-Agent":"reader-agent"}}',
      );
      final second = await service.load(
        sourceId: 'm4',
        chapterUrl:
            '$baseUrl/chapter-1,{"headers":{"Referer":"$baseUrl/custom-ref","User-Agent":"reader-agent"}}',
      );

      expect(first.isImageContent, isTrue);
      expect(first.imageHeaders['User-Agent'], 'reader-agent');
      expect(first.imageHeaders['Referer'], '$baseUrl/custom-ref');
      expect(first.imageHeaders['Origin'], baseUrl);
      expect(second.fromCache, isTrue);
      expect(second.imageHeaders['User-Agent'], 'reader-agent');
      expect(second.imageHeaders['Referer'], '$baseUrl/custom-ref');

      await server.close(force: true);
    });

    test(
      'supports onclick-like chapter url input for content request',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          request.response
            ..statusCode = 200
            ..write('<div class="content">第一段</div>');
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_click_content',
            name: '点击正文源',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(contentRule: '.content@text'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_click_content',
          chapterUrl: "open('/chapter-1')",
        );

        expect(result.content, contains('第一段'));

        await server.close(force: true);
      },
    );

    test(
      'throws validation when chapter url looks like html fragment',
      () async {
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_html_url',
            name: '无效链接源',
            baseUrl: 'https://example.com',
            rules: const SourceRuleSet(contentRule: '.content@text'),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);

        expect(
          () => service.load(
            sourceId: 's_html_url',
            chapterUrl: '<div class="content" id="chaptercontent">',
          ),
          throwsA(
            isA<AppException>()
                .having((error) => error.code, 'code', ErrorCode.validation)
                .having(
                  (error) => error.briefMessage,
                  'message',
                  contains('正文请求地址非法'),
                ),
          ),
        );
      },
    );

    test('supports @put/@get variable chain in content rule', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div class="body">正文变量链路</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_put_get_content',
          name: '@put/@get 正文源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule: '''@put:{ct:".body@text"}
@get:{ct}''',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_put_get_content',
        chapterUrl: '$baseUrl/chapter-1',
      );

      expect(result.content, contains('正文变量链路'));

      await server.close(force: true);
    });

    test('persists java.put/java.get as book-scoped variables', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div class="body">book variable</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_book_scope_content',
          name: 'book-scope-content',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule:
                '@js:var saved = java.get("bk"); saved ? saved : (java.put("bk", chapter.chapterUrl), "init")',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final first = await service.load(
        sourceId: 's_book_scope_content',
        chapterUrl: '$baseUrl/chapter-1',
        bookId: 'book-a',
      );
      expect(first.content, 'init');

      final second = await service.load(
        sourceId: 's_book_scope_content',
        chapterUrl: '$baseUrl/chapter-2',
        bookId: 'book-a',
      );
      expect(second.content, '$baseUrl/chapter-1');

      final third = await service.load(
        sourceId: 's_book_scope_content',
        chapterUrl: '$baseUrl/chapter-3',
        bookId: 'book-b',
      );
      expect(third.content, 'init');

      final persisted =
          repository.sources
                  .firstWhere((item) => item.id == 's_book_scope_content')
                  .originalSource?[r'_appread_js_book_variables']
              as Map?;
      expect(
        persisted?['book-a'],
        isA<Map>().having((value) => value['bk'], 'bk', '$baseUrl/chapter-1'),
      );
      expect(
        persisted?['book-b'],
        isA<Map>().having((value) => value['bk'], 'bk', '$baseUrl/chapter-3'),
      );

      await server.close(force: true);
    });

    test('supports xpath-style content rule', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div id="chapter">天地玄黄</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_xpath_content',
          name: 'XPath正文源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            contentRule: '//div[@id="chapter"]/text()',
          ),
        ),
      ]);

      final service = ChapterContentService(sourceRepository: repository);
      final result = await service.load(
        sourceId: 's_xpath_content',
        chapterUrl: '$baseUrl/chapter-1',
      );

      expect(result.content, contains('天地玄黄'));

      await server.close(force: true);
    });

    test(
      'supports mixed content init request + @put parse variables',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        String? observedToken;

        server.listen((request) async {
          if (request.uri.path == '/init') {
            request.response
              ..statusCode = 200
              ..write('<meta name="token" content="content-init-token" />');
          } else {
            observedToken = request.headers.value('x-token');
            request.response
              ..statusCode = 200
              ..write('<div class="content">正文初始化</div>');
          }
          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final repository = _FakeSourceRepository([
          SourceDefinition(
            id: 's_init_mixed_content',
            name: 'Init混合正文源',
            baseUrl: baseUrl,
            rules: SourceRuleSet(
              contentInitRule: '/init\n@put:{tk:"meta[name=token]@content"}',
              contentRule: '.content@text',
            ),
          ),
        ]);

        final service = ChapterContentService(sourceRepository: repository);
        final result = await service.load(
          sourceId: 's_init_mixed_content',
          chapterUrl: '$baseUrl/chapter-1,{"headers":{"x-token":"{{tk}}"}}',
        );

        expect(result.content, contains('正文初始化'));
        expect(observedToken, 'content-init-token');

        await server.close(force: true);
      },
    );

    test('uses sourceRegex matched resource url for webView content', () async {
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_webview_content_regex',
          name: 'WebView正文嗅探源',
          baseUrl: 'https://example.com',
          rules: const SourceRuleSet(contentRule: '@js:result'),
        ),
      ]);
      final webViewExecutor = _FakeWebViewExecutor(
        body: '<html><body>ignored</body></html>',
        matchedResourceUrl: 'https://cdn.example.com/audio/ch1.m3u8',
      );

      final service = ChapterContentService(
        sourceRepository: repository,
        webViewExecutor: webViewExecutor,
      );
      final result = await service.load(
        sourceId: 's_webview_content_regex',
        chapterUrl:
            'https://example.com/ch1,{"webView":true,"sourceRegex":"cdn\\\\.example\\\\.com","webJs":"window.__ok=true;"}',
      );

      expect(result.content, 'https://cdn.example.com/audio/ch1.m3u8');
      expect(webViewExecutor.callCount, 1);
      expect(webViewExecutor.lastRequest?.sourceRegex, r'cdn\.example\.com');
      expect(webViewExecutor.lastRequest?.webJs, 'window.__ok=true;');
    });

    test('falls back to HTTP when WebView content request throws', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('<div class="content">HTTP正文回退</div>');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final repository = _FakeSourceRepository([
        SourceDefinition(
          id: 's_webview_content_fallback',
          name: 'WebView正文回退源',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(contentRule: '.content@text'),
        ),
      ]);
      final webViewExecutor = _FakeWebViewExecutor(
        body: '<html><body>ignored</body></html>',
        error: StateError('webview content crashed'),
      );

      final service = ChapterContentService(
        sourceRepository: repository,
        webViewExecutor: webViewExecutor,
      );
      final result = await service.load(
        sourceId: 's_webview_content_fallback',
        chapterUrl: '$baseUrl/chapter-1,{"webView":true}',
      );

      expect(webViewExecutor.callCount, 1);
      expect(result.content, contains('HTTP正文回退'));

      await server.close(force: true);
    });

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

String _encryptLegacyAesChapterPayload({
  required String plainText,
  required String key,
}) {
  final iv = Uint8List.fromList(List<int>.generate(16, (index) => index + 1));
  final keyBytes = Uint8List.fromList(utf8.encode(key));

  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    CBCBlockCipher(AESEngine()),
  );
  cipher.init(
    true,
    PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
      ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), iv),
      null,
    ),
  );

  final encrypted = cipher.process(Uint8List.fromList(utf8.encode(plainText)));
  final payload = Uint8List.fromList(<int>[...iv, ...encrypted]);
  return base64.encode(payload);
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
    required this.contentBySourceId,
  }) : _registeredSources = registeredSources,
       super();

  final List<RegisteredSource> _registeredSources;
  final Map<String, runtime_models.Content> contentBySourceId;

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
  Future<runtime_models.Content> content({
    required String sourceId,
    required runtime_models.Book book,
    required runtime_models.Chapter chapter,
  }) async {
    return contentBySourceId[sourceId] ??
        runtime_models.Content(title: chapter.title, content: '');
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
