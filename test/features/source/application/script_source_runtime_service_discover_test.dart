import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/features/source/application/script_source_runtime_service.dart';
import 'package:flutter_appread/runtime/browser/browser_runtime.dart';
import 'package:flutter_appread/runtime/http/challenge_detector.dart';
import 'package:flutter_appread/runtime/http/http_models.dart';
import 'package:flutter_appread/runtime/http/request_engine.dart';
import 'package:flutter_appread/runtime/session/source_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QQ reader discover script', () {
    late ScriptSourceRuntimeService service;

    setUp(() {
      service = ScriptSourceRuntimeService(
        requestEngine: _FakeRequestEngine(),
        browserRuntime: const UnsupportedBrowserRuntime(),
      );
    });

    test(
      'discovers categories and maps category books to runtime books',
      () async {
        final sourceCode =
            File(
              'test/fixtures/script_sources/tencent_qq_reader_source_v1.js',
            ).readAsStringSync();

        await service.compileAndRegister(
          sourceCode: sourceCode,
          runtimeId: 'qq_reader_fixture',
        );

        final categories = await service.discoverCategories(
          sourceId: 'qq_reader_fixture',
        );
        expect(
          categories.map((item) => item.title),
          containsAll(<String>['男生 · 玄幻', '女生 · 古言', '出版 · 小说']),
        );

        final maleCategory = categories.firstWhere(
          (item) => item.title == '男生 · 玄幻',
        );
        expect(maleCategory.extra['categoryId'], 20001);
        expect(maleCategory.extra['bookType'], 1);

        final books = await service.discoverBooks(
          sourceId: 'qq_reader_fixture',
          category: maleCategory,
          page: 2,
          pageSize: 2,
        );

        expect(books, hasLength(2));

        final first = books.first;
        expect(first.title, '斗破苍穹');
        expect(first.author, '天蚕土豆');
        expect(first.category, '玄幻 / 东方玄幻');
        expect(first.status, '已完结');
        expect(first.detailUrl, contains('bookid=1100002557'));
        expect(first.tocUrl, contains('bookId=1100002557'));
        expect(first.sourceId, 'qq_reader_fixture');
        expect(first.extra['resourceId'], '1100002557');

        final second = books.last;
        expect(second.title, '苟在武道世界成圣');
        expect(second.author, '在水中的纸老虎');
        expect(second.category, '玄幻 / 东方玄幻');
        expect(second.status, '连载');
        expect(second.extra['resourceId'], '1155003366');
      },
    );
  });
}

class _FakeRequestEngine implements RequestEngine {
  static final Uri _discoverCategoriesUri = Uri.parse(
    'https://ubook.reader.qq.com/book-cate',
  );
  static final Uri _discoverBooksUri = Uri.parse(
    'https://ubook.reader.qq.com/api/book/categories/booklist',
  );

  @override
  Future<RuntimeHttpResponse> request(
    RuntimeHttpRequest request, {
    SourceSession? session,
  }) async {
    final uri = request.resolvedUri;
    if (uri == _discoverCategoriesUri) {
      return RuntimeHttpResponse(
        ok: true,
        status: 200,
        uri: uri,
        headers: const <String, String>{'content-type': 'text/html'},
        text: _discoverCategoriesHtml,
      );
    }

    if (uri.path == _discoverBooksUri.path) {
      final bookType = uri.queryParameters['bookType'];
      final categoryId = uri.queryParameters['categoryid'];
      final pageIndex = uri.queryParameters['pageIndex'];
      final pageSize = uri.queryParameters['pageSize'];
      final sorted = uri.queryParameters['sorted'];
      if (bookType == '1' &&
          categoryId == '20001' &&
          pageIndex == '2' &&
          pageSize == '2' &&
          sorted == '0') {
        final payload = <String, Object?>{
          'isLogin': false,
          'data': <String, Object?>{
            'total': 1000,
            'pages': 500,
            'pageIndex': 2,
            'name': '玄幻',
            'pageSize': 2,
            'list': <Map<String, Object?>>[
              <String, Object?>{
                'id': 2557,
                'title': '斗破苍穹',
                'author': '天蚕土豆',
                'cover': 'https://example.com/dpcq.jpg',
                'intro': '这里是简介',
                'score': 9.8,
                'finished': true,
                'lastChapterName': '第一千六百章 大结局',
                'totalWords': 5321200,
                'sexAttr': 1,
                'categories': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 20000,
                    'name': '小说',
                    'shortName': '小说',
                  },
                  <String, Object?>{
                    'id': 20001,
                    'name': '玄幻',
                    'shortName': '玄幻',
                  },
                  <String, Object?>{
                    'id': 20002,
                    'name': '东方玄幻',
                    'shortName': '东方玄幻',
                  },
                ],
              },
              <String, Object?>{
                'id': 55003366,
                'title': '苟在武道世界成圣',
                'author': '在水中的纸老虎',
                'cover': 'https://example.com/gzwdsjcs.jpg',
                'intro': '第二本简介',
                'score': 9.1,
                'finished': false,
                'lastChapterName': '第312章 新的征途',
                'totalWords': 3120000,
                'sexAttr': 1,
                'categories': <Map<String, Object?>>[
                  <String, Object?>{
                    'id': 20000,
                    'name': '小说',
                    'shortName': '小说',
                  },
                  <String, Object?>{
                    'id': 20001,
                    'name': '玄幻',
                    'shortName': '玄幻',
                  },
                  <String, Object?>{
                    'id': 20002,
                    'name': '东方玄幻',
                    'shortName': '东方玄幻',
                  },
                ],
              },
            ],
          },
        };
        return RuntimeHttpResponse(
          ok: true,
          status: 200,
          uri: uri,
          headers: const <String, String>{'content-type': 'application/json'},
          text: jsonEncode(payload),
          json: payload,
        );
      }
    }

    throw StateError('Unexpected request: ${uri.toString()}');
  }

  @override
  bool isHtml(RuntimeHttpResponse response) {
    return response.contentType?.contains('text/html') ?? false;
  }

  @override
  bool isJson(RuntimeHttpResponse response) {
    return response.contentType?.contains('application/json') ?? false;
  }

  @override
  bool isRedirect(RuntimeHttpResponse response) => false;

  @override
  bool isChallenge(RuntimeHttpResponse response) => false;

  @override
  ChallengeDetectionResult detectChallenge(RuntimeHttpResponse response) {
    return const ChallengeDetectionResult(isChallenge: false);
  }
}

const String _discoverCategoriesHtml = '''
<!doctype html>
<html>
  <body>
    <div class="cate-list">
      <p class="cate-tab">男生</p>
      <ul>
        <li>
          <a href="//ubook.reader.qq.com/book-cate/20001-0-0-0-0-0-0-1">
            <p class="cate-name">玄幻</p>
          </a>
        </li>
      </ul>
    </div>
    <div class="cate-list">
      <p class="cate-tab">女生</p>
      <ul>
        <li>
          <a href="//ubook.reader.qq.com/book-cate/30013-0-0-0-0-0-0-1">
            <p class="cate-name">古言</p>
          </a>
        </li>
      </ul>
    </div>
    <div class="cate-list">
      <p class="cate-tab">出版</p>
      <ul>
        <li>
          <a href="//ubook.reader.qq.com/book-cate/13100-0-0-0-0-0-0-1">
            <p class="cate-name">小说</p>
          </a>
        </li>
      </ul>
    </div>
  </body>
</html>
''';
