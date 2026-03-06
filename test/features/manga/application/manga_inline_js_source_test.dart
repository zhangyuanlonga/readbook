import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/core/result/result.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_appread/features/source/application/source_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Inline-js manga source fallback', () {
    test('supports 1771173829 source without reload runtime', () async {
      final payload =
          jsonDecode(File('1771173829.json').readAsStringSync())
              as List<dynamic>;
      final item = Map<String, dynamic>.from(payload.first as Map);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final baseUrl = 'http://${server.address.host}:${server.port}';
      item['bookSourceUrl'] = baseUrl;
      item['searchUrl'] = '''
<js>
eval(function(p,a,c,k,e,r){e=function(c){return c.toString(a)};if(!''.replace(/^/,String)){while(c--)r[e(c)]=k[c]||e(c);k=[function(e){return r[e]}];e=function(){return'\\w+'};c=1};while(c--)if(k[c])p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c]);return p}('0(1(2.3));4==5?"/search?keyword={{key}}":6.7("\\n\\u2757\\u672a\\u542f\\u7528\\u4e66\\u6e90\\u2757");',8,8,'eval|String|source|bookSourceComment|1|flag|java|toast'.split('|'),0,{}))
</js>
''';

      server.listen((request) async {
        if (request.uri.path == '/search') {
          request.response
            ..statusCode = 200
            ..write('''
              <ul class="book-list">
                <li>
                  <a href="$baseUrl/comic/1001">详情</a>
                  <div class="book-list-info-title">测试漫画</div>
                </li>
              </ul>
            ''');
        } else if (request.uri.path == '/comic/1001') {
          request.response
            ..statusCode = 200
            ..write('''
              <h1 class="detail-main-info-title">测试漫画</h1>
              <div class="detail-main-info-author"></div>
              <div class="detail-main-info-author"></div>
              <div class="detail-main-info-author">测试作者</div>
              <p class="detail-desc">漫画简介文本</p>
              <div class="detail-main-cover"><img data-original="$baseUrl/covers/1001.jpg" /></div>
              <ul class="detail-list-1">
                <li><a href="$baseUrl/comic/1001/ch1">第1话</a></li>
              </ul>
            ''');
        } else if (request.uri.path == '/comic/1001/ch1') {
          request.response
            ..statusCode = 200
            ..write('''
              <div class="view-main-1 readForm">
                <img src="$baseUrl/images/1.jpg" />
                <img src="$baseUrl/images/2.jpg" />
              </div>
            ''');
        } else {
          request.response
            ..statusCode = 404
            ..write('not found: ${request.uri.path}');
        }
        await request.response.close();
      });

      final importService = SourceImportService();
      final importResult = importService.importFromText(jsonEncode([item]));
      expect(importResult, isA<Success<List<SourceDefinition>>>());
      final source =
          (importResult as Success<List<SourceDefinition>>).data.first;

      expect(source.rules.searchRule, '/search?keyword={{key}}');
      expect(source.rules.tocListRule, '.detail-list-1 li@html');
      expect(source.rules.contentRule, '.view-main-1.readForm img@src');

      final repository = _FakeSourceRepository([source]);
      final searchService = SearchService(sourceRepository: repository);
      final detailService = BookDetailService(sourceRepository: repository);
      final contentService = ChapterContentService(
        sourceRepository: repository,
      );

      final searchResult = await searchService.search(
        keyword: '测试',
        contentMode: SearchContentMode.manga,
      );
      expect(searchResult.books, hasLength(1));

      final book = searchResult.books.first;
      final detail = await detailService.load(
        sourceId: source.id,
        bookId: book.id,
        detailUrl: book.detailUrl,
      );
      expect(detail.detail.title, '测试漫画');
      expect(detail.chapters, hasLength(1));

      final content = await contentService.load(
        sourceId: source.id,
        chapterUrl: detail.chapters.first.chapterUrl,
        bookId: book.id,
        chapterIndex: 0,
      );

      expect(content.isImageContent, isTrue);
      expect(content.imageUrls, hasLength(2));

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
    return List<SourceDefinition>.unmodifiable(sources);
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
  Future<void> upsertAll(List<SourceDefinition> updatedSources) async {
    for (final source in updatedSources) {
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
    return Stream<List<SourceDefinition>>.value(
      List<SourceDefinition>.unmodifiable(sources),
    );
  }
}
