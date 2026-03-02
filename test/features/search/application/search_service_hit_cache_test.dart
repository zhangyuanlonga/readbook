import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/domain/entities/source_definition.dart';
import 'package:flutter_appread/domain/repositories/source_repository.dart';
import 'package:flutter_appread/features/search/application/search_hit_cache_service.dart';
import 'package:flutter_appread/features/search/application/search_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchService hit cache', () {
    test('persists source hits after search completed', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write('''
            <div class="item">
              <a class="title" href="/book/1">凡人修仙传</a>
              <span class="author">忘语</span>
            </div>
          ''');
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final database = AppDatabase(executor: NativeDatabase.memory());
      final hitCacheService = SearchHitCacheService(database: database);
      final service = SearchService(
        sourceRepository: _FakeSourceRepository([
          SourceDefinition(
            id: 's1',
            name: '源1',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              searchRule: '/search?key={{key}}',
              searchListRule: '.item@html',
              searchTitleRule: '.title@text',
              searchAuthorRule: '.author@text',
              searchDetailUrlRule: '.title@href',
            ),
          ),
        ]),
        searchHitCacheService: hitCacheService,
      );

      final report = await service.search(keyword: '凡人修仙传');
      expect(report.books, hasLength(1));

      final counts = await hitCacheService.loadSourceHitCounts(
        title: '凡人修仙传',
        author: '忘语',
      );
      expect(counts['s1'], 1);

      await database.close();
      await server.close(force: true);
    });

    test('does not fail search when hit cache persistence throws', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response
          ..statusCode = 200
          ..write(
            '<div class="item"><a class="title" href="/book/1">测试书</a></div>',
          );
        await request.response.close();
      });

      final baseUrl = 'http://${server.address.host}:${server.port}';
      final service = SearchService(
        sourceRepository: _FakeSourceRepository([
          SourceDefinition(
            id: 's1',
            name: '源1',
            baseUrl: baseUrl,
            rules: const SourceRuleSet(
              searchRule: '/search?key={{key}}',
              searchListRule: '.item@html',
              searchTitleRule: '.title@text',
              searchDetailUrlRule: '.title@href',
            ),
          ),
        ]),
        searchHitCacheService: _ThrowingSearchHitCacheService(),
      );

      final report = await service.search(keyword: '测试书');
      expect(report.books, hasLength(1));

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

class _ThrowingSearchHitCacheService extends SearchHitCacheService {
  _ThrowingSearchHitCacheService()
    : super(database: AppDatabase(executor: NativeDatabase.memory()));

  @override
  Future<void> recordBooks(
    Iterable<Book> books, {
    Map<String, String> sourceNames = const <String, String>{},
  }) {
    throw StateError('mock cache write failed');
  }
}
