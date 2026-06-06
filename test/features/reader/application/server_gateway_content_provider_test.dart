import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shuxiang_reading_next/domain/entities/book.dart';
import 'package:shuxiang_reading_next/domain/entities/book_detail.dart';
import 'package:shuxiang_reading_next/features/book/application/book_detail_service.dart';
import 'package:shuxiang_reading_next/features/reader/application/server_gateway_content_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'delegates online detail loading to shared book detail service',
    () async {
      const result = BookDetailLoadResult(
        detail: BookDetail(
          id: 'book_1',
          sourceId: 'server-gateway:source_a',
          title: '示例书籍',
          detailUrl: 'https://example.com/book/1',
        ),
        chapters: <Never>[],
        sourceName: '源A',
        tocFromCache: false,
        catalogLoaded: false,
        catalogComplete: false,
      );
      final detailService = _FakeBookDetailService(result);
      final provider = ServerGatewayContentProvider(
        detailService: detailService,
      );
      const initialBook = Book(
        id: 'book_1',
        sourceId: 'server-gateway:source_a',
        title: '示例书籍',
        detailUrl: 'https://example.com/book/1',
        tocUrl: 'https://example.com/book/1/toc',
        executionContext: '{"sourceId":"source_a"}',
      );

      final loaded = await provider.loadDetail(
        sourceId: 'server-gateway:source_a',
        bookId: 'book_1',
        detailUrl: 'https://example.com/book/1',
        initialBook: initialBook,
        fallbackTitle: '兜底标题',
        fallbackAuthor: '兜底作者',
        forceRefresh: true,
        includeCatalog: false,
      );

      expect(loaded, same(result));
      expect(detailService.sourceId, 'server-gateway:source_a');
      expect(detailService.bookId, 'book_1');
      expect(detailService.detailUrl, 'https://example.com/book/1');
      expect(detailService.initialBook, same(initialBook));
      expect(detailService.fallbackTitle, '兜底标题');
      expect(detailService.fallbackAuthor, '兜底作者');
      expect(detailService.forceRefresh, isTrue);
      expect(detailService.includeCatalog, isFalse);
    },
  );
}

class _FakeBookDetailService extends BookDetailService {
  _FakeBookDetailService(this.result);

  final BookDetailLoadResult result;

  String? sourceId;
  String? bookId;
  String? detailUrl;
  Book? initialBook;
  String? fallbackTitle;
  String? fallbackAuthor;
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
}
