import 'dart:convert';
import 'dart:io';

import 'package:flutter_appread/data/adapters/legado_source_adapter.dart';
import 'package:flutter_appread/data/models/legado_source_raw.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Legacy source compatibility fixtures', () {
    final manifest =
        jsonDecode(
              File(
                'test/fixtures/compatibility/legacy_sources_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final cases = (manifest['cases'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

    const adapter = LegadoSourceAdapter();

    for (final item in cases) {
      final caseId = item['id']?.toString() ?? 'unknown';
      final description = item['description']?.toString() ?? caseId;

      test('runs fixture case: $description', () async {
        final sourceRaw = LegadoSourceRaw.fromJson(
          Map<String, dynamic>.from(item['source'] as Map),
        );
        final fixtures = Map<String, dynamic>.from(item['fixtures'] as Map);
        final expectMap = Map<String, dynamic>.from(item['expect'] as Map);

        final searchPayload =
            File(fixtures['search'].toString()).readAsStringSync();
        final detailPayload =
            File(fixtures['detail'].toString()).readAsStringSync();
        final tocPayload = File(fixtures['toc'].toString()).readAsStringSync();
        final contentPayload =
            File(fixtures['content'].toString()).readAsStringSync();

        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          switch (request.uri.path) {
            case '/api-search':
              request.response
                ..statusCode = 200
                ..write(searchPayload);
              break;
            case '/api-info-13148-35':
              request.response
                ..statusCode = 200
                ..write(detailPayload);
              break;
            case '/api-chapterlist-13148-35':
              request.response
                ..statusCode = 200
                ..write(tocPayload);
              break;
            case '/api-chapter-13148-35-10196648':
            case '/api-chapter-13148-35-10196649':
              request.response
                ..statusCode = 200
                ..write(contentPayload);
              break;
            default:
              request.response
                ..statusCode = 404
                ..write('not found');
              break;
          }

          await request.response.close();
        });

        final baseUrl = 'http://${server.address.host}:${server.port}';
        final adapted = adapter.adapt(sourceRaw);
        final normalizedHeaders = <String, String>{...adapted.headers};
        normalizedHeaders.update(
          'origin',
          (_) => baseUrl,
          ifAbsent: () => baseUrl,
        );
        normalizedHeaders.update(
          'referer',
          (_) => '$baseUrl/',
          ifAbsent: () => '$baseUrl/',
        );

        final source = adapted.copyWith(
          baseUrl: baseUrl,
          headers: normalizedHeaders,
        );
        final repository = _FixtureSourceRepository([source]);

        final searchService = SearchService(sourceRepository: repository);
        final searchReport = await searchService.search(keyword: '校园');
        expect(searchReport.failures, isEmpty);
        expect(searchReport.books, isNotEmpty);

        final detailService = BookDetailService(sourceRepository: repository);
        final detail = await detailService.load(
          sourceId: source.id,
          bookId: '${caseId}_book_1',
          detailUrl: '$baseUrl/api-info-13148-35',
        );

        expect(detail.detail.title, expectMap['detailTitle']);
        expect(detail.detail.author, expectMap['author']);
        expect(detail.detail.coverUrl, contains(expectMap['coverContains']));
        expect(detail.chapters, isNotEmpty);
        expect(detail.chapters.first.title, expectMap['firstChapterTitle']);
        expect(
          detail.chapters.first.chapterUrl,
          endsWith(expectMap['firstChapterUrlSuffix'].toString()),
        );

        final contentService = ChapterContentService(
          sourceRepository: repository,
        );
        final contentResult = await contentService.load(
          sourceId: source.id,
          chapterUrl: detail.chapters.first.chapterUrl,
        );

        for (final snippet in (expectMap['contentContains'] as List<dynamic>)) {
          expect(contentResult.content, contains(snippet.toString()));
        }

        await server.close(force: true);
      });
    }
  });
}

class _FixtureSourceRepository implements SourceRepository {
  _FixtureSourceRepository(this._items);

  final List<SourceDefinition> _items;

  @override
  Future<void> clear() async {
    _items.clear();
  }

  @override
  Future<void> deleteById(String sourceId) async {
    _items.removeWhere((item) => item.id == sourceId);
  }

  @override
  Future<void> deleteByIds(List<String> sourceIds) async {
    final sourceIdSet = sourceIds.toSet();
    _items.removeWhere((item) => sourceIdSet.contains(item.id));
  }

  @override
  Future<List<SourceDefinition>> getAll() async {
    return List.unmodifiable(_items);
  }

  @override
  Future<void> setEnabled({
    required String sourceId,
    required bool enabled,
  }) async {
    final index = _items.indexWhere((item) => item.id == sourceId);
    if (index < 0) {
      return;
    }

    _items[index] = _items[index].copyWith(enabled: enabled);
  }

  @override
  Future<void> upsertAll(List<SourceDefinition> items) async {
    for (final item in items) {
      final index = _items.indexWhere((source) => source.id == item.id);
      if (index >= 0) {
        _items[index] = item;
      } else {
        _items.add(item);
      }
    }
  }

  @override
  Stream<List<SourceDefinition>> watchAll() {
    return Stream.value(List.unmodifiable(_items));
  }
}
