import 'package:flutter_test/flutter_test.dart';
import 'package:shuxiang_reading_next/features/book/presentation/book_detail_route.dart';

void main() {
  test('buildBookDetailRoute roundtrips complex query parameters', () {
    final location = buildBookDetailRoute(
      bookId: 'book:https://example.com/detail?id=1',
      sourceId: 'source_a',
      detailUrl: 'https://example.com/detail?id=1',
      title: '测试书籍',
      author: '作者甲',
      coverUrl: 'https://example.com/cover.jpg',
      heroTag: 'hero:1',
      titleHeroTag: 'title:1',
      metaHeroTag: 'meta:1',
      revealTransition: true,
    );

    final route = BookDetailRouteData.fromUri(Uri.parse(location));

    expect(route.bookId, 'book:https://example.com/detail?id=1');
    expect(route.detailUrl, 'https://example.com/detail?id=1');
    expect(route.title, '测试书籍');
    expect(route.author, '作者甲');
    expect(route.revealTransition, isTrue);
    expect(route.location, location);
  });

  test('supports browser refresh without route extra by preserving query data', () {
    final location = buildBookDetailRoute(
      bookId: 'book_1',
      sourceId: 'source_web',
      detailUrl: 'https://example.com/detail?id=1&from=search',
      title: '刷新恢复测试',
      author: '作者乙',
      coverUrl: 'https://example.com/cover.png',
    );

    final restored = BookDetailRouteData.fromUri(Uri.parse(location));

    expect(restored.bookId, 'book_1');
    expect(restored.sourceId, 'source_web');
    expect(restored.detailUrl, 'https://example.com/detail?id=1&from=search');
    expect(restored.title, '刷新恢复测试');
    expect(restored.author, '作者乙');
    expect(restored.coverUrl, 'https://example.com/cover.png');
  });

  test('falls back to stable unknown book path for empty book id', () {
    final location = buildBookDetailRoute(bookId: ' ');

    expect(location, '/book/unknown-book');
    expect(BookDetailRouteData.fromUri(Uri.parse(location)).bookId, 'unknown-book');
  });
}
