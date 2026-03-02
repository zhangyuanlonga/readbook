import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase search source hits', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('upserts and accumulates source hit counts', () async {
      await database.upsertSearchSourceHits([
        const SearchSourceHitUpsert(
          titleNorm: '凡人修仙传',
          authorNorm: '忘语',
          sourceId: 's1',
          sourceName: '源1',
          title: '凡人修仙传',
          author: '忘语',
          latestChapter: '第10章',
          latestChapterNo: 10,
        ),
        const SearchSourceHitUpsert(
          titleNorm: '凡人修仙传',
          authorNorm: '忘语',
          sourceId: 's2',
          sourceName: '源2',
          title: '凡人修仙传',
          author: '忘语',
          latestChapter: '第11章',
          latestChapterNo: 11,
        ),
      ]);

      await database.upsertSearchSourceHits([
        const SearchSourceHitUpsert(
          titleNorm: '凡人修仙传',
          authorNorm: '忘语',
          sourceId: 's1',
          sourceName: '源1',
          title: '凡人修仙传',
          author: '忘语',
          latestChapter: '第12章',
          latestChapterNo: 12,
          hitIncrement: 2,
        ),
      ]);

      final counts = await database.getSearchSourceHitCounts(
        titleNorm: '凡人修仙传',
        authorNorm: '忘语',
      );
      expect(counts['s1'], 3);
      expect(counts['s2'], 1);
    });

    test('clears search source hits', () async {
      await database.upsertSearchSourceHits([
        const SearchSourceHitUpsert(
          titleNorm: '斗破苍穹',
          authorNorm: '天蚕土豆',
          sourceId: 's3',
          sourceName: '源3',
          title: '斗破苍穹',
          author: '天蚕土豆',
        ),
      ]);

      expect(
        await database.getSearchSourceHitCounts(
          titleNorm: '斗破苍穹',
          authorNorm: '天蚕土豆',
        ),
        isNotEmpty,
      );

      await database.clearSearchSourceHits();
      expect(
        await database.getSearchSourceHitCounts(
          titleNorm: '斗破苍穹',
          authorNorm: '天蚕土豆',
        ),
        isEmpty,
      );
    });
  });
}
