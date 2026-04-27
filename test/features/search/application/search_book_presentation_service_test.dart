import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/data/datasources/local/app_database.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_metadata_override.dart';
import 'package:shuxiang_reading_next/features/search/application/search_book_presentation_service.dart';

void main() {
  test('resolves metadata override for search book presentation', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime.parse('2026-04-27T12:00:00.000Z');
    await database.upsertBookMetadataOverride(
      BookMetadataOverride.forRemote(
        sourceId: 'source_b',
        detailUrl: '/detail/2',
        title: '搜索覆盖标题',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final service = SearchBookPresentationService(database: database);

    final presentation = await service.resolve(
      const Book(
        id: 'book_2',
        sourceId: 'source_b',
        title: '原始标题',
        detailUrl: '/detail/2',
      ),
    );

    expect(presentation.displayTitle, '搜索覆盖标题');
  });
}
