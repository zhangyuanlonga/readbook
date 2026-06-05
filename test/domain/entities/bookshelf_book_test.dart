import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/domain/entities/bookshelf_book.dart';

void main() {
  group('BookshelfBook', () {
    test('supports toJson and fromJson roundtrip', () {
      final book = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'source_a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
        addedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        author: '忘语',
        category: '仙侠',
        coverUrl: 'https://example.com/cover.jpg',
        latestChapter: '第100章',
        inReadingQueue: true,
      );

      final restored = BookshelfBook.fromJson(book.toJson());

      expect(restored.bookId, book.bookId);
      expect(restored.sourceId, book.sourceId);
      expect(restored.title, book.title);
      expect(restored.detailUrl, book.detailUrl);
      expect(restored.author, '忘语');
      expect(restored.category, '仙侠');
      expect(restored.latestChapter, '第100章');
      expect(restored.inReadingQueue, isTrue);
    });

    test('copyWith can clear nullable fields', () {
      final book = BookshelfBook(
        bookId: 'book_1',
        sourceId: 'source_a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
        addedAt: DateTime.parse('2026-06-03T12:00:00.000Z'),
        author: '忘语',
        category: '仙侠',
        coverUrl: 'https://example.com/cover.jpg',
        latestChapter: '第100章',
      );

      final updated = book.copyWith(
        author: null,
        clearAuthor: true,
        category: null,
        clearCategory: true,
        coverUrl: null,
        clearCoverUrl: true,
        latestChapter: null,
        clearLatestChapter: true,
      );

      expect(updated.author, isNull);
      expect(updated.category, isNull);
      expect(updated.coverUrl, isNull);
      expect(updated.latestChapter, isNull);
      expect(updated.inReadingQueue, isFalse);
    });
  });
}
