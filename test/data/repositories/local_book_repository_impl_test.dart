import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/local_book_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalBookRepositoryImpl', () {
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('upserts and queries local books', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_r_1',
          title: '仓储测试',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/local_r_1.txt',
          fileSize: 123,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final all = await repository.getAllBooks();
      expect(all, hasLength(1));
      expect(all.first.id, 'local_r_1');

      final loaded = await repository.getBookById('local_r_1');
      expect(loaded, isNotNull);
      expect(loaded!.title, '仓储测试');
    });

    test('replaces chapters and supports chapter query', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await repository.upsertBook(
        LocalBook(
          id: 'local_r_2',
          title: '章节仓储测试',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/local_r_2.txt',
          fileSize: 456,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.replaceChapters(
        bookId: 'local_r_2',
        chapters: [
          LocalChapter(
            id: 'local_r_2_c1',
            bookId: 'local_r_2',
            chapterIndex: 0,
            title: '第一章',
            content: '章节内容1',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final chapters = await repository.getChapters('local_r_2');
      expect(chapters, hasLength(1));
      expect(chapters.first.id, 'local_r_2_c1');

      final chapter = await repository.getChapterById('local_r_2_c1');
      expect(chapter, isNotNull);
      expect(chapter!.title, '第一章');

      final chapterMeta = await repository.getChapterMetaByIndex(
        'local_r_2',
        0,
      );
      expect(chapterMeta, isNotNull);
      expect(chapterMeta!.title, '第一章');
      expect(chapterMeta.content, isEmpty);

      await repository.deleteBook('local_r_2');
      expect(await repository.getBookById('local_r_2'), isNull);
      expect(await repository.getChapters('local_r_2'), isEmpty);
    });
  });
}
