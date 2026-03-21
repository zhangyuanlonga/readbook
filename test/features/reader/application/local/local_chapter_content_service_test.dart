import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_appread/data/datasources/local/app_database.dart';
import 'package:flutter_appread/data/repositories/local_book_repository_impl.dart';
import 'package:flutter_appread/domain/entities/local_book.dart';
import 'package:flutter_appread/features/reader/application/local/local_book_parser.dart';
import 'package:flutter_appread/features/reader/application/local/local_book_index_service.dart';
import 'package:flutter_appread/features/reader/application/local/local_chapter_content_service.dart';
import 'package:flutter_appread/features/reader/application/local/txt_local_book_parser.dart';
import 'package:flutter_appread/features/reader/application/local/txt_toc_rule_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalChapterContentService', () {
    late Directory tempDir;
    late AppDatabase database;
    late LocalBookRepositoryImpl repository;
    late LocalBookIndexService indexService;
    late LocalChapterContentService contentService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp(
        'local_chapter_content_service_test',
      );
      database = AppDatabase(executor: NativeDatabase.memory());
      repository = LocalBookRepositoryImpl(database);
      indexService = LocalBookIndexService(
        localBookRepository: repository,
        parsers: <LocalBookParser>[
          TxtLocalBookParser(ruleSettingsService: TxtTocRuleSettingsService()),
        ],
      );
      contentService = LocalChapterContentService(
        localBookRepository: repository,
        indexService: indexService,
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'loads txt chapter content from file offsets after indexing',
      () async {
        final file = File('${tempDir.path}/offset_book.txt');
        await file.writeAsString('''
第1章 开始
第一章内容。

第2章 继续
第二章内容。
''');

        final now = DateTime.parse('2026-03-21T12:00:00.000Z');
        await repository.upsertBook(
          LocalBook(
            id: 'local_offset_1',
            title: '偏移读取测试',
            format: LocalBookFormat.txt,
            storagePath: file.path,
            fileSize: await file.length(),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await indexService.ensureIndexed(bookId: 'local_offset_1');

        final metas = await repository.getChapters('local_offset_1');
        expect(metas, hasLength(2));
        expect(metas.first.content, isEmpty);
        expect(metas.first.startOffset, isNotNull);
        expect(metas.first.endOffset, isNotNull);

        final chapter = await contentService.load(
          bookId: 'local_offset_1',
          chapterIndex: 0,
        );
        expect(chapter.title, '第1章 开始');
        expect(chapter.content, contains('第一章内容'));
        expect(chapter.content, isNot(contains('第2章 继续')));
      },
    );
  });
}
