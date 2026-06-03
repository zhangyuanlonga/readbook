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
}
