import 'package:flutter_appread/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Book', () {
    test('supports toJson and fromJson', () {
      const book = Book(
        id: 'book_1',
        sourceId: 'source-a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
        author: '忘语',
        intro: '简介',
        coverUrl: 'https://example.com/cover/1.jpg',
        latestChapter: '第100章',
      );

      final restored = Book.fromJson(book.toJson());

      expect(restored.id, book.id);
      expect(restored.sourceId, book.sourceId);
      expect(restored.title, book.title);
      expect(restored.detailUrl, book.detailUrl);
      expect(restored.author, book.author);
      expect(restored.latestChapter, book.latestChapter);
    });

    test('copyWith can clear optional fields', () {
      const book = Book(
        id: 'book_1',
        sourceId: 'source-a',
        title: '凡人修仙传',
        detailUrl: 'https://example.com/book/1',
        author: '忘语',
        intro: '简介',
      );

      final updated = book.copyWith(
        title: '诛仙',
        clearAuthor: true,
        clearIntro: true,
      );

      expect(updated.title, '诛仙');
      expect(updated.author, isNull);
      expect(updated.intro, isNull);
      expect(updated.detailUrl, book.detailUrl);
    });
  });
}
