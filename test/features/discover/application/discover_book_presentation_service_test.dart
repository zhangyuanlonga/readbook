import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/features/discover/application/discover_book_presentation_service.dart';

void main() {
  test('resolves metadata override for discover book presentation', () async {
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
    final service = DiscoverBookPresentationService(database: database);

    final presentation = await service.resolvePresentedBook(
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
}
