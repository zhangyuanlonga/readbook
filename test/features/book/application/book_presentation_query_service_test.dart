import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/data/repositories/book_metadata_override_repository_impl.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/book/application/book_presentation_query_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';

void main() {
  test('resolves metadata override for remote book presentation', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.parse('2026-04-27T12:00:00.000Z');
    await database.upsertBookMetadataOverride(
      BookMetadataOverride.forRemote(
        sourceId: 'source_a',
        detailUrl: '/detail/1',
        title: '覆盖标题',
        author: '覆盖作者',
        intro: '覆盖简介',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final service = BookPresentationQueryService(
      bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
        database,
      ),
    );

    final presentation = await service.resolveRemoteBook(
      const Book(
        id: 'book_1',
        sourceId: 'source_a',
        title: '原始标题',
        detailUrl: '/detail/1',
        author: '原始作者',
        intro: '原始简介',
      ),
    );

    expect(presentation.displayTitle, '覆盖标题');
    expect(presentation.displayAuthor, '覆盖作者');
    expect(presentation.displayIntro, '覆盖简介');
  });

  test(
    'loads metadata override map for local and remote bookshelf books',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.parse('2026-04-27T12:00:00.000Z');
      await database.upsertBookMetadataOverride(
        BookMetadataOverride.forRemote(
          sourceId: 'remote_source',
          detailUrl: '/detail/remote',
          title: '远程覆盖',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await database.upsertBookMetadataOverride(
        BookMetadataOverride.forLocal(
          bookId: 'local_book_1',
          title: '本地覆盖',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final service = BookPresentationQueryService(
        bookMetadataOverrideRepository: BookMetadataOverrideRepositoryImpl(
          database,
        ),
      );

      final result = await service
          .loadMetadataOverrideMapForBooks(<BookshelfBook>[
            BookshelfBook(
              bookId: 'remote_book_1',
              sourceId: 'remote_source',
              detailUrl: '/detail/remote',
              title: '远程书籍',
              addedAt: now,
            ),
            BookshelfBook(
              bookId: 'local_book_1',
              sourceId: LocalBookImportService.localBookSourceId,
              detailUrl: 'local://book/local_book_1',
              title: '本地图书',
              addedAt: now,
            ),
          ]);

      expect(
        result[BookMetadataOverride.remoteTargetKey(
              sourceId: 'remote_source',
              detailUrl: '/detail/remote',
            )]
            ?.title,
        '远程覆盖',
      );
      expect(
        result[BookMetadataOverride.localTargetKey('local_book_1')]?.title,
        '本地覆盖',
      );
    },
  );
}
