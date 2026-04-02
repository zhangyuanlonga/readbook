import 'package:flutter_appread/features/reader/presentation/reader_route.dart';
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
}
