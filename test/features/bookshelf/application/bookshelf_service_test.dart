import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/bookshelf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BookshelfService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('upsert inserts and contains returns true', () async {
      final service = BookshelfService();
      final book = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'src_1',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/detail/1',
        addedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
      );

      await service.upsert(book);

      final all = await service.getAll();
      expect(all, hasLength(1));
      expect(all.first.title, '凡人修仙传');

      final exists = await service.contains(
        sourceId: 'src_1',
        detailUrl: 'https://example.com/detail/1',
      );
      expect(exists, isTrue);
    });

    test('upsert same key replaces old item and keeps one record', () async {
      final service = BookshelfService();
      final first = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'src_1',
        title: '旧标题',
        detailUrl: 'https://example.com/detail/1',
        addedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
      );
      final second = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'src_1',
        title: '新标题',
        detailUrl: 'https://example.com/detail/1',
        addedAt: DateTime.parse('2026-02-12T12:00:01.000Z'),
      );

      await service.upsert(first);
      await service.upsert(second);

      final all = await service.getAll();
      expect(all, hasLength(1));
      expect(all.first.title, '新标题');
    });

    test('remove deletes item', () async {
      final service = BookshelfService();
      final book = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'src_1',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/detail/1',
        addedAt: DateTime.parse('2026-02-12T12:00:00.000Z'),
      );

      await service.upsert(book);
      await service.remove(
        sourceId: 'src_1',
        detailUrl: 'https://example.com/detail/1',
      );

      final all = await service.getAll();
      expect(all, isEmpty);
    });

    test('renameTag renames across books and deduplicates tags', () async {
      final service = BookshelfService();
      await service.setBookTags(
        sourceId: 'src_1',
        detailUrl: 'detail_1',
        tags: const ['在读', '收藏'],
      );
      await service.setBookTags(
        sourceId: 'src_2',
        detailUrl: 'detail_2',
        tags: const ['在读', '已读'],
      );
      await service.setBookTags(
        sourceId: 'src_3',
        detailUrl: 'detail_3',
        tags: const ['追更', '在读'],
      );

      final affectedCount = await service.renameTag(fromTag: '在读', toTag: '追更');
      expect(affectedCount, 3);

      final map = await service.getTagMap();
      expect(map['src_1::detail_1'], orderedEquals(const ['追更', '收藏']));
      expect(map['src_2::detail_2'], orderedEquals(const ['追更', '已读']));
      expect(map['src_3::detail_3'], orderedEquals(const ['追更']));
    });

    test('deleteTag removes target tag and clears empty book tags', () async {
      final service = BookshelfService();
      await service.setBookTags(
        sourceId: 'src_1',
        detailUrl: 'detail_1',
        tags: const ['在读'],
      );
      await service.setBookTags(
        sourceId: 'src_2',
        detailUrl: 'detail_2',
        tags: const ['在读', '收藏'],
      );

      final affectedCount = await service.deleteTag('在读');
      expect(affectedCount, 2);

      final map = await service.getTagMap();
      expect(map.containsKey('src_1::detail_1'), isFalse);
      expect(map['src_2::detail_2'], orderedEquals(const ['收藏']));
    });

    test(
      'replace swaps old entry and migrates tags to new source entry',
      () async {
        final service = BookshelfService();
        await service.upsert(
          BookshelfBook(
            bookId: 'book_old',
            sourceId: 'src_old',
            title: '旧书源',
            detailUrl: 'https://example.com/old',
            addedAt: DateTime.parse('2026-03-09T00:00:00.000Z'),
          ),
        );
        await service.setBookTags(
          sourceId: 'src_old',
          detailUrl: 'https://example.com/old',
          tags: const ['在读', '玄幻'],
        );

        await service.replace(
          previousSourceId: 'src_old',
          previousDetailUrl: 'https://example.com/old',
          nextBook: BookshelfBook(
            bookId: 'book_new',
            sourceId: 'src_new',
            title: '新书源',
            detailUrl: 'https://example.com/new',
            addedAt: DateTime.parse('2026-03-09T00:00:01.000Z'),
          ),
        );

        final all = await service.getAll();
        expect(all, hasLength(1));
        expect(all.first.sourceId, 'src_new');
        expect(all.first.detailUrl, 'https://example.com/new');

        final oldExists = await service.contains(
          sourceId: 'src_old',
          detailUrl: 'https://example.com/old',
        );
        final newExists = await service.contains(
          sourceId: 'src_new',
          detailUrl: 'https://example.com/new',
        );
        expect(oldExists, isFalse);
        expect(newExists, isTrue);

        final tagMap = await service.getTagMap();
        expect(tagMap['src_old::https://example.com/old'], isNull);
        expect(
          tagMap['src_new::https://example.com/new'],
          orderedEquals(const ['在读', '玄幻']),
        );
      },
    );
  });
}
