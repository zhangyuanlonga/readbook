import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase chapter caches', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert, count and delete caches', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|u1',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u1',
        chapterTitle: 'c1',
        content: 'hello',
      );
      await database.upsertChapterCache(
        cacheKey: 's1|u2',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 1,
        chapterUrl: 'u2',
        chapterTitle: 'c2',
        content: 'world',
      );

      final cached = await database.getCachedChapterCount('book_1');
      expect(cached, 2);

      final summary = await database.listCachedBooks();
      expect(summary, hasLength(1));
      expect(summary.first.bookId, 'book_1');
      expect(summary.first.cachedCount, 2);

      await database.deleteChapterCachesByBookId('book_1');
      expect(await database.getCachedChapterCount('book_1'), 0);

      final total = await database.getTotalCachedChapterCount();
      expect(total, 0);
    });

    test('clear all caches', () async {
      await database.upsertChapterCache(
        cacheKey: 's1|u1',
        bookId: 'book_1',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u1',
        chapterTitle: 'c1',
        content: 'hello',
      );
      await database.upsertChapterCache(
        cacheKey: 's1|u2',
        bookId: 'book_2',
        sourceId: 's1',
        chapterIndex: 0,
        chapterUrl: 'u2',
        chapterTitle: 'c2',
        content: 'world',
      );

      expect(await database.getTotalCachedChapterCount(), 2);
      await database.clearChapterCaches();
      expect(await database.getTotalCachedChapterCount(), 0);
    });
  });
}
