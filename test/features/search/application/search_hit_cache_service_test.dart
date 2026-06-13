import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:shuxiang_reading_next/core/cache/app_cache_coordinator.dart';
import 'package:shuxiang_reading_next/core/cache/cache_entry.dart';
import 'package:shuxiang_reading_next/core/cache/cache_policy.dart';
import 'package:shuxiang_reading_next/core/cache/cache_result.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/features/search/application/search_hit_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchHitCacheService', () {
    late AppDatabase database;
    late SearchHitCacheService service;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      service = SearchHitCacheService(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test('records books and returns hit counts by source', () async {
      await service.recordBooks(const <Book>[
        Book(
          id: 'b1',
          sourceId: 's1',
          title: '凡人修仙传',
          detailUrl: '/a',
          author: '忘语',
          latestChapter: '第100章',
        ),
        Book(
          id: 'b2',
          sourceId: 's2',
          title: '凡人修仙传',
          detailUrl: '/b',
          author: '忘语',
          latestChapter: '第98章',
        ),
        Book(
          id: 'b3',
          sourceId: 's1',
          title: '凡人修仙传',
          detailUrl: '/c',
          author: '忘语',
          latestChapter: '第101章',
        ),
      ]);

      await service.recordBooks(const <Book>[
        Book(
          id: 'b4',
          sourceId: 's3',
          title: '凡人 修仙传',
          detailUrl: '/d',
          author: '忘语',
          latestChapter: '第102章',
        ),
      ]);

      final counts = await service.loadSourceHitCounts(
        title: '凡人修仙传',
        author: '忘语',
      );
      expect(counts['s1'], 2);
      expect(counts['s2'], 1);
      expect(counts['s3'], 1);
    });

    test('returns empty when title is blank', () async {
      final counts = await service.loadSourceHitCounts(
        title: '  ',
        author: '忘语',
      );
      expect(counts, isEmpty);
    });

    test('reads cached hit counts through AppCacheStore', () async {
      await service.recordBooks(const <Book>[
        Book(
          id: 'b1',
          sourceId: 's1',
          title: '凡人修仙传',
          detailUrl: '/a',
          author: '忘语',
          latestChapter: '第100章',
        ),
        Book(
          id: 'b2',
          sourceId: 's2',
          title: '凡人修仙传',
          detailUrl: '/b',
          author: '忘语',
          latestChapter: '第99章',
        ),
      ]);
      final key = SearchHitCacheService.keyBuilder.build(
        userId: 'user_1',
        titleNorm: service.normalizeText('凡人修仙传'),
        authorNorm: service.normalizeText('忘语'),
      );

      final result = await service.read(
        key,
        policy: AppCachePolicies.searchHit,
      );

      expect(result.status, AppCacheReadStatus.hit);
      expect(result.entry?.payload, <String, int>{'s1': 1, 's2': 1});
      expect(result.entry?.metadata['titleNorm'], '凡人修仙传');
    });

    test('returns stale when search hits exceed TTL', () async {
      await service.recordBooks(const <Book>[
        Book(
          id: 'b1',
          sourceId: 's1',
          title: '凡人修仙传',
          detailUrl: '/a',
          author: '忘语',
        ),
      ]);
      final staleAt = DateTime.now().subtract(const Duration(days: 8));
      await (database.update(database.searchSourceHits)
        ..where((table) => table.sourceId.equals('s1'))).write(
        SearchSourceHitsCompanion(
          createdAt: Value(staleAt),
          updatedAt: Value(staleAt),
          lastHitAt: Value(staleAt),
        ),
      );
      final key = SearchHitCacheService.keyBuilder.build(
        userId: 'user_1',
        titleNorm: service.normalizeText('凡人修仙传'),
        authorNorm: service.normalizeText('忘语'),
      );

      final result = await service.read(
        key,
        policy: AppCachePolicies.searchHit,
      );

      expect(result.status, AppCacheReadStatus.stale);
      expect(result.invalidReason, AppCacheInvalidReason.ttlExpired);
    });

    test('writes deletes stats and prunes through AppCacheStore', () async {
      final key = SearchHitCacheService.keyBuilder.build(
        userId: 'user_1',
        titleNorm: service.normalizeText('凡人修仙传'),
        authorNorm: service.normalizeText('忘语'),
        sourceId: 's1',
      );

      final writeResult = await service.write(
        AppCacheEntry(
          key: key,
          payload: SearchSourceHitUpsert(
            titleNorm: service.normalizeText('凡人修仙传'),
            authorNorm: service.normalizeText('忘语'),
            sourceId: 's1',
            sourceName: '书源一',
            title: '凡人修仙传',
            author: '忘语',
            hitIncrement: 2,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ),
        policy: AppCachePolicies.searchHit,
      );

      expect(writeResult.status, AppCacheWriteStatus.written);
      expect((await service.stats()).entries, 1);
      expect((await service.read(key)).entry?.payload, 2);

      final deleted = await service.delete(key);
      expect(deleted.deletedEntries, 1);
      expect((await service.read(key)).status, AppCacheReadStatus.miss);

      await service.recordBooks(const <Book>[
        Book(id: 'b1', sourceId: 's1', title: '书一', detailUrl: '/1'),
        Book(id: 'b2', sourceId: 's2', title: '书二', detailUrl: '/2'),
      ]);
      final pruneResult = await service.prune(
        const AppCachePolicy(maxEntries: 1, maxBytes: 1024),
      );
      expect(pruneResult.deletedEntries, 1);
      expect((await service.stats()).entries, 1);

      final clearResult = await service.clearScope(owner: 'user_1');
      expect(clearResult.deletedEntries, 1);
      expect((await service.stats()).entries, 0);
    });

    test('clears user scoped search hits on account switch', () async {
      await service.recordBooks(const <Book>[
        Book(
          id: 'b1',
          sourceId: 's1',
          title: '凡人修仙传',
          detailUrl: '/a',
          author: '忘语',
        ),
      ]);
      final coordinator = AppCacheCoordinator(stores: [service]);
      final key = SearchHitCacheService.keyBuilder.build(
        userId: 'user_2',
        titleNorm: service.normalizeText('凡人修仙传'),
        authorNorm: service.normalizeText('忘语'),
      );

      await coordinator.clearUserScoped(owner: 'user_1');
      final result = await coordinator.read(key);

      expect(result.status, AppCacheReadStatus.miss);
      expect((await service.stats()).entries, 0);
    });
  });
}
