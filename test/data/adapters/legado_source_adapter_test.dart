import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/errors/app_exception.dart';
import 'package:flutter_appread/core/errors/error_codes.dart';
import 'package:flutter_appread/data/adapters/legado_source_adapter.dart';
import 'package:flutter_appread/data/models/legado_source_raw.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegadoSourceAdapter', () {
    const adapter = LegadoSourceAdapter();

    test('maps legado fields to source definition', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试书源',
        'bookSourceUrl': 'https://example.com',
        'bookSourceGroup': '小说',
        'bookSourceComment': '示例备注',
        'enabled': false,
        'ruleSearch': '.book-list',
        'ruleBookInfo': '.book-detail',
        'ruleToc': '.chapter-item',
        'ruleContent': '#content',
        'header': 'User-Agent@appread&&Referer@https://example.com',
      });

      final source = adapter.adapt(raw);

      expect(source.id, startsWith('src_'));
      expect(source.name, '测试书源');
      expect(source.baseUrl, 'https://example.com');
      expect(source.group, '小说');
      expect(source.comment, '示例备注');
      expect(source.enabled, isFalse);
      expect(source.rules.searchRule, '.book-list');
      expect(source.rules.detailRule, '.book-detail');
      expect(source.rules.tocRule, '.chapter-item');
      expect(source.rules.contentRule, '#content');
      expect(source.headers['User-Agent'], 'appread');
      expect(source.headers['Referer'], 'https://example.com');
      expect(source.lastCheckStatus, SourceHealthStatus.unknown);
      expect(source.originalSource?['bookSourceName'], '测试书源');
      expect(source.originalSource?['ruleSearch'], '.book-list');
    });

    test('maps nested ruleSearch fields', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': 'Map源',
        'bookSourceUrl': 'https://map.example.com',
        'searchUrl': '/search?key={{key}}',
        'ruleSearch': {
          'bookList': '.result-item@html',
          'name': '.title@text',
          'bookUrl': '.title@href',
          'author': '.author@text',
          'intro': '.intro@text',
          'coverUrl': '.cover@src',
          'lastChapter': '.latest@text',
        },
      });

      final source = adapter.adapt(raw);

      expect(source.rules.searchRule, '/search?key={{key}}');
      expect(source.rules.searchListRule, '.result-item@html');
      expect(source.rules.searchTitleRule, '.title@text');
      expect(source.rules.searchDetailUrlRule, '.title@href');
      expect(source.rules.searchAuthorRule, '.author@text');
      expect(source.rules.searchIntroRule, '.intro@text');
      expect(source.rules.searchCoverUrlRule, '.cover@src');
      expect(source.rules.searchLatestChapterRule, '.latest@text');
    });

    test('maps nested detail and toc fields', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '详情目录源',
        'bookSourceUrl': 'https://detail.example.com',
        'searchUrl': '/search?key={{key}}',
        'ruleBookInfo': {
          'name': '.book-title@text',
          'author': '.book-author@text',
          'intro': '.book-intro@text',
          'coverUrl': '.cover@src',
          'tocUrl': '.toc@href',
        },
        'ruleToc': {
          'chapterList': '.chapter-item@html',
          'chapterName': '.chapter-title@text',
          'chapterUrl': '.chapter-title@href',
          'isReverse': true,
        },
      });

      final source = adapter.adapt(raw);

      expect(source.rules.detailTitleRule, '.book-title@text');
      expect(source.rules.detailAuthorRule, '.book-author@text');
      expect(source.rules.detailIntroRule, '.book-intro@text');
      expect(source.rules.detailCoverUrlRule, '.cover@src');
      expect(source.rules.detailTocUrlRule, '.toc@href');
      expect(source.rules.tocListRule, '.chapter-item@html');
      expect(source.rules.tocTitleRule, '.chapter-title@text');
      expect(source.rules.tocChapterUrlRule, '.chapter-title@href');
      expect(source.rules.tocReversed, isTrue);
    });

    test('maps nested ruleContent fields', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '正文源',
        'bookSourceUrl': 'https://content.example.com',
        'ruleContent': {'content': '4.data.content'},
      });

      final source = adapter.adapt(raw);

      expect(source.rules.contentRule, '4.data.content');
    });

    test('maps init rules for search/detail/toc/content stages', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': 'Init源',
        'bookSourceUrl': 'https://init.example.com',
        'ruleSearch': {
          'init': '/search/init',
          'bookList': '.item@html',
          'name': '.name@text',
          'bookUrl': '.name@href',
        },
        'ruleBookInfo': {
          'init': '/detail/init,{"method":"POST","body":"id={{bookId}}"}',
          'name': '.title@text',
        },
        'ruleToc': {
          'init': '/toc/init',
          'chapterList': '.chapter@html',
          'chapterName': '.name@text',
          'chapterUrl': '.name@href',
        },
        'ruleContent': {'init': '/content/init', 'content': '.content@html'},
      });

      final source = adapter.adapt(raw);

      expect(source.rules.searchInitRule, '/search/init');
      expect(
        source.rules.detailInitRule,
        '/detail/init,{"method":"POST","body":"id={{bookId}}"}',
      );
      expect(source.rules.detailRule, isNull);
      expect(source.rules.tocInitRule, '/toc/init');
      expect(source.rules.contentInitRule, '/content/init');
    });

    test('downgrades inline-js manga rules to static fallback rules', () {
      final payload =
          jsonDecode(File('1771173829.json').readAsStringSync())
              as List<dynamic>;
      final raw = LegadoSourceRaw.fromJson(
        Map<String, dynamic>.from(payload.first as Map),
      );

      final source = adapter.adapt(raw);

      expect(source.sourceType, 2);
      expect(source.rules.searchRule, '/search?keyword={{key}}');
      expect(source.rules.searchDetailUrlRule, 'a@href');
      expect(source.rules.detailRule, '.detail-main-info-title@html');
      expect(source.rules.detailTitleRule, '.detail-main-info-title@text');
      expect(
        source.rules.detailAuthorRule,
        '.detail-main-info-author:nth-child(3)@text',
      );
      expect(source.rules.detailIntroRule, 'p.detail-desc@text');
      expect(source.rules.detailTocUrlRule, '.detail-list-1 li a@href');
      expect(source.rules.tocListRule, '.detail-list-1 li@html');
      expect(source.rules.tocTitleRule, 'a@text');
      expect(source.rules.tocChapterUrlRule, 'a@href');
      expect(source.rules.contentRule, '.view-main-1.readForm img@src');
    });

    test('converts server proxy source to api-compatible rules', () {
      final payload =
          jsonDecode(File('番茄四合一.json').readAsStringSync()) as List<dynamic>;
      final raw = LegadoSourceRaw.fromJson(
        Map<String, dynamic>.from(payload.first as Map),
      );

      final source = adapter.adapt(raw);

      expect(source.baseUrl, 'https://fq.vv9v.cn');
      expect(source.headers['x-sec-token'], '{{sourceToken}}');
      expect(source.headers['x-android-id'], '{{androidId}}');
      expect(source.requiresServerTokenAuth, isTrue);
      expect(
        source.rules.searchRule,
        '/{{sourceMode}}/search?keyword={{serverKeyword|encode}}&page={{page}}',
      );
      expect(
        source.rules.searchDetailUrlRule,
        r'{{$.type}}/info?novelId={{$.book_id}}',
      );
      expect(
        source.rules.contentRule,
        r'json:$.data.content||json:$.data.url||json:$.data.images[*]',
      );
    });

    test('falls back to searchUrl when ruleSearch is missing', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试书源',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': '/search?key={{key}}',
      });

      final source = adapter.adapt(raw);

      expect(source.rules.searchRule, '/search?key={{key}}');
    });

    test('repairs mojibake source name and group text', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': 'æ™´å¤©å°è¯´',
        'bookSourceGroup': 'åˆ†ç»„',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': '/search?key={{key}}',
      });

      final source = adapter.adapt(raw);

      expect(source.name, '晴天小说');
      expect(source.group, '分组');
    });

    test('supports json header format', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试书源',
        'bookSourceUrl': 'https://example.com',
        'header': '{"User-Agent":"appread","X-Trace":"trace-id"}',
      });

      final source = adapter.adapt(raw);

      expect(source.headers, {'User-Agent': 'appread', 'X-Trace': 'trace-id'});
    });

    test('parses js header object and resolves source.key fallback', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '动态Header源',
        'bookSourceUrl': 'https://example.com',
        'searchUrl': '/search?key={{key}}',
        'header': '''
@js:JSON.stringify({
  'Accept': 'application/json, text/plain, */*',
  'origin': source.key,
  'referer': source.key + '/'
})
''',
      });

      final source = adapter.adapt(raw);

      expect(source.headers['Accept'], 'application/json, text/plain, */*');
      expect(source.headers['origin'], 'https://example.com');
      expect(source.headers['referer'], 'https://example.com/');
    });

    test('extracts legacy chapter decrypt config from loginCheckJs', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '3A小说',
        'bookSourceUrl': 'https://www.aaawz.cc',
        'ruleContent': {'content': '@js:result'},
        'loginCheckJs': r'''
let url = result.url()
let body = result.body()
if(url.includes('-chapter-')){
  let data = java.base64DecodeToByteArray(body)
  let iv = data.slice(0,16)
  let x = java.createSymmetricCrypto('AES/CBC/PKCS7Padding',java.strToBytes('123#2^0@0vm@08.b5%$1[A]1&4115s(('), iv)
  body = x.decryptStr(data.slice(16, data.length))
}
Packages.io.legado.app.help.http.StrResponse(url, decompressFromBase64(String(body).replace(/\s/g,'')))
''',
      });

      final source = adapter.adapt(raw);
      final decryptRule = source.rules.contentDecryptRule;

      expect(decryptRule, isNotNull);
      final decoded = jsonDecode(decryptRule!) as Map<String, dynamic>;
      expect(decoded['type'], 'aes_cbc_pkcs7_iv16_base64_lzbase64');
      expect(decoded['key'], r'123#2^0@0vm@08.b5%$1[A]1&4115s((');
      expect(decoded['urlContains'], '-chapter-');
    });

    test('extracts lz-base64 decrypt config without aes branch', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': 'LZ正文源',
        'bookSourceUrl': 'https://example.com',
        'ruleContent': {'content': '@js:result'},
        'loginCheckJs': r'''
let url = result.url()
let body = result.body()
if(url.includes('/api-chapter-')){
  body = decompressFromBase64(String(body).replace(/\s/g,''))
}
Packages.io.legado.app.help.http.StrResponse(url, body)
''',
      });

      final source = adapter.adapt(raw);
      final decryptRule = source.rules.contentDecryptRule;

      expect(decryptRule, isNotNull);
      final decoded = jsonDecode(decryptRule!) as Map<String, dynamic>;
      expect(decoded['type'], 'lz_base64');
      expect(decoded['urlContains'], '/api-chapter-');
    });

    test('extracts base64 decrypt config when only base64 decode appears', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': 'Base64正文源',
        'bookSourceUrl': 'https://example.com',
        'ruleContent': {'content': '@js:result'},
        'loginCheckJs': r'''
let url = result.url()
let body = result.body()
if(url.includes('/chapter/')){
  let data = java.base64DecodeToByteArray(body)
  body = java.bytesToString(data)
}
Packages.io.legado.app.help.http.StrResponse(url, body)
''',
      });

      final source = adapter.adapt(raw);
      final decryptRule = source.rules.contentDecryptRule;

      expect(decryptRule, isNotNull);
      final decoded = jsonDecode(decryptRule!) as Map<String, dynamic>;
      expect(decoded['type'], 'base64_utf8');
      expect(decoded['urlContains'], '/chapter/');
    });

    test('throws validation exception when required fields are missing', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '',
        'bookSourceUrl': '   ',
      });

      expect(
        () => adapter.adapt(raw),
        throwsA(
          isA<AppException>()
              .having((error) => error.code, 'code', ErrorCode.validation)
              .having(
                (error) => error.briefMessage,
                'briefMessage',
                contains('bookSourceName'),
              ),
        ),
      );
    });

    test('creates deterministic id for same source payload', () {
      final raw = LegadoSourceRaw.fromJson({
        'bookSourceName': '测试书源',
        'bookSourceUrl': 'https://example.com',
        'bookSourceGroup': '小说',
      });

      final first = adapter.adapt(raw);
      final second = adapter.adapt(raw);

      expect(first.id, second.id);
    });
  });
}
