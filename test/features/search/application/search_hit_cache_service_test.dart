import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_appread/features/search/application/search_hit_cache_service.dart';
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
  });
}
