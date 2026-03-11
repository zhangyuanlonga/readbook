import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_codes.dart';
import '../../../core/errors/error_stage.dart';
import '../../../domain/entities/book_detail.dart';
import '../../../domain/entities/chapter.dart';
import '../../bookshelf/application/local_book_import_service.dart';
import '../../book/application/book_detail_service.dart';
import '../../book/application/local_book_detail_service.dart';
import 'chapter_content_service.dart';
import 'content_provider.dart';
import 'local/local_chapter_content_service.dart';

class LocalContentProvider extends ContentProvider {
  LocalContentProvider({
    LocalBookDetailService? detailService,
    LocalChapterContentService? chapterContentService,
  }) : _detailService = detailService ?? LocalBookDetailService(),
       _chapterContentService =
           chapterContentService ?? LocalChapterContentService();

  static const String sourceName = '本地导入';
  static const String _kLocalDetailPrefix = 'local://book/';
  static const String _kLocalChapterPrefix = 'local://chapter/';

  final LocalBookDetailService _detailService;
  final LocalChapterContentService _chapterContentService;

  @override
  ContentCapabilities get capabilities => const ContentCapabilities(
    canSwitchSource: false,
    canCacheChapter: false,
    canRefreshToc: false,
    canSearchInSource: false,
    canReindexLocal: true,
  );

  @override
  bool supportsSourceId(String sourceId) {
    return sourceId.trim() == LocalBookImportService.localBookSourceId;
  }

  @override
  Future<BookDetailLoadResult> loadDetail({
    required String sourceId,
    required String bookId,
    required String detailUrl,
    String? fallbackTitle,
    String? fallbackAuthor,
    bool forceRefresh = false,
  }) async {
    if (!supportsSourceId(sourceId)) {
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: ErrorStage.detail,
        briefMessage: '非本地书籍来源，无法加载本地详情。',
      );
    }

    final result = await _detailService.load(
      bookId: bookId,
      forceReindex: forceRefresh,
      withContent: false,
    );

    final resolvedAuthor = _resolveAuthor(result.book.author);
    final coverUrl = _resolveCoverUrl(result.book.coverPath);
    final detail = BookDetail(
      id: result.book.id,
      sourceId: LocalBookImportService.localBookSourceId,
      title: result.book.title,
      detailUrl: _buildLocalDetailUrl(result.book.id),
      author: resolvedAuthor,
      coverUrl: coverUrl,
    );

    final chapters = result.chapters
        .map(
          (chapter) => Chapter(
            id: chapter.id,
            bookId: chapter.bookId,
            title: chapter.title,
            chapterUrl: _buildLocalChapterUrl(chapter.id),
            index: chapter.chapterIndex,
          ),
        )
        .toList(growable: false);

    return BookDetailLoadResult(
      detail: detail,
      chapters: chapters,
      sourceName: sourceName,
      tocFromCache: false,
      tocError: null,
    );
  }

  @override
  Future<ChapterContentResult> loadChapterContent({
    required String sourceId,
    required String bookId,
    required String chapterUrl,
    String? chapterId,
    int? chapterIndex,
    String? chapterTitle,
    String? nextChapterUrl,
  }) async {
    if (!supportsSourceId(sourceId)) {
      throw AppException(
        code: ErrorCode.unknownSource,
        stage: ErrorStage.content,
        briefMessage: '非本地书籍来源，无法加载本地正文。',
      );
    }

    final resolvedChapterId = _resolveChapterId(
      chapterId: chapterId,
      chapterUrl: chapterUrl,
    );

    if ((resolvedChapterId == null || resolvedChapterId.isEmpty) &&
        chapterIndex == null) {
      throw AppException(
        code: ErrorCode.validation,
        stage: ErrorStage.content,
        briefMessage: '缺少本地章节信息，请重新进入或重新索引。',
      );
    }

    final chapter = await _chapterContentService.load(
      bookId: bookId,
      chapterId: resolvedChapterId,
      chapterIndex: chapterIndex,
    );

    return ChapterContentResult(
      content: chapter.content,
      fromCache: true,
    );
  }

  String? _resolveChapterId({
    required String? chapterId,
    required String chapterUrl,
  }) {
    final normalizedChapterId = (chapterId ?? '').trim();
    if (normalizedChapterId.isNotEmpty) {
      return normalizedChapterId;
    }

    final normalizedUrl = chapterUrl.trim();
    if (normalizedUrl.isEmpty) {
      return null;
    }

    if (normalizedUrl.startsWith(_kLocalChapterPrefix)) {
      final extracted = normalizedUrl.substring(_kLocalChapterPrefix.length);
      return extracted.isEmpty ? null : extracted;
    }

    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null || uri.scheme != 'local') {
      return null;
    }

    if (uri.host != 'chapter') {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return null;
    }

    final last = segments.last.trim();
    return last.isEmpty ? null : last;
  }

  String _buildLocalDetailUrl(String bookId) {
    return '$_kLocalDetailPrefix$bookId';
  }

  String _buildLocalChapterUrl(String chapterId) {
    return '$_kLocalChapterPrefix$chapterId';
  }

  String? _resolveCoverUrl(String? coverPath) {
    final normalized = coverPath?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return Uri.file(normalized).toString();
  }

  String _resolveAuthor(String? author) {
    final normalized = author?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return sourceName;
  }
}
