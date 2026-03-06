import 'dart:io';

import 'package:flutter_appread/core/result/result.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_appread/features/source/application/source_capability_analyzer.dart';
import 'package:flutter_appread/features/source/application/source_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Manga JS-free regression', () {
    test(
      'fixture keeps three JS-free manga samples with no unsupported hint',
      () {
        final payload = _readFixture().replaceAll(
          '__BASE_URL__',
          'https://manga.example.com',
        );
        final service = SourceImportService();
        final result = service.previewFromText(payload);

        expect(result, isA<Success<SourceImportPreviewReport>>());
        final report = (result as Success<SourceImportPreviewReport>).data;

        expect(report.totalCount, 3);
        expect(report.validCount, 3);
        expect(report.invalidCount, 0);
        expect(
          report.compatibilityHints.where(
            (hint) => hint.level == SourceCompatibilityLevel.unsupported,
          ),
          isEmpty,
        );
        expect(
          report.compatibilityHints
              .expand((hint) => hint.reasons)
              .where(
                (reason) => reason.contains('JS') || reason.contains('Reload'),
              ),
          isEmpty,
        );
      },
    );

    test(
      'three JS-free manga sources pass search-detail-toc-content flow',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          final path = request.uri.path;

          if (path == '/s1/search') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="book"><a class="title" href="/s1/book/1">样例漫画A</a><span class="author">作者A</span></div>
            ''');
          } else if (path == '/s1/book/1') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="name">样例漫画A</h1>
              <span class="author">作者A</span>
              <p class="intro">A简介</p>
              <img class="cover" src="/covers/a.jpg" />
              <a class="toc" href="/s1/book/1/toc">目录</a>
            ''');
          } else if (path == '/s1/book/1/toc') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="chapter"><a class="link" href="/s1/book/1/ch1">第1话</a></div>
            ''');
          } else if (path == '/s1/book/1/ch1') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="viewer"><img src="/images/a-1.jpg" /><img src="/images/a-2.jpg" /></div>
            ''');
          } else if (path == '/s2/search') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="book"><a class="title" href="/s2/book/1">样例漫画B</a><span class="author">作者B</span></div>
            ''');
          } else if (path == '/s2/book/1') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="name">样例漫画B</h1>
              <span class="author">作者B</span>
              <p class="intro">B简介</p>
              <img class="cover" src="/covers/b.jpg" />
              <a class="toc" href="/s2/book/1/toc">目录</a>
            ''');
          } else if (path == '/s2/book/1/toc') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="chapter"><a class="link" href="/s2/book/1/ch1">第1话</a></div>
            ''');
          } else if (path == '/s2/book/1/ch1') {
            request.response
              ..statusCode = 200
              ..write('''
              {"images":["/images/b-1.jpg","https://cdn.example.com/b-2.png"]}
            ''');
          } else if (path == '/s3/search') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="book"><a class="title" href="/s3/book/1">样例漫画C</a><span class="author">作者C</span></div>
            ''');
          } else if (path == '/s3/book/1') {
            request.response
              ..statusCode = 200
              ..write('''
              <h1 class="name">样例漫画C</h1>
              <span class="author">作者C</span>
              <p class="intro">C简介</p>
              <img class="cover" src="/covers/c.jpg" />
              <a class="toc" href="/s3/book/1/toc">目录</a>
            ''');
          } else if (path == '/s3/book/1/toc') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="chapter"><a class="link" href="/s3/book/1/ch1">第1话</a></div>
            ''');
          } else if (path == '/s3/book/1/ch1') {
            request.response
              ..statusCode = 200
              ..write('''
              <div class="viewer"><p>loading...</p><img src="/images/c-1.jpg" /><img src="/images/c-2.webp" /></div>
            ''');
          } else {
            request.response
              ..statusCode = 404
              ..write('not found: $path');
          }

          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final payload = _readFixture().replaceAll('__BASE_URL__', baseUrl);
        final importService = SourceImportService();
        final importResult = importService.importFromText(payload);

        expect(importResult, isA<Success<List<SourceDefinition>>>());
        final sources = (importResult as Success<List<SourceDefinition>>).data;
        expect(sources, hasLength(3));
        expect(sources.every((source) => source.isMangaSource), isTrue);

        final repository = _FakeSourceRepository(
          List<SourceDefinition>.from(sources),
        );
        final searchService = SearchService(
          sourceRepository: repository,
          maxConcurrentSources: 2,
        );
        final detailService = BookDetailService(sourceRepository: repository);
        final contentService = ChapterContentService(
          sourceRepository: repository,
        );

        final searchReport = await searchService.search(
          keyword: '样例',
          contentMode: SearchContentMode.manga,
        );

        expect(searchReport.failures, isEmpty);
        expect(searchReport.books, hasLength(3));

        for (final book in searchReport.books) {
          final detail = await detailService.load(
            sourceId: book.sourceId,
            bookId: book.id,
            detailUrl: book.detailUrl,
            fallbackTitle: book.title,
          );
          expect(detail.chapters, isNotEmpty);

          final chapter = detail.chapters.first;
          final firstLoad = await contentService.load(
            sourceId: book.sourceId,
            chapterUrl: chapter.chapterUrl,
            bookId: book.id,
            chapterIndex: 0,
            chapterTitle: chapter.title,
          );

          expect(firstLoad.isImageContent, isTrue);
          expect(firstLoad.imageUrls, isNotEmpty);
          expect(firstLoad.fromCache, isFalse);

          final secondLoad = await contentService.load(
            sourceId: book.sourceId,
            chapterUrl: chapter.chapterUrl,
            bookId: book.id,
            chapterIndex: 0,
            chapterTitle: chapter.title,
          );

          expect(secondLoad.isImageContent, isTrue);
          expect(secondLoad.imageUrls, isNotEmpty);
          expect(secondLoad.fromCache, isTrue);
        }

        await server.close(force: true);
      },
    );
  });
}

String _readFixture() {
  return File('test/fixtures/manga_js_free_sources.json').readAsStringSync();
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
