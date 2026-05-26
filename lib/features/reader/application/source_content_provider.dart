import '../../bookshelf/application/local_book_import_service.dart';
import '../../book/application/book_detail_service.dart';
import '../../../domain/entities/book.dart';
import 'chapter_content_service.dart';
import 'content_provider.dart';

class SourceContentProvider extends ContentProvider {
  SourceContentProvider({
    BookDetailService? detailService,
    ChapterContentService? contentService,
  }) : _detailService = detailService ?? BookDetailService(),
       _contentService = contentService ?? ChapterContentService();

  final BookDetailService _detailService;
  final ChapterContentService _contentService;

  BookDetailLoadResult? peekCachedDetail({
    required String sourceId,
    required String detailUrl,
  }) {
    return _detailService.peekCached(sourceId: sourceId, detailUrl: detailUrl);
  }

  @override
  ContentCapabilities get capabilities => const ContentCapabilities(
    canSwitchSource: true,
    canCacheChapter: true,
    canRefreshToc: true,
    canSearchInSource: true,
    canReindexLocal: false,
  );

  @override
  bool supportsSourceId(String sourceId) {
    final normalized = sourceId.trim();
    return normalized.isNotEmpty &&
        normalized != LocalBookImportService.localBookSourceId;
  }

  @override
  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    Book? initialBook,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
    bool includeCatalog = true,
  }) {
    return _detailService.load(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      initialBook: initialBook,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      forceRefresh: forceRefresh,
      includeCatalog: includeCatalog,
    );
  }

  @override
  Future<ChapterContentResult> loadChapterContent({
    required String sourceId,
    required String bookId,
    required String chapterUrl,
    String? bookTitle,
    String? detailUrl,
    String? chapterId,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
    String? executionContext,
  }) {
    return _contentService.load(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      bookId: bookId,
      bookTitle: bookTitle,
      detailUrl: detailUrl,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      nextChapterUrl: nextChapterUrl,
      executionContext: executionContext,
    );
  }
}
