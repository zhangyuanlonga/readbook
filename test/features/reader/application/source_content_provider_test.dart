import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/domain/entities/chapter.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/bookshelf/application/local_book_import_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/chapter_content_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/source_content_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBookDetailService extends BookDetailService {
  _FakeBookDetailService(this.result);

  final BookDetailLoadResult result;
  BookDetailLoadResult? cachedResult;

  String? sourceId;
  String? bookId;
  String? detailUrl;
  String? fallbackTitle;
  String? fallbackAuthor;
  Book? initialBook;
  bool? forceRefresh;
  bool? includeCatalog;

  @override
  Future<BookDetailLoadResult> load({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    Book? initialBook,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  }) async {
    this.sourceId = sourceId;
    this.bookId = bookId;
    this.detailUrl = detailUrl;
    this.initialBook = initialBook;
    this.fallbackTitle = fallbackTitle;
    this.fallbackAuthor = fallbackAuthor;
    this.forceRefresh = forceRefresh;
    this.includeCatalog = includeCatalog;
    return result;
  }

  @override
  BookDetailLoadResult? peekCached({
    required String sourceId,
    required String detailUrl,
  }) {
    return cachedResult;
  }
}

class _FakeChapterContentService extends ChapterContentService {
  _FakeChapterContentService(this.result);

  final ChapterContentResult result;

  String? sourceId;
  String? chapterUrl;
  String? bookId;
  String? bookTitle;
  String? detailUrl;
  int? chapterIndex;
  String? chapterTitle;
  String? nextChapterUrl;
  String? executionContext;

  @override
  Future<ChapterContentResult> load({
    required String sourceId,
    required String chapterUrl,
    String? bookId,
    String? bookTitle,
    String? detailUrl,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
    String? executionContext,
  }) async {
    this.sourceId = sourceId;
    this.chapterUrl = chapterUrl;
    this.bookId = bookId;
    this.bookTitle = bookTitle;
    this.detailUrl = detailUrl;
    this.chapterIndex = chapterIndex;
    this.chapterTitle = chapterTitle;
    this.nextChapterUrl = nextChapterUrl;
    this.executionContext = executionContext;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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
    final contentResult = ChapterContentResult(
      content: '正文内容',
      fromCache: false,
      contentType: 'audio',
      audioUrl: 'https://cdn.example/chapter-1.mp3',
    );

    final fakeDetailService = _FakeBookDetailService(detailResult);
    final fakeContentService = _FakeChapterContentService(contentResult);

    final provider = SourceContentProvider(
      detailService: fakeDetailService,
      contentService: fakeContentService,
    );
    const initialBook = Book(
      id: 'book_1',
      sourceId: 'source_a',
      title: '示例书籍',
      detailUrl: 'https://example.com/book/1',
      tocUrl: 'https://example.com/book/1/toc',
      executionContext: '{"sourceId":"source_a"}',
    );

    final loadedDetail = await provider.loadDetail(
      sourceId: 'source_a',
      bookId: 'book_1',
      detailUrl: 'https://example.com/book/1',
      initialBook: initialBook,
      fallbackTitle: '兜底标题',
      fallbackAuthor: '兜底作者',
      forceRefresh: true,
      includeCatalog: false,
    );

    expect(loadedDetail, same(detailResult));
    expect(fakeDetailService.sourceId, 'source_a');
    expect(fakeDetailService.bookId, 'book_1');
    expect(fakeDetailService.detailUrl, 'https://example.com/book/1');
    expect(fakeDetailService.initialBook, same(initialBook));
    expect(fakeDetailService.fallbackTitle, '兜底标题');
    expect(fakeDetailService.fallbackAuthor, '兜底作者');
    expect(fakeDetailService.forceRefresh, isTrue);
    expect(fakeDetailService.includeCatalog, isFalse);

    final loadedContent = await provider.loadChapterContent(
      sourceId: 'source_a',
      bookId: 'book_1',
      chapterUrl: 'https://example.com/book/1/c1',
      bookTitle: '示例书籍',
      detailUrl: 'https://example.com/book/1',
      chapterIndex: 0,
      chapterTitle: '第一章',
      nextChapterUrl: 'https://example.com/book/1/c2',
      executionContext: '{"chapterUrl":"https://example.com/book/1/c1"}',
    );

    expect(loadedContent, same(contentResult));
    expect(fakeContentService.sourceId, 'source_a');
    expect(fakeContentService.bookId, 'book_1');
    expect(fakeContentService.bookTitle, '示例书籍');
    expect(fakeContentService.detailUrl, 'https://example.com/book/1');
    expect(fakeContentService.chapterUrl, 'https://example.com/book/1/c1');
    expect(fakeContentService.chapterIndex, 0);
    expect(fakeContentService.chapterTitle, '第一章');
    expect(fakeContentService.nextChapterUrl, 'https://example.com/book/1/c2');
    expect(
      fakeContentService.executionContext,
      '{"chapterUrl":"https://example.com/book/1/c1"}',
    );
    expect(loadedContent.contentType, 'audio');
    expect(loadedContent.audioUrl, 'https://cdn.example/chapter-1.mp3');
  });

  test('exposes cached detail peek for reader bootstrap reuse', () {
    const detail = BookDetail(
      id: 'book_1',
      sourceId: 'source_a',
      title: '示例书籍',
      detailUrl: 'https://example.com/book/1',
      author: '作者',
    );
    const detailResult = BookDetailLoadResult(
      detail: detail,
      chapters: <Chapter>[],
      sourceName: '源A',
      tocFromCache: true,
    );
    final fakeDetailService = _FakeBookDetailService(detailResult)
      ..cachedResult = detailResult;
    final provider = SourceContentProvider(detailService: fakeDetailService);

    final cached = provider.peekCachedDetail(
      sourceId: 'source_a',
      detailUrl: 'https://example.com/book/1',
    );

    expect(cached, same(detailResult));
  });
}
