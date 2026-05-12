import 'package:drift/native.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/local_book.dart';
import 'package:shuxiang_reading_next/domain/entities/local_chapter.dart';
import 'package:shuxiang_reading_next/domain/entities/reader_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase local books', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('upsert, query and update local book index state', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await database.upsertLocalBook(
        LocalBook(
          id: 'local_1',
          title: '本地测试书',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/local_1.txt',
          sourcePath: '/input/book.txt',
          fileSize: 1024,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await database.getLocalBookById('local_1');
      expect(loaded, isNotNull);
      expect(loaded!.title, '本地测试书');
      expect(loaded.charset, isNull);
      expect(loaded.description, isNull);
      expect(loaded.indexStatus, LocalBookIndexStatus.pending);

      await database.updateLocalBookIndexState(
        bookId: 'local_1',
        status: LocalBookIndexStatus.ready,
        chapterCount: 18,
      );

      final updated = await database.getLocalBookById('local_1');
      expect(updated, isNotNull);
      expect(updated!.indexStatus, LocalBookIndexStatus.ready);
      expect(updated.chapterCount, 18);
    });

    test('persists charset, description and file metadata fields', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await database.upsertLocalBook(
        LocalBook(
          id: 'local_meta_1',
          title: '元数据测试书',
          format: LocalBookFormat.txt,
          storagePath: '/tmp/local_meta_1.txt',
          sourcePath: '/input/meta.txt',
          charset: 'gbk',
          description: '这是一段本地图书简介。',
          fileSize: 2048,
          sourceFileSize: 4096,
          sourceFileLastModifiedMs: 123456789,
          storageFileLastModifiedMs: 987654321,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final loaded = await database.getLocalBookById('local_meta_1');
      expect(loaded, isNotNull);
      expect(loaded!.charset, 'gbk');
      expect(loaded.description, '这是一段本地图书简介。');
      expect(loaded.sourceFileSize, 4096);
      expect(loaded.sourceFileLastModifiedMs, 123456789);
      expect(loaded.storageFileLastModifiedMs, 987654321);
    });

    test('replace chapters and delete local book', () async {
      final now = DateTime.parse('2026-02-23T12:00:00.000Z');
      await database.upsertLocalBook(
        LocalBook(
          id: 'local_2',
          title: '本地章节书',
          format: LocalBookFormat.epub,
          storagePath: '/tmp/local_2.epub',
          fileSize: 2048,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.replaceLocalChapters(
        bookId: 'local_2',
        chapters: [
          LocalChapter(
            id: 'c_1',
            bookId: 'local_2',
            chapterIndex: 0,
            title: '第一章',
            content: '第一章内容',
            createdAt: now,
            updatedAt: now,
            startOffset: 0,
            endOffset: 100,
          ),
          LocalChapter(
            id: 'c_2',
            bookId: 'local_2',
            chapterIndex: 1,
            title: '第二章',
            content: '第二章内容',
            imageUrls: const ['file:///tmp/image_2.png'],
            sourceRef: 'OPS/chapter2.xhtml',
            createdAt: now,
            updatedAt: now,
            startOffset: 101,
            endOffset: 200,
            document: ReaderDocument(
              blocks: const <ReaderBlock>[
                ReaderTextBlock(text: '第二章内容'),
                ReaderImageBlock(imageUrl: 'file:///tmp/image_2.png'),
              ],
            ),
          ),
        ],
      );

      final chapters = await database.getLocalChapters('local_2');
      expect(chapters, hasLength(2));
      expect(chapters.first.title, '第一章');

      final chapter = await database.getLocalChapterById('c_2');
      expect(chapter, isNotNull);
      expect(chapter!.chapterIndex, 1);
      expect(chapter.imageUrls, contains('file:///tmp/image_2.png'));
      expect(chapter.sourceRef, 'OPS/chapter2.xhtml');
      expect(chapter.document, isNotNull);
      expect(chapter.document!.blocks.last, isA<ReaderImageBlock>());

      final chapterMeta = await database.getLocalChapterMetaByIndex(
        bookId: 'local_2',
        chapterIndex: 1,
      );
      expect(chapterMeta, isNotNull);
      expect(chapterMeta!.title, '第二章');
      expect(chapterMeta.content, isEmpty);
      expect(chapterMeta.document, isNull);
      expect(chapterMeta.sourceRef, 'OPS/chapter2.xhtml');

      final book = await database.getLocalBookById('local_2');
      expect(book, isNotNull);
      expect(book!.chapterCount, 2);

      await database.deleteLocalBook('local_2');
      expect(await database.getLocalBookById('local_2'), isNull);
      expect(await database.getLocalChapters('local_2'), isEmpty);
    });
  });
}
