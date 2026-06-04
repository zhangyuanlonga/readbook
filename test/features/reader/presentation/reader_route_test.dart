import 'package:shuxiang_reading_next/features/reader/presentation/reader_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildReaderRoute encodes path parameters that contain url fragments', () {
    final route = buildReaderRoute(
      bookId:
          'bc0c9dda-20c4-4f6e-afa0-da90972f4a4b:https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1143014772',
      chapterId:
          'bc0c9dda-20c4-4f6e-afa0-da90972f4a4b:https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1143014772:https://novel.html5.qq.com/be-api/content/ads-read?bookId=1143014772&chapterSeqNo=1',
      chapterUrl:
          'https://novel.html5.qq.com/be-api/content/ads-read?bookId=1143014772&chapterSeqNo=1',
      chapterTitle: '第1章 归零',
      sourceId: 'bc0c9dda-20c4-4f6e-afa0-da90972f4a4b',
      detailUrl:
          'https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1143014772',
      chapterIndex: 0,
    );

    final uri = Uri.parse(route);

    expect(uri.pathSegments, hasLength(3));
    expect(uri.pathSegments.first, 'reader');
    expect(
      uri.pathSegments[1],
      'bc0c9dda-20c4-4f6e-afa0-da90972f4a4b:https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1143014772',
    );
    expect(
      uri.pathSegments[2],
      'bc0c9dda-20c4-4f6e-afa0-da90972f4a4b:https://bookshelf.html5.qq.com/qbread/api/novel/intro-info?bookid=1143014772:https://novel.html5.qq.com/be-api/content/ads-read?bookId=1143014772&chapterSeqNo=1',
    );
    expect(
      uri.queryParameters['chapterUrl'],
      'https://novel.html5.qq.com/be-api/content/ads-read?bookId=1143014772&chapterSeqNo=1',
    );
    expect(uri.queryParameters['chapterIndex'], '0');
  });

  test('buildReaderRoute roundtrips full reader restore query data', () {
    final route = buildReaderRoute(
      bookId: 'book-1',
      chapterId: 'chapter-2',
      sourceId: 'source-web',
      detailUrl: 'https://example.com/detail?id=1&from=book',
      chapterUrl: 'https://example.com/read?chapter=2&token=a',
      chapterTitle: '第二章 桌面与 Web 刷新',
      chapterIndex: 2,
      bookmarkId: 'bookmark-1',
      openRequestedAtMs: 1770000000123,
      openRouteKind: 'continue_reading',
      heroTag: 'hero:book-1',
    );

    final restored = ReaderRouteData.fromUri(Uri.parse(route));

    expect(restored.bookId, 'book-1');
    expect(restored.chapterId, 'chapter-2');
    expect(restored.sourceId, 'source-web');
    expect(restored.detailUrl, 'https://example.com/detail?id=1&from=book');
    expect(restored.chapterUrl, 'https://example.com/read?chapter=2&token=a');
    expect(restored.chapterTitle, '第二章 桌面与 Web 刷新');
    expect(restored.chapterIndex, 2);
    expect(restored.bookmarkId, 'bookmark-1');
    expect(restored.openRequestedAtMs, 1770000000123);
    expect(restored.openRouteKind, 'continue_reading');
    expect(restored.heroTag, 'hero:book-1');
    expect(restored.location, route);
  });

  test('falls back to stable unknown reader path for empty ids', () {
    final route = buildReaderRoute(bookId: ' ', chapterId: ' ');

    expect(route, '/reader/unknown-book/unknown-chapter');
    final restored = ReaderRouteData.fromUri(Uri.parse(route));
    expect(restored.bookId, 'unknown-book');
    expect(restored.chapterId, 'unknown-chapter');
  });
}
