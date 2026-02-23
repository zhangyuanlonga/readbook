import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:charset/charset.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';

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
