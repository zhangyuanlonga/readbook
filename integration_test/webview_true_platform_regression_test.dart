import 'dart:io';

import 'package:flutter_appread/core/webview/webview_executor.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('webView:true platform regression', () {
    testWidgets(
      'runs search -> detail -> toc -> content with real WebView executor',
      (tester) async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final baseUrl = 'http://${server.address.host}:${server.port}';
        final detailRequestUrl = '$baseUrl/detail,{"webView":true}';
        final tocRequestUrl = '$baseUrl/toc,{"webView":true}';
        final chapterRequestUrl = '$baseUrl/chapter-1,{"webView":true}';

        server.listen((request) async {
          if (request.uri.path == '/search') {
            request.response
              ..statusCode = 200
              ..write('''
                <div class="item">
                  <a class="name" href='$detailRequestUrl'>Platform Book</a>
                </div>
              ''');
          } else if (request.uri.path == '/detail') {
            request.response
              ..statusCode = 200
              ..write('''
                <h1 class="title">Platform Detail</h1>
                <a class="toc" href='$tocRequestUrl'>Table</a>
              ''');
          } else if (request.uri.path == '/toc') {
            request.response
              ..statusCode = 200
              ..write('''
                <div class="chapter">
                  <a class="link" href='$chapterRequestUrl'>Chapter 1</a>
                </div>
              ''');
          } else if (request.uri.path == '/chapter-1') {
            request.response
              ..statusCode = 200
              ..write('<div class="content">Platform Content</div>');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        final source = SourceDefinition(
          id: 'webview_platform_chain',
          name: 'WebView Platform Chain',
          baseUrl: baseUrl,
          rules: const SourceRuleSet(
            searchRule:
                '/search?keyword={{key}},{"webView":true,"webJs":"window.__search_smoke=1;"}',
            searchListRule: '.item@html',
            searchTitleRule: '.name@text',
            searchDetailUrlRule: '.name@href',
            detailTitleRule: '.title@text',
            detailTocUrlRule: '.toc@href',
            tocListRule: '.chapter@html',
            tocTitleRule: '.link@text',
            tocChapterUrlRule: '.link@href',
            contentRule: '.content@text',
          ),
        );

        final repository = _FakeSourceRepository([source]);
        final webViewExecutor = WebViewExecutor(poolSize: 1);

        try {
          final searchService = SearchService(
            sourceRepository: repository,
            webViewExecutor: webViewExecutor,
          );
          final detailService = BookDetailService(
            sourceRepository: repository,
            webViewExecutor: webViewExecutor,
          );
          final contentService = ChapterContentService(
            sourceRepository: repository,
            webViewExecutor: webViewExecutor,
          );

          final searchReport = await searchService.search(
            keyword: 'platform',
            sourceIds: [source.id],
            pageSize: 1,
          );
          expect(searchReport.failures, isEmpty);
          expect(searchReport.books, hasLength(1));

          final book = searchReport.books.first;
          expect(book.title, 'Platform Book');

          final detail = await detailService.load(
            sourceId: source.id,
            bookId: book.id,
            detailUrl: book.detailUrl,
            fallbackTitle: book.title,
            forceRefresh: true,
          );
          expect(detail.detail.title, 'Platform Detail');
          expect(detail.chapters, hasLength(1));

          final chapter = detail.chapters.first;
          final content = await contentService.load(
            sourceId: source.id,
            bookId: book.id,
            chapterIndex: chapter.index,
            chapterTitle: chapter.title,
            chapterUrl: chapter.chapterUrl,
          );
          expect(content.content, contains('Platform Content'));
        } finally {
          await webViewExecutor.dispose();
          await server.close(force: true);
        }
      },
    );

    testWidgets('captures sourceRegex resource url in real WebView', (
      tester,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://${server.address.host}:${server.port}';
      final executor = WebViewExecutor(poolSize: 1);

      server.listen((request) async {
        if (request.uri.path == '/resource-page') {
          request.response
            ..statusCode = 200
            ..write('''
              <html>
                <head><script src="$baseUrl/static/probe.js"></script></head>
                <body>probe</body>
              </html>
            ''');
        } else if (request.uri.path == '/static/probe.js') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType('application', 'javascript')
            ..write('window.__resource_probe=true;');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found');
        }
        await request.response.close();
      });

      try {
        final response = await executor.load(
          request: WebViewRequestPayload(
            url: '$baseUrl/resource-page',
            sourceRegex: r'static/probe\.js',
          ),
        );
        expect(response.statusCode, 200);
        expect(response.body, contains('probe'));
        expect(response.matchedResourceUrl, isNotNull);
        expect(response.matchedResourceUrl, contains('/static/probe.js'));
      } finally {
        await executor.dispose();
        await server.close(force: true);
      }
    });

    testWidgets(
      'supports repeated queued webview loads without completion race',
      (tester) async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final baseUrl = 'http://${server.address.host}:${server.port}';
        final executor = WebViewExecutor(poolSize: 1);

        server.listen((request) async {
          if (request.uri.path == '/parallel-a') {
            request.response
              ..statusCode = 200
              ..write('<html><body>A</body></html>');
          } else if (request.uri.path == '/parallel-b') {
            request.response
              ..statusCode = 200
              ..write('<html><body>B</body></html>');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found');
          }
          await request.response.close();
        });

        try {
          final first = executor.load(
            request: WebViewRequestPayload(url: '$baseUrl/parallel-a'),
          );
          final second = executor.load(
            request: WebViewRequestPayload(url: '$baseUrl/parallel-b'),
          );
          final responses = await Future.wait([first, second]);
          expect(responses, hasLength(2));
          expect(responses[0].body, contains('A'));
          expect(responses[1].body, contains('B'));
        } finally {
          await executor.dispose();
          await server.close(force: true);
        }
      },
    );
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
    if (index < 0) {
      return;
    }
    sources[index] = sources[index].copyWith(enabled: enabled);
  }

  @override
  Future<void> setGroup({required String sourceId, String? group}) async {
    final index = sources.indexWhere((source) => source.id == sourceId);
    if (index < 0) {
      return;
    }
    sources[index] = sources[index].copyWith(group: group);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> incoming) async {
    for (final source in incoming) {
      final index = sources.indexWhere((item) => item.id == source.id);
      if (index >= 0) {
        sources[index] = source;
      } else {
        sources.add(source);
      }
    }
  }

  @override
  Stream<List<SourceDefinition>> watchAll() {
    return Stream.value(List.unmodifiable(sources));
  }
}
