import '../../bookshelf/application/local_book_import_service.dart';
import '../../book/application/book_detail_service.dart';
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
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
  }) {
    return _detailService.load(
      sourceId: sourceId,
      bookId: bookId,
      detailUrl: detailUrl,
      fallbackTitle: fallbackTitle,
      fallbackAuthor: fallbackAuthor,
      forceRefresh: forceRefresh,
    );
  }

  @override
  Future<ChapterContentResult> loadChapterContent({
    required String sourceId,
    required String bookId,
    required String chapterUrl,
    String? bookTitle,
    String? chapterId,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  }) {
    return _contentService.load(
      sourceId: sourceId,
      chapterUrl: chapterUrl,
      bookId: bookId,
      bookTitle: bookTitle,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      nextChapterUrl: nextChapterUrl,
    );
  }
}
