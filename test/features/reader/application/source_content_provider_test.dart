import 'package:flutter_appread/domain/entities/book_detail.dart';
import 'package:flutter_appread/domain/entities/chapter.dart';
import 'package:flutter_appread/features/book/application/book_detail_service.dart';
import 'package:flutter_appread/features/bookshelf/application/local_book_import_service.dart';
import 'package:flutter_appread/features/reader/application/chapter_content_service.dart';
import 'package:flutter_appread/features/reader/application/source_content_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBookDetailService extends BookDetailService {
  _FakeBookDetailService(this.result);

  final BookDetailLoadResult result;

  String? sourceId;
  String? bookId;
  String? detailUrl;
  String? fallbackTitle;
  String? fallbackAuthor;
  bool? forceRefresh;

  @override
  Future<BookDetailLoadResult> load({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
  }) async {
    this.sourceId = sourceId;
    this.bookId = bookId;
    this.detailUrl = detailUrl;
    this.fallbackTitle = fallbackTitle;
    this.fallbackAuthor = fallbackAuthor;
    this.forceRefresh = forceRefresh;
    return result;
  }
}

class _FakeChapterContentService extends ChapterContentService {
  _FakeChapterContentService(this.result);

  final ChapterContentResult result;

  String? sourceId;
  String? chapterUrl;
  String? bookId;
  int? chapterIndex;
  String? chapterTitle;
  String? nextChapterUrl;

  @override
  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  }) async {
    this.sourceId = sourceId;
    this.chapterUrl = chapterUrl;
    this.bookId = bookId;
    this.chapterIndex = chapterIndex;
    this.chapterTitle = chapterTitle;
    this.nextChapterUrl = nextChapterUrl;
    return result;
  }
}

void main() {
  test('supportsSourceId rejects local source id', () {
    final provider = SourceContentProvider();

    expect(provider.supportsSourceId(''), isFalse);
    expect(
      provider.supportsSourceId(LocalBookImportService.localBookSourceId),
      isFalse,
    );
    expect(provider.supportsSourceId('source_a'), isTrue);
  });

  test('delegates detail and content loading', () async {
    const detail = BookDetail(
      id: 'book_1',
      sourceId: 'source_a',
      title: '示例书籍',
      detailUrl: 'https://example.com/book/1',
      author: '作者',
    );
    const chapters = <Chapter>[
      Chapter(
        id: 'chapter_1',
        bookId: 'book_1',
        title: '第一章',
        chapterUrl: 'https://example.com/book/1/c1',
        index: 0,
      ),
    ];

    const detailResult = BookDetailLoadResult(
      detail: detail,
      chapters: chapters,
      sourceName: '源A',
      tocFromCache: false,
    );
    const contentResult = ChapterContentResult(
      content: '正文内容',
      fromCache: false,
    );

    final fakeDetailService = _FakeBookDetailService(detailResult);
    final fakeContentService = _FakeChapterContentService(contentResult);

    final provider = SourceContentProvider(
      detailService: fakeDetailService,
      contentService: fakeContentService,
    );

    final loadedDetail = await provider.loadDetail(
      sourceId: 'source_a',
      bookId: 'book_1',
      detailUrl: 'https://example.com/book/1',
      fallbackTitle: '兜底标题',
      fallbackAuthor: '兜底作者',
      forceRefresh: true,
    );

    expect(loadedDetail, same(detailResult));
    expect(fakeDetailService.sourceId, 'source_a');
    expect(fakeDetailService.bookId, 'book_1');
    expect(fakeDetailService.detailUrl, 'https://example.com/book/1');
    expect(fakeDetailService.fallbackTitle, '兜底标题');
    expect(fakeDetailService.fallbackAuthor, '兜底作者');
    expect(fakeDetailService.forceRefresh, isTrue);

    final loadedContent = await provider.loadChapterContent(
      sourceId: 'source_a',
      bookId: 'book_1',
      chapterUrl: 'https://example.com/book/1/c1',
      chapterIndex: 0,
      chapterTitle: '第一章',
      nextChapterUrl: 'https://example.com/book/1/c2',
    );

    expect(loadedContent, same(contentResult));
    expect(fakeContentService.sourceId, 'source_a');
    expect(fakeContentService.bookId, 'book_1');
    expect(fakeContentService.chapterUrl, 'https://example.com/book/1/c1');
    expect(fakeContentService.chapterIndex, 0);
    expect(fakeContentService.chapterTitle, '第一章');
    expect(fakeContentService.nextChapterUrl, 'https://example.com/book/1/c2');
  });
}
