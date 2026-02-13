import 'package:flutter_appread/domain/entities/bookshelf_book.dart';
import 'package:flutter_appread/features/bookshelf/application/bookshelf_service.dart';
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
  });
}
