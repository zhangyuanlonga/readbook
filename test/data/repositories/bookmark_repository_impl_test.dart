import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/bookmark_repository_impl.dart';
import 'package:flutter_appread/domain/entities/bookmark.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookmarkRepositoryImpl', () {
    late AppDatabase database;
    late BookmarkRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = BookmarkRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('adds, lists and removes bookmarks', () async {
      final now = DateTime.parse('2026-03-14T08:00:00.000Z');
      final first = Bookmark(
        id: 'bm_1',
        bookId: 'book_1',
        chapterId: 'chapter_1',
        chapterIndex: 0,
        startOffset: 12,
        endOffset: 34,
        snippet: '第一段喜欢的句子。',
        createdAt: now,
        updatedAt: now,
        isBold: true,
        isUnderline: true,
        isWavy: true,
      );
      final second = Bookmark(
        id: 'bm_2',
        bookId: 'book_1',
        chapterId: 'chapter_2',
        chapterIndex: 1,
        startOffset: 5,
        endOffset: 18,
        snippet: '第二段喜欢的句子。',
        createdAt: now.add(const Duration(minutes: 5)),
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      final third = Bookmark(
        id: 'bm_3',
        bookId: 'book_2',
        chapterId: 'chapter_1',
        chapterIndex: 0,
        startOffset: 2,
        endOffset: 9,
        snippet: '另一本书的片段。',
        createdAt: now.add(const Duration(minutes: 10)),
        updatedAt: now.add(const Duration(minutes: 10)),
      );

      await repository.addBookmark(first);
      await repository.addBookmark(second);
      await repository.addBookmark(third);

      final items = await repository.listBookmarks('book_1');
      expect(items, hasLength(2));
      expect(items.first.id, 'bm_1');
      expect(items.first.isBold, isTrue);
      expect(items.first.isUnderline, isTrue);
      expect(items.first.isWavy, isTrue);
      expect(items.last.id, 'bm_2');

      final all = await repository.listAllBookmarks();
      expect(all, hasLength(3));

      await repository.removeBookmark('bm_1');
      final remaining = await repository.listBookmarks('book_1');
      expect(remaining, hasLength(1));
      expect(remaining.first.id, 'bm_2');
    });
  });
}
