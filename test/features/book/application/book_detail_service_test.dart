import 'dart:io';

import 'package:charset/charset.dart';
import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/core/errors/error_stage.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
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
